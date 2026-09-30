package ai_handler

import (
	"errors"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"
	"sync"
	"unicode/utf8"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/service/ai"
	"monarch/internal/service/review"
)

// 回顾的范围与长度上限：超出即 400，不静默夹取。
const (
	reviewDefaultDays   = 30
	reviewMaxDays       = 730
	reviewMaxRoleRunes  = 1000
	reviewMaxToneRunes  = 500
	reviewMaxFocusRunes = 500
	// 未指定抽样条数时的默认值：给模型一点具体材料，又不至于挤占上下文。
	defaultSampleEssays  = 3
	defaultSampleRecords = 3
)

// 预设存储延迟初始化：只有真正用到该功能时才读写文件，
// 避免 route_export 之类的只读进程也生成一份配置文件。
var (
	reviewStoreOnce sync.Once
	reviewStore     *config.ReviewPresetStore
	reviewStoreErr  error
)

func presets() (*config.ReviewPresetStore, error) {
	reviewStoreOnce.Do(func() {
		store := config.NewReviewPresetStore(filepath.Join(config.AppConf.StaticDir, "data", "review_presets.json"))
		if err := store.Load(); err != nil {
			reviewStoreErr = err
			return
		}
		reviewStore = store
	})
	return reviewStore, reviewStoreErr
}

// GetReviewPresets 处理 GET /API/ai/review/presets：下发给端上做本地镜像。
func GetReviewPresets(c *gin.Context) {
	store, err := presets()
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"presets": store.Snapshot(), "path": store.Path()})
}

// UpdateReviewPresets 处理 PUT /API/ai/review/presets：整体替换（服务端权威）。
func UpdateReviewPresets(c *gin.Context) {
	store, err := presets()
	if err != nil {
		fail(c, err)
		return
	}

	var req struct {
		Presets []config.ReviewPreset `json:"presets"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
		return
	}
	if err := store.Replace(req.Presets); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"presets": store.Snapshot(), "path": store.Path()})
}

// reviewRequest POST /API/ai/review 请求体。
type reviewRequest struct {
	chatTuning
	// From/To 为 `YYYY-MM-DD` 日历日（闭区间）；都缺省时按 Days 回溯到今天。
	From string `json:"from"`
	To   string `json:"to"`
	Days int    `json:"days"`
	// Role/Tone 直接由端上预设下发：服务端不查表，未保存的临时编辑也能立即生成。
	Role  string `json:"role"`
	Tone  string `json:"tone"`
	Focus string `json:"focus"`
	// 随机抽样条数；0 表示只给统计、不给具体材料。
	SampleEssays  *int `json:"sample_essays"`
	SampleRecords *int `json:"sample_records"`
}

// Review 处理 POST /API/ai/review：确定性统计 + 可选随机素材，交给本地模型写成叙述。
//
// 与 /chat 同为 NDJSON 流；正文之前先下发一条 `stats` 事件（本次依据的统计文本），
// 端上可直接展示以便核对叙述没有跑偏。生成结果由端上本地缓存，服务端不落库。
func Review(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, chatMaxBodyBytes)
	var req reviewRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
		return
	}

	role := strings.TrimSpace(req.Role)
	if role == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "role（角色设定）不能为空"})
		return
	}
	tone := strings.TrimSpace(req.Tone)
	focus := strings.TrimSpace(req.Focus)
	for _, item := range []struct {
		label string
		value string
		limit int
	}{
		{"角色设定", role, reviewMaxRoleRunes},
		{"语气要求", tone, reviewMaxToneRunes},
		{"关注点", focus, reviewMaxFocusRunes},
	} {
		if utf8.RuneCountInString(item.value) > item.limit {
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("%s最多 %d 字", item.label, item.limit)})
			return
		}
	}

	scope, err := reviewScope(req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	wantEssays, err := sampleCount("sample_essays", req.SampleEssays, defaultSampleEssays, review.MaxSampleEssays)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	wantRecords, err := sampleCount("sample_records", req.SampleRecords, defaultSampleRecords, review.MaxSampleRecords)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	data, err := review.Collect(scope, wantEssays, wantRecords)
	if err != nil {
		fail(c, err)
		return
	}

	modelName, options, err := req.chatTuning.resolve(e)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	system, user := review.Prompts(role, tone, focus, data)
	streamChat(c, e, "回顾", modelName, options,
		[]ai.ChatMessage{{Role: "system", Content: system}, {Role: "user", Content: user}},
		ai.ChatEvent{Type: "stats", Content: data.Stats.Text()},
	)
}

// reviewScope 解析时间范围：优先 from/to，其次 days，都缺省时取最近 30 天。
func reviewScope(req reviewRequest) (review.Range, error) {
	to := review.Today()
	if raw := strings.TrimSpace(req.To); raw != "" {
		parsed, err := review.Date(raw)
		if err != nil {
			return review.Range{}, err
		}
		to = parsed
	}

	days := req.Days
	if days == 0 {
		days = reviewDefaultDays
	}
	if days < 1 || days > reviewMaxDays {
		return review.Range{}, fmt.Errorf("days 超出范围 1-%d", reviewMaxDays)
	}

	from := to.AddDate(0, 0, -(days - 1))
	if raw := strings.TrimSpace(req.From); raw != "" {
		parsed, err := review.Date(raw)
		if err != nil {
			return review.Range{}, err
		}
		from = parsed
	}
	if from.After(to) {
		return review.Range{}, errors.New("from 不能晚于 to")
	}
	return review.Range{From: from, To: to}, nil
}

// sampleCount 校验抽样条数（未指定时取默认值）。
func sampleCount(key string, requested *int, fallback, limit int) (int, error) {
	if requested == nil {
		return fallback, nil
	}
	if *requested < 0 || *requested > limit {
		return 0, fmt.Errorf("%s 超出范围 0-%d", key, limit)
	}
	return *requested, nil
}
