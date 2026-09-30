package model

import (
	"time"

	"github.com/google/uuid"
)

// AiResultSpec 一条 AI 结果的溯源信息：用了哪个输入档位、哪个执行者（实现或模型）。
// 与期望规格不一致时由 reconcile 循环自动重排。
type AiResultSpec struct {
	MediaID    uuid.UUID `json:"media_id"`
	Capability string    `json:"capability"`
	InputTier  string    `json:"input_tier"`
	Executor   string    `json:"executor"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// AiImplementation 一个能力实现或模型候选。
type AiImplementation struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Note  string `json:"note,omitempty"`
}

// AiCapabilityInfo 一个能力的输入档位、当前选择与候选清单；由后端下发，消费端只渲染。
type AiCapabilityInfo struct {
	Capability string             `json:"capability"`
	Label      string             `json:"label"`
	InputTier  string             `json:"input_tier"`
	Selected   string             `json:"selected"`
	Ready      bool               `json:"ready"`
	Reason     string             `json:"reason,omitempty"`
	Candidates []AiImplementation `json:"candidates"`
	// SettingKey 是切换该能力执行者时要写入的配置键；为空表示不可切换。
	// 有了它，消费端不必自己维护"能力 → 配置键"的对照表。
	SettingKey string `json:"setting_key,omitempty"`
}

// AiJob 一条 AI 处理任务（能力 × 媒体）。
type AiJob struct {
	ID         int64      `json:"id"`
	Capability string     `json:"capability"`
	MediaID    uuid.UUID  `json:"media_id"`
	Status     string     `json:"status"`
	Priority   int        `json:"priority"`
	Attempts   int        `json:"attempts"`
	LastError  *string    `json:"last_error"`
	StartedAt  *time.Time `json:"started_at"`
	FinishedAt *time.Time `json:"finished_at"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}

// AiCapabilityStat 单个能力的队列计数。
type AiCapabilityStat struct {
	Capability string `json:"capability"`
	Pending    int    `json:"pending"`
	Running    int    `json:"running"`
	Done       int    `json:"done"`
	Failed     int    `json:"failed"`
	Total      int    `json:"total"`
}

// AiPersonCount 人物分组条目。
type AiPerson struct {
	ID          uuid.UUID `json:"id"`
	Name        *string   `json:"name"`
	CoverFaceID *string   `json:"cover_face_id"`
	CoverMedia  *string   `json:"cover_media_id"`
	FaceCount   int       `json:"face_count"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// AiFace 单张人脸。
type AiFace struct {
	ID        uuid.UUID `json:"id"`
	MediaID   uuid.UUID `json:"media_id"`
	PersonID  *string   `json:"person_id"`
	Box       []float64 `json:"bbox"` // 归一化 x1,y1,x2,y2
	DetScore  float64   `json:"det_score"`
	Quality   float64   `json:"quality"`
	CreatedAt time.Time `json:"created_at"`
}

// AiMediaDetail 单个媒体的 AI 结果汇总。
type AiMediaDetail struct {
	MediaID   uuid.UUID `json:"media_id"`
	PHash     *int64    `json:"phash"`
	OCRText   *string   `json:"ocr_text"`
	Caption   *string   `json:"caption"`
	VLMTags   []string  `json:"vlm_tags"`
	HasVector bool      `json:"has_vector"`
	Faces     []AiFace  `json:"faces"`
}

// AiSearchHit 一条搜索结果（媒体 + 相关度）。
type AiSearchHit struct {
	MediaAsset
	Score  float64  `json:"score"`
	Source []string `json:"source"` // semantic / ocr / tag / person / caption / vlm_tag
}

// AiSearchResponse 组合搜索结果。
type AiSearchResponse struct {
	Hits  []AiSearchHit `json:"hits"`
	Total int           `json:"total"`
	Mode  string        `json:"mode"` // 本次实际使用的检索模式
}

// DuplicateGroup pHash 近重复分组。
type DuplicateGroup struct {
	Distance int         `json:"distance"`
	MediaIDs []uuid.UUID `json:"media_ids"`
	Files    []string    `json:"files"`
}
