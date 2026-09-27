// Package review 实现"近期回顾"：先由后端算出确定性统计，再交本地模型写成叙述。
//
// 分工是刻意的——数字全部由 Go 侧从库中算出并随结果一起返回，模型只被要求
// "用给定的事实写一段话"。这样即使模型胡说，页面上的统计仍然可信；模型不可用时
// 接口依然返回统计，只是没有叙述（完整降级）。
// 结果按"统计指纹 + 预设 + 模型"缓存，数据没变就不会重复推理。
package review

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/repository/data_repo"
	"monarch/internal/service/ai"
)

// KindRecent 目前只有"近期回顾"一种回顾。
const KindRecent = "recent"

// DefaultDays 默认回顾窗口。
const DefaultDays = 30

// MaxDays 回顾窗口上限，避免把整年数据塞进提示词。
const MaxDays = 365

// TaskStat 单个打卡任务的完成情况。
type TaskStat struct {
	Name string `json:"name"`
	Done int    `json:"done"`
	Days int    `json:"days"`
}

// LabelStat 标签及其随笔数。
type LabelStat struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

// BookletStats 打卡模块的确定性统计。
type BookletStats struct {
	ActiveStyles   int            `json:"active_styles"`
	TotalRecords   int            `json:"total_records"`
	CheckInDays    int            `json:"check_in_days"`
	CurrentStreak  int            `json:"current_streak"`
	LongestStreak  int            `json:"longest_streak"`
	CompletionRate float64        `json:"completion_rate"`
	MoodCounts     map[string]int `json:"mood_counts"`
	TopTasks       []TaskStat     `json:"top_tasks"`
}

// EssayStats 随笔模块的确定性统计。
type EssayStats struct {
	Articles   int            `json:"articles"`
	Words      int            `json:"words"`
	ActiveDays int            `json:"active_days"`
	AvgWords   float64        `json:"avg_words"`
	TopLabels  []LabelStat    `json:"top_labels"`
	MoodCounts map[string]int `json:"mood_counts"`
}

// Stats 一次回顾的全部确定性统计。
type Stats struct {
	From    string       `json:"from"`
	To      string       `json:"to"`
	Days    int          `json:"days"`
	Facts   []string     `json:"facts"`
	Booklet BookletStats `json:"booklet"`
	Essay   EssayStats   `json:"essay"`
}

// Result 回顾结果：统计 + 模型叙述（可能为空）。
type Result struct {
	Stats     Stats  `json:"stats"`
	Narrative string `json:"narrative"`
	Model     string `json:"model,omitempty"`
	PresetID  string `json:"preset_id"`
	Preset    string `json:"preset_name,omitempty"`
	Cached    bool   `json:"cached"`
	CreatedAt string `json:"created_at,omitempty"`
	// Notice 在模型不可用或生成失败时给出可读原因（统计仍然有效）。
	Notice string `json:"notice,omitempty"`
}

// Recent 生成近期回顾。
func Recent(ctx context.Context, days int, presetID string, force bool) (*Result, error) {
	days = normalizeDays(days)

	preset, err := resolvePreset(presetID)
	if err != nil {
		return nil, err
	}

	stats, err := ComputeStats(days)
	if err != nil {
		return nil, err
	}
	fingerprint, err := fingerprint(stats)
	if err != nil {
		return nil, err
	}

	result := &Result{Stats: stats, PresetID: preset.ID, Preset: preset.Name}

	engine := ai.Default
	if engine == nil || !engine.Config().Enabled {
		result.Notice = "AI 处理层未启用，仅返回确定性统计"
		return result, nil
	}
	modelName := engine.VLMModel()
	result.Model = modelName
	if modelName == "" {
		result.Notice = "未配置 VLM 模型，仅返回确定性统计"
		return result, nil
	}

	if !force {
		cached, err := ai_repo.GetCachedReview(KindRecent, fingerprint, preset.ID, modelName)
		if err != nil {
			return nil, err
		}
		if cached != nil {
			result.Narrative = cached.Narrative
			result.Cached = true
			result.CreatedAt = cached.CreatedAt
			return result, nil
		}
	}

	narrative, genErr := generate(ctx, engine, modelName, preset, stats)
	if genErr != nil {
		result.Notice = "模型生成失败，仅返回确定性统计: " + genErr.Error()
		return result, nil
	}
	result.Narrative = narrative
	result.CreatedAt = model.Now()

	if err := ai_repo.SaveReview(KindRecent, fingerprint, preset.ID, modelName, mustJSON(stats), narrative); err != nil {
		// 缓存失败不影响本次结果，只在响应里说明
		result.Notice = strings.TrimSpace(result.Notice + " 缓存写入失败: " + err.Error())
	}
	return result, nil
}

// resolvePreset 解析预设；未指定时用默认预设。
func resolvePreset(presetID string) (ai_repo.ReviewPreset, error) {
	if err := ai_repo.EnsureReviewPresets(); err != nil {
		return ai_repo.ReviewPreset{}, err
	}
	presetID = strings.TrimSpace(presetID)
	if presetID != "" {
		preset, err := ai_repo.GetReviewPreset(presetID)
		if err != nil {
			return ai_repo.ReviewPreset{}, err
		}
		if preset == nil {
			return ai_repo.ReviewPreset{}, fmt.Errorf("回顾预设不存在: %s", presetID)
		}
		return *preset, nil
	}
	presets, err := ai_repo.ListReviewPresets()
	if err != nil {
		return ai_repo.ReviewPreset{}, err
	}
	if len(presets) == 0 {
		return ai_repo.DefaultReviewPreset(), nil
	}
	return presets[0], nil
}

// generate 把统计交给本地模型，让它只做"叙述"而不再算数。
func generate(ctx context.Context, engine *ai.Engine, modelName string, preset ai_repo.ReviewPreset, stats Stats) (string, error) {
	lease := engine.UseModel(ctx, modelName, "近期回顾", ai.ModelForeground)
	defer lease.Release()
	if lease.Notice != "" {
		// 抢占提示只影响后台标注，不阻断本次生成
		_ = lease.Notice
	}
	runCtx, cancel := context.WithTimeout(lease.Context(), 5*time.Minute)
	defer cancel()

	facts := mustJSON(stats)
	system := strings.TrimSpace(fmt.Sprintf(
		"你是%s。用%s的语气，写一段 %d 天生活的简短回顾（150-250 字，中文，分 2-3 段）。"+
			"只能使用我给出的统计数据，不得编造任何数字或事件；数据里没有的不要提。",
		orDefault(preset.Role, "熟悉我日常节奏的记录者"),
		orDefault(preset.Tone, "平实、克制"),
		stats.Days,
	))
	user := "以下是我这段时期的确定性统计（JSON）：\n" + facts + "\n\n请据此写回顾。"

	var sb strings.Builder
	err := engine.OllamaProvider().Chat(runCtx, modelName, []ai.ChatMessage{
		{Role: "system", Content: system},
		{Role: "user", Content: user},
	}, ai.ChatOptions{Think: false, KeepAliveSeconds: -1}, func(ev ai.ChatEvent) error {
		switch ev.Type {
		case "delta":
			sb.WriteString(ev.Content)
		case "error":
			return fmt.Errorf("%s", ev.Content)
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	narrative := strings.TrimSpace(sb.String())
	if narrative == "" {
		return "", fmt.Errorf("模型返回空内容")
	}
	return narrative, nil
}

// ComputeStats 从库中算出确定性统计（不依赖任何模型）。
func ComputeStats(days int) (Stats, error) {
	days = normalizeDays(days)
	now := time.Now().UTC()
	from := now.AddDate(0, 0, -(days - 1))
	fromDate := from.Format(model.DateFormat)
	toDate := now.Format(model.DateFormat)

	stats := Stats{
		From: fromDate,
		To:   toDate,
		Days: days,
		Booklet: BookletStats{
			MoodCounts: map[string]int{},
		},
		Essay: EssayStats{
			MoodCounts: map[string]int{},
		},
	}

	if err := computeBooklet(&stats, fromDate, toDate); err != nil {
		return Stats{}, err
	}
	if err := computeEssay(&stats, fromDate, toDate); err != nil {
		return Stats{}, err
	}
	stats.Facts = buildFacts(stats)
	return stats, nil
}

func computeBooklet(stats *Stats, fromDate, toDate string) error {
	styles, err := data_repo.FetchAllBookletStyles()
	if err != nil {
		return err
	}
	records, err := data_repo.FetchAllBookletRecords()
	if err != nil {
		return err
	}

	// 任务名映射：styleID → taskID → 名称。
	// 客户端的打卡任务结构里名称字段叫 title（历史数据里也可能出现 name），两者都认。
	taskNames := make(map[string]map[string]string, len(styles))
	activeStyles := 0
	for _, s := range styles {
		if inRange(s.StartDate, fromDate, toDate) {
			activeStyles++
		}
		names := map[string]string{}
		var tasks []struct {
			ID    string `json:"id"`
			Title string `json:"title"`
			Name  string `json:"name"`
		}
		if len(s.Tasks) > 0 {
			_ = json.Unmarshal(s.Tasks, &tasks)
		}
		for _, t := range tasks {
			if t.ID == "" {
				continue
			}
			names[t.ID] = firstNonEmpty(t.Title, t.Name)
		}
		taskNames[s.ID.String()] = names
	}

	days := map[string]bool{}
	taskDone := map[string]int{}
	taskDays := map[string]int{}
	totalDone, totalSlots := 0, 0

	for _, r := range records {
		if r.DeletedAt != nil || !inRange(r.Date, fromDate, toDate) {
			continue
		}
		stats.Booklet.TotalRecords++
		days[r.Date.Format(model.DateFormat)] = true
		if r.Mood != nil && *r.Mood != "" {
			stats.Booklet.MoodCounts[*r.Mood]++
		}

		completed := map[string]bool{}
		if len(r.TaskCompletion) > 0 {
			_ = json.Unmarshal(r.TaskCompletion, &completed)
		}
		names := taskNames[r.StyleID.String()]
		for taskID, done := range completed {
			totalSlots++
			if !done {
				continue
			}
			totalDone++
			name := names[taskID]
			if name == "" {
				name = taskID
			}
			taskDone[name]++
			taskDays[name]++
		}
	}

	stats.Booklet.ActiveStyles = activeStyles
	stats.Booklet.CheckInDays = len(days)
	if totalSlots > 0 {
		stats.Booklet.CompletionRate = round2(float64(totalDone) / float64(totalSlots))
	}
	stats.Booklet.LongestStreak, stats.Booklet.CurrentStreak = streaks(days, toDate)
	stats.Booklet.TopTasks = topTasks(taskDone, taskDays, 5)
	return nil
}

func computeEssay(stats *Stats, fromDate, toDate string) error {
	articles, err := data_repo.FetchAllEssayArticles()
	if err != nil {
		return err
	}
	labels, err := data_repo.FetchAllEssayLabels()
	if err != nil {
		return err
	}
	labelNames := make(map[string]string, len(labels))
	for _, l := range labels {
		labelNames[l.ID.String()] = l.Name
	}

	days := map[string]bool{}
	labelCounts := map[string]int{}
	for _, a := range articles {
		if a.DeletedAt != nil || !inRange(a.Date, fromDate, toDate) {
			continue
		}
		stats.Essay.Articles++
		stats.Essay.Words += a.WordCount
		days[a.Date.Format(model.DateFormat)] = true
		if a.Mood != nil && *a.Mood != "" {
			stats.Essay.MoodCounts[*a.Mood]++
		}
		for _, id := range a.Labels {
			name := labelNames[id]
			if name == "" {
				continue
			}
			labelCounts[name]++
		}
	}

	stats.Essay.ActiveDays = len(days)
	if stats.Essay.Articles > 0 {
		stats.Essay.AvgWords = round2(float64(stats.Essay.Words) / float64(stats.Essay.Articles))
	}
	stats.Essay.TopLabels = topLabels(labelCounts, 5)
	return nil
}

// buildFacts 把统计整理成人读的事实清单：模型只被允许引用这些句子。
func buildFacts(stats Stats) []string {
	facts := []string{
		fmt.Sprintf("统计区间 %s 至 %s，共 %d 天。", stats.From, stats.To, stats.Days),
	}
	if stats.Booklet.CheckInDays > 0 {
		facts = append(facts,
			fmt.Sprintf("打卡 %d 天，共 %d 条记录，任务完成率 %.0f%%。",
				stats.Booklet.CheckInDays, stats.Booklet.TotalRecords, stats.Booklet.CompletionRate*100),
			fmt.Sprintf("最长连续打卡 %d 天，当前连续 %d 天。",
				stats.Booklet.LongestStreak, stats.Booklet.CurrentStreak))
		for _, t := range stats.Booklet.TopTasks {
			facts = append(facts, fmt.Sprintf("打卡任务「%s」完成 %d 次。", t.Name, t.Done))
		}
	}
	if stats.Essay.Articles > 0 {
		facts = append(facts,
			fmt.Sprintf("写下 %d 篇随笔、共 %d 字，平均每篇 %.0f 字，覆盖 %d 天。",
				stats.Essay.Articles, stats.Essay.Words, stats.Essay.AvgWords, stats.Essay.ActiveDays))
		for _, l := range stats.Essay.TopLabels {
			facts = append(facts, fmt.Sprintf("随笔标签「%s」出现 %d 次。", l.Name, l.Count))
		}
	}
	return facts
}

// ---------- 辅助 ----------

func normalizeDays(days int) int {
	if days <= 0 {
		return DefaultDays
	}
	if days > MaxDays {
		return MaxDays
	}
	return days
}

// inRange 判断时间是否落在 [from, to] 日期区间内（含端点，按 UTC 日期比较）。
func inRange(t time.Time, fromDate, toDate string) bool {
	if t.IsZero() {
		return false
	}
	d := t.UTC().Format(model.DateFormat)
	return d >= fromDate && d <= toDate
}

// streaks 计算最长连续与"截至 toDate"的当前连续天数。
func streaks(days map[string]bool, toDate string) (longest, current int) {
	if len(days) == 0 {
		return 0, 0
	}
	dates := make([]string, 0, len(days))
	for d := range days {
		dates = append(dates, d)
	}
	sort.Strings(dates)

	run := 0
	var prev time.Time
	for _, d := range dates {
		t, err := time.Parse(model.DateFormat, d)
		if err != nil {
			continue
		}
		if !prev.IsZero() && t.Sub(prev) == 24*time.Hour {
			run++
		} else {
			run = 1
		}
		if run > longest {
			longest = run
		}
		prev = t
	}

	end, err := time.Parse(model.DateFormat, toDate)
	if err != nil {
		return longest, 0
	}
	// 当前连续：从今天（或昨天）往前逐日回溯
	cursor := end
	if !days[cursor.Format(model.DateFormat)] {
		cursor = cursor.AddDate(0, 0, -1)
	}
	for days[cursor.Format(model.DateFormat)] {
		current++
		cursor = cursor.AddDate(0, 0, -1)
	}
	return longest, current
}

func topTasks(done, dayCount map[string]int, limit int) []TaskStat {
	out := make([]TaskStat, 0, len(done))
	for name, n := range done {
		out = append(out, TaskStat{Name: name, Done: n, Days: dayCount[name]})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Done == out[j].Done {
			return out[i].Name < out[j].Name
		}
		return out[i].Done > out[j].Done
	})
	if len(out) > limit {
		out = out[:limit]
	}
	return out
}

func topLabels(counts map[string]int, limit int) []LabelStat {
	out := make([]LabelStat, 0, len(counts))
	for name, n := range counts {
		out = append(out, LabelStat{Name: name, Count: n})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Count == out[j].Count {
			return out[i].Name < out[j].Name
		}
		return out[i].Count > out[j].Count
	})
	if len(out) > limit {
		out = out[:limit]
	}
	return out
}

// fingerprint 是统计内容的确定性指纹，用作缓存键：数据一变就重新生成。
func fingerprint(stats Stats) (string, error) {
	data, err := json.Marshal(stats)
	if err != nil {
		return "", fmt.Errorf("计算统计指纹失败: %w", err)
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:16]), nil
}

func mustJSON(v any) string {
	data, err := json.Marshal(v)
	if err != nil {
		return "{}"
	}
	return string(data)
}

func round2(v float64) float64 {
	return float64(int(v*100+0.5)) / 100
}

func orDefault(v, def string) string {
	if strings.TrimSpace(v) == "" {
		return def
	}
	return v
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}
