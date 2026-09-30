package model

import (
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

// 输入图源档位。只分两档，且都复用 gallery 已有的派生图目录，
// 不新增档位、也不改动 media_assets.preview_path 的语义与用途。
const (
	// TierPreview 256 预览档（GALLERY_DIR/Preview）：体积小，够 pHash 与向量编码。
	TierPreview = "preview256"
	// TierAI 长边 1024 的 AI 专用派生档（GALLERY_DIR/AI，`*_ai.jpg`）：
	// 人脸与文字识别需要更多像素，256 档会明显掉质量。
	TierAI = "ai1024"
)

// CapabilitySpec 一个能力的输入与执行者契约。
//
// 由服务端唯一下发（`/API/ai/capabilities`）：消费端只渲染，不在端上硬编码能力语义；
// InputSig 是"输入档位 + 执行者"的指纹，任务与产物都记录它，用于判断产物是否仍然匹配，
// 不匹配即自动重排（换向量模型/换 VLM 模型后不必手工清库）。
type CapabilitySpec struct {
	Capability string `json:"capability"`
	Label      string `json:"label"`       // 简短动作，如"人脸识别"
	Description string `json:"description"` // 该能力产出什么、依赖什么
	InputTier  string `json:"input_tier"`  // preview256 / ai1024
	TierNote   string `json:"tier_note"`   // 档位的作用说明（如"长边 1024 派生图"）
	Executor   string `json:"executor"`    // 实际执行者（进程内实现 / 模型名 / Ollama 模型名）
	InputSig   string `json:"input_sig"`
}

// InputSignature 计算"输入档位 + 执行者"指纹。
func InputSignature(tier, executor string) string { return tier + "|" + executor }

// IsValidCapability 报告能力标识是否受支持。
func IsValidCapability(capability string) bool {
	for _, c := range AllCapabilities {
		if c == capability {
			return true
		}
	}
	return false
}

// AiJob 一条 AI 处理任务（能力 × 媒体）。
type AiJob struct {
	ID         int64     `json:"id"`
	Capability string    `json:"capability"`
	MediaID    uuid.UUID `json:"media_id"`
	Status     string    `json:"status"`
	Priority   int       `json:"priority"`
	Attempts   int       `json:"attempts"`
	LastError  *string   `json:"last_error"`
	// InputSig 执行时使用的"输入档位 + 执行者"指纹；空表示历史任务（旧版本未记录）
	InputSig   *string   `json:"input_sig"`
	StartedAt  *FlexTime `json:"started_at"`
	FinishedAt *FlexTime `json:"finished_at"`
	CreatedAt  FlexTime  `json:"created_at"`
	UpdatedAt  FlexTime  `json:"updated_at"`
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
	CreatedAt   FlexTime  `json:"created_at"`
	UpdatedAt   FlexTime  `json:"updated_at"`
}

// AiFace 单张人脸。
type AiFace struct {
	ID        uuid.UUID `json:"id"`
	MediaID   uuid.UUID `json:"media_id"`
	PersonID  *string   `json:"person_id"`
	Box       []float64 `json:"bbox"` // 归一化 x1,y1,x2,y2
	DetScore  float64   `json:"det_score"`
	Quality   float64   `json:"quality"`
	CreatedAt FlexTime  `json:"created_at"`
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
