// Package review 为"近期回顾"准备输入：后端从 booklet/essay 数据算出确定性统计，
// 再（可选）随机抽取若干具体记录作为素材，一并交给本地模型写成叙述。
//
// 统计部分不含任何随机成分：同样的范围与数据必然得出同样的结果。随机只发生在
// "抽哪几条"上，且素材仅用于拼提示词，不落库、不回写。
package review

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"sort"
	"strings"
	"time"

	"monarch/internal/model"
	"monarch/internal/repository/data_repo"
)

// 抽样与展示的上限：素材只是给模型的引子，过多只会挤占上下文。
const (
	MaxSampleEssays  = 20
	MaxSampleRecords = 20
	maxSampleRunes   = 600 // 单条素材正文截断长度（rune）
	maxTopLabels     = 5
	maxGroupTasks    = 4
)

// Range 回顾的时间范围，闭区间；From/To 是"日历日"标记（以 UTC 零点表示）。
type Range struct {
	From time.Time
	To   time.Time
}

// Days 范围内的天数（含首尾）。
func (r Range) Days() int {
	if r.To.Before(r.From) {
		return 0
	}
	return int(r.To.Sub(r.From).Hours()/24) + 1
}

// Contains 判断某个日历日标记是否落在范围内。
func (r Range) Contains(day time.Time) bool {
	return !day.Before(r.From) && !day.After(r.To)
}

// Date 解析 `YYYY-MM-DD` 为日历日标记（UTC 零点）。
func Date(raw string) (time.Time, error) {
	t, err := time.ParseInLocation("2006-01-02", strings.TrimSpace(raw), time.UTC)
	if err != nil {
		return time.Time{}, fmt.Errorf("日期格式应为 YYYY-MM-DD: %q", raw)
	}
	return t, nil
}

// Today 返回本机当前日历日标记。回顾面向的是"我这里的今天"。
func Today() time.Time {
	y, m, d := time.Now().In(time.Local).Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// Count 一项计数（标签 / 心情）。
type Count struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

// Stats 回顾的确定性统计，结构同时用于提示词与端上展示。
type Stats struct {
	From    string       `json:"from"`
	To      string       `json:"to"`
	Days    int          `json:"days"`
	Essay   EssayStats   `json:"essay"`
	Booklet BookletStats `json:"booklet"`
}

// EssayStats 随笔在范围内的汇总。
type EssayStats struct {
	Count         int     `json:"count"`
	WordCount     int     `json:"word_count"`
	ActiveDays    int     `json:"active_days"`
	LongestStreak int     `json:"longest_streak"`
	LongestWords  int     `json:"longest_words"`
	LongestDate   string  `json:"longest_date"`
	TopLabels     []Count `json:"top_labels"`
	Moods         []Count `json:"moods"`
}

// BookletStats 打卡在范围内的汇总。
type BookletStats struct {
	RecordCount   int          `json:"record_count"`
	ActiveDays    int          `json:"active_days"`
	FullyDoneDays int          `json:"fully_done_days"`
	LongestStreak int          `json:"longest_streak"`
	MessageDays   int          `json:"message_days"`
	Moods         []Count      `json:"moods"`
	Groups        []GroupStats `json:"groups"`
}

// GroupStats 一个打卡项目组在范围内的表现。
type GroupStats struct {
	Tasks         []string `json:"tasks"`
	RecordCount   int      `json:"record_count"`
	FullyDoneDays int      `json:"fully_done_days"`
	DoneRate      float64  `json:"done_rate"` // 已完成任务数 / 应完成任务数
}

// EssaySample 随机抽取的一篇随笔。
type EssaySample struct {
	Date      string   `json:"date"`
	WordCount int      `json:"word_count"`
	Labels    []string `json:"labels"`
	Mood      string   `json:"mood,omitempty"`
	Content   string   `json:"content"`
}

// RecordSample 随机抽取的一天打卡记录。
type RecordSample struct {
	Date    string   `json:"date"`
	Group   string   `json:"group"`
	Done    []string `json:"done"`
	Missed  []string `json:"missed"`
	Mood    string   `json:"mood,omitempty"`
	Message string   `json:"message,omitempty"`
}

// Data 一次回顾的全部输入：确定性统计 + 随机抽样素材。
type Data struct {
	Stats   Stats
	Essays  []EssaySample
	Records []RecordSample
}

// Collect 读取范围内的数据，产出确定性统计与可选抽样。
//
// 时间口径必须分开处理，否则会整体错一天：
//   - essay.date 是绝对时刻（按本机本地时间存储），按本地日历日归日；
//   - booklet_records.date 是日历日标记（按 UTC 零点存储），直接取其年月日。
func Collect(r Range, wantEssays, wantRecords int) (*Data, error) {
	articles, err := data_repo.FetchAllEssayArticles()
	if err != nil {
		return nil, err
	}
	labels, err := data_repo.FetchAllEssayLabels()
	if err != nil {
		return nil, err
	}
	styles, err := data_repo.FetchAllBookletStyles()
	if err != nil {
		return nil, err
	}
	records, err := data_repo.FetchAllBookletRecords()
	if err != nil {
		return nil, err
	}

	labelNames := make(map[string]string, len(labels))
	for _, item := range labels {
		labelNames[item.ID.String()] = item.Name
	}

	data := &Data{Stats: Stats{
		From: r.From.Format("2006-01-02"),
		To:   r.To.Format("2006-01-02"),
		Days: r.Days(),
	}}
	data.Stats.Essay = collectEssays(r, articles, labelNames)
	data.Stats.Booklet = collectBooklet(r, styles, records)
	data.Essays = sampleEssaysIn(r, articles, labelNames, wantEssays)
	data.Records = sampleRecordsIn(r, styles, records, wantRecords)
	return data, nil
}

// ---------- 随笔 ----------

func collectEssays(r Range, articles []model.EssayArticle, labelNames map[string]string) EssayStats {
	stats := EssayStats{TopLabels: []Count{}, Moods: []Count{}}
	labelCount := map[string]int{}
	moodCount := map[string]int{}
	var days []time.Time

	for _, item := range articles {
		day := localDay(item.Date.Time())
		if !r.Contains(day) {
			continue
		}
		stats.Count++
		stats.WordCount += item.WordCount
		days = append(days, day)
		if item.WordCount > stats.LongestWords {
			stats.LongestWords = item.WordCount
			stats.LongestDate = day.Format("2006-01-02")
		}
		for _, id := range item.Labels {
			if name := labelNames[id]; name != "" {
				labelCount[name]++
			}
		}
		if label := moodLabel(item.Mood); label != "" {
			moodCount[label]++
		}
	}

	stats.ActiveDays = distinctDays(days)
	stats.LongestStreak = longestStreak(days)
	stats.TopLabels = topCounts(labelCount, maxTopLabels)
	stats.Moods = topCounts(moodCount, 0)
	return stats
}

// sampleEssaysIn 在范围内随机抽取若干随笔（不足则全取）。
func sampleEssaysIn(r Range, articles []model.EssayArticle, labelNames map[string]string, want int) []EssaySample {
	if want <= 0 {
		return nil
	}
	var inRange []model.EssayArticle
	for _, item := range articles {
		if r.Contains(localDay(item.Date.Time())) {
			inRange = append(inRange, item)
		}
	}
	shuffle(len(inRange), func(i, j int) { inRange[i], inRange[j] = inRange[j], inRange[i] })
	if len(inRange) > want {
		inRange = inRange[:want]
	}

	// 抽出的几条按时间排序，读起来才像一条线索。
	sort.Slice(inRange, func(i, j int) bool { return inRange[i].Date.Time().Before(inRange[j].Date.Time()) })

	samples := make([]EssaySample, 0, len(inRange))
	for _, item := range inRange {
		names := make([]string, 0, len(item.Labels))
		for _, id := range item.Labels {
			if name := labelNames[id]; name != "" {
				names = append(names, name)
			}
		}
		content := strings.TrimSpace(item.Content)
		if content == "" {
			continue // 只有图片没有正文的随笔，对写作回顾没有价值
		}
		samples = append(samples, EssaySample{
			Date:      localDay(item.Date.Time()).Format("2006-01-02"),
			WordCount: item.WordCount,
			Labels:    names,
			Mood:      moodLabel(item.Mood),
			Content:   truncate(content, maxSampleRunes),
		})
	}
	return samples
}

// ---------- 打卡 ----------

func collectBooklet(r Range, styles []model.BookletStyle, records []model.BookletRecord) BookletStats {
	stats := BookletStats{Moods: []Count{}, Groups: []GroupStats{}}
	styleIndex := indexStyles(styles)

	var days []time.Time
	moodCount := map[string]int{}
	// 按项目组累计：记录数、全勤天数、已完成/应完成任务数。
	type groupAcc struct {
		records   int
		fullDays  int
		done      int
		expected  int
	}
	accs := map[string]*groupAcc{}

	for _, rec := range records {
		day := markedDay(rec.Date.Time())
		if !r.Contains(day) {
			continue
		}
		stats.RecordCount++
		days = append(days, day)
		if strings.TrimSpace(rec.Message) != "" {
			stats.MessageDays++
		}
		if label := moodLabel(rec.Mood); label != "" {
			moodCount[label]++
		}

		completion := decodeCompletion(rec.TaskCompletion)
		group := styleIndex[rec.StyleID.String()]
		done, total := countDone(completion, group.tasks)
		if total > 0 && done == total {
			stats.FullyDoneDays++
		}

		acc := accs[rec.StyleID.String()]
		if acc == nil {
			acc = &groupAcc{}
			accs[rec.StyleID.String()] = acc
		}
		acc.records++
		if total > 0 && done == total {
			acc.fullDays++
		}
		acc.done += done
		acc.expected += total
	}

	stats.ActiveDays = distinctDays(days)
	stats.LongestStreak = longestStreak(days)
	stats.Moods = topCounts(moodCount, 0)

	// 组内按记录数从多到少，保证输出稳定可比。
	ids := make([]string, 0, len(accs))
	for id := range accs {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool {
		if accs[ids[i]].records != accs[ids[j]].records {
			return accs[ids[i]].records > accs[ids[j]].records
		}
		return ids[i] < ids[j]
	})
	for _, id := range ids {
		acc := accs[id]
		group := styleIndex[id]
		rate := 0.0
		if acc.expected > 0 {
			rate = float64(acc.done) / float64(acc.expected)
		}
		stats.Groups = append(stats.Groups, GroupStats{
			Tasks:         group.titles,
			RecordCount:   acc.records,
			FullyDoneDays: acc.fullDays,
			DoneRate:      rate,
		})
	}
	return stats
}

// sampleRecordsIn 在范围内随机抽取若干打卡记录（不足则全取）。
func sampleRecordsIn(r Range, styles []model.BookletStyle, records []model.BookletRecord, want int) []RecordSample {
	if want <= 0 {
		return nil
	}
	var inRange []model.BookletRecord
	for _, rec := range records {
		if r.Contains(markedDay(rec.Date.Time())) {
			inRange = append(inRange, rec)
		}
	}
	shuffle(len(inRange), func(i, j int) { inRange[i], inRange[j] = inRange[j], inRange[i] })
	if len(inRange) > want {
		inRange = inRange[:want]
	}
	sort.Slice(inRange, func(i, j int) bool { return inRange[i].Date.Time().Before(inRange[j].Date.Time()) })

	styleIndex := indexStyles(styles)
	samples := make([]RecordSample, 0, len(inRange))
	for _, rec := range inRange {
		group := styleIndex[rec.StyleID.String()]
		completion := decodeCompletion(rec.TaskCompletion)
		done, missed := splitCompletion(completion, group.tasks)
		samples = append(samples, RecordSample{
			Date:    markedDay(rec.Date.Time()).Format("2006-01-02"),
			Group:   strings.Join(group.titles, "/"),
			Done:    done,
			Missed:  missed,
			Mood:    moodLabel(rec.Mood),
			Message: truncate(strings.TrimSpace(rec.Message), maxSampleRunes),
		})
	}
	return samples
}

// ---------- 通用辅助 ----------

// styleInfo 一个打卡项目组的任务标题（记录里只存任务 ID，需要回表取名字）。
type styleInfo struct {
	titles []string
	tasks  map[string]string // 任务 ID → 标题
}

func indexStyles(styles []model.BookletStyle) map[string]styleInfo {
	index := make(map[string]styleInfo, len(styles))
	for _, style := range styles {
		info := styleInfo{titles: []string{}, tasks: map[string]string{}}
		var tasks []struct {
			ID    string `json:"id"`
			Title string `json:"title"`
		}
		if err := json.Unmarshal(style.Tasks, &tasks); err != nil {
			// 任务定义损坏时不该让整个回顾失败：这一组按空任务处理。
			index[style.ID.String()] = info
			continue
		}
		for _, task := range tasks {
			title := strings.TrimSpace(task.Title)
			if title == "" {
				continue
			}
			info.tasks[task.ID] = title
			if len(info.titles) < maxGroupTasks {
				info.titles = append(info.titles, title)
			}
		}
		index[style.ID.String()] = info
	}
	return index
}

func decodeCompletion(raw json.RawMessage) map[string]bool {
	completion := map[string]bool{}
	if len(raw) == 0 {
		return completion
	}
	_ = json.Unmarshal(raw, &completion)
	return completion
}

// countDone 统计已完成与应完成的任务数（以项目组当前的任务定义为准）。
func countDone(completion map[string]bool, tasks map[string]string) (done, total int) {
	for id, title := range tasks {
		if title == "" {
			continue
		}
		total++
		if completion[id] {
			done++
		}
	}
	return done, total
}

func splitCompletion(completion map[string]bool, tasks map[string]string) (done, missed []string) {
	done, missed = []string{}, []string{}
	for id, title := range tasks {
		if title == "" {
			continue
		}
		if completion[id] {
			done = append(done, title)
		} else {
			missed = append(missed, title)
		}
	}
	sort.Strings(done)
	sort.Strings(missed)
	return done, missed
}

// localDay 绝对时刻 → 本机本地日历日标记。
func localDay(t time.Time) time.Time { return civilDay(t, time.Local) }

// markedDay 日历日标记（UTC 零点）→ 它自身表示的那一天。
func markedDay(t time.Time) time.Time { return civilDay(t, time.UTC) }

// civilDay 取 t 在 loc 下的年月日，以 UTC 零点表示，便于跨来源统一比较。
func civilDay(t time.Time, loc *time.Location) time.Time {
	y, m, d := t.In(loc).Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// distinctDays 去重后的天数。
func distinctDays(days []time.Time) int {
	seen := map[string]bool{}
	for _, day := range days {
		seen[day.Format("2006-01-02")] = true
	}
	return len(seen)
}

// longestStreak 最长连续天数（输入允许重复与乱序）。
func longestStreak(days []time.Time) int {
	seen := map[string]time.Time{}
	for _, day := range days {
		seen[day.Format("2006-01-02")] = day
	}
	unique := make([]time.Time, 0, len(seen))
	for _, day := range seen {
		unique = append(unique, day)
	}
	sort.Slice(unique, func(i, j int) bool { return unique[i].Before(unique[j]) })

	best, run := 0, 0
	var previous time.Time
	for _, day := range unique {
		if run > 0 && day.Sub(previous) == 24*time.Hour {
			run++
		} else {
			run = 1
		}
		previous = day
		if run > best {
			best = run
		}
	}
	return best
}

// topCounts 按次数降序（同次数按名称升序，保证输出稳定）；limit<=0 表示不截断。
func topCounts(counts map[string]int, limit int) []Count {
	items := make([]Count, 0, len(counts))
	for name, count := range counts {
		items = append(items, Count{Name: name, Count: count})
	}
	sort.Slice(items, func(i, j int) bool {
		if items[i].Count != items[j].Count {
			return items[i].Count > items[j].Count
		}
		return items[i].Name < items[j].Name
	})
	if limit > 0 && len(items) > limit {
		items = items[:limit]
	}
	return items
}

// shuffle 就地洗牌。回顾的"随机素材"每次生成都换一批，因此用时间播种。
func shuffle(n int, swap func(i, j int)) {
	if n < 2 {
		return
	}
	rand.New(rand.NewSource(time.Now().UnixNano())).Shuffle(n, swap)
}

// truncate 按 rune 截断，避免把多字节字符截坏。
func truncate(text string, limit int) string {
	runes := []rune(text)
	if len(runes) <= limit {
		return text
	}
	return string(runes[:limit]) + "…"
}

// moodLabels 心情标识 → 中文名（与端上 MoodType 一致）。
var moodLabels = map[string]string{
	"happy": "开心",
	"calm":  "平静",
	"sad":   "难过",
	"angry": "生气",
	"tired": "疲惫",
}

func moodLabel(raw *string) string {
	if raw == nil {
		return ""
	}
	return moodLabels[strings.ToLower(strings.TrimSpace(*raw))]
}
