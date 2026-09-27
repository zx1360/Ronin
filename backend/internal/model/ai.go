package model

import (
	"time"

	"github.com/google/uuid"
)

// AI 能力标识。phash 在 Go 进程内完成，其余通过外部进程接入。
const (
	CapPHash = "phash" // 感知哈希（纯 Go，无外部进程）
	CapEmbed = "embed" // SigLIP 图像向量
	CapFace  = "face"  // InsightFace 人脸检测与特征
	CapOCR   = "ocr"   // RapidOCR / PP-OCR 文字识别
	CapVLM   = "vlm"   // Ollama VLM 描述与关键词
)

// AllCapabilities 全部能力，顺序即处理优先级（廉价能力优先）。
var AllCapabilities = []string{CapPHash, CapEmbed, CapFace, CapOCR, CapVLM}

// IsValidCapability 报告能力标识是否受支持。
func IsValidCapability(capability string) bool {
	for _, c := range AllCapabilities {
		if c == capability {
			return true
		}
	}
	return false
}

// AI 能力的输入档位。phash/embed 用 256 预览图；face/ocr/vlm 需要更大分辨率。
// AI 专用派生档只有这一个新增档位，PreviewSize 的语义与用途不变。
const (
	TierPreview256 = "preview256"
	TierAI1024     = "ai1024"
)

// AIInputTier 返回能力对应的输入档位。
func AIInputTier(capability string) string {
	switch capability {
	case CapPHash, CapEmbed:
		return TierPreview256
	default:
		return TierAI1024
	}
}

// 固定能力实现的稳定标识（写入 ai_results.executor，作为结果溯源的执行者）。
// 标识一旦变更，既有结果会被判定为失配并自动重排。
const (
	ImplPHashGoDCT  = "go-dct-phash-v1"
	ImplFaceSidecar = "buffalo_l"
	ImplOCRSidecar  = "rapidocr"
)

// LegacyInputTier 是迁移前所有 AI 结果实际使用的输入档位：旧代码统一喂 256 预览图。
// 迁移按此如实登记溯源，face/ocr/vlm 因此会被判定为失配并自动改用 ai1024 重排。
const LegacyInputTier = TierPreview256

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
