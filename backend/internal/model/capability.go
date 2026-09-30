package model

// 本文件是 AI 能力的**唯一权威登记**：能力标识、展示名、输入档位、默认优先级、
// 固定实现与执行者配置键都只写一遍，设置项候选项、溯源执行者、/API/ai/capabilities
// 与两端 UI 一律从这里派生。新增一个能力只需在本文件末尾的 Capabilities 里加一条，
// 并补上它在 service/ai 里的执行实现。

// AI 能力标识。phash 在 Go 进程内完成，其余通过外部进程接入。
const (
	CapPHash = "phash" // 感知哈希（纯 Go，无外部进程）
	CapEmbed = "embed" // SigLIP 图像向量
	CapFace  = "face"  // InsightFace 人脸检测与特征
	CapOCR   = "ocr"   // RapidOCR / PP-OCR 文字识别
	CapVLM   = "vlm"   // Ollama VLM 描述与关键词
)

// 固定能力实现的稳定标识（写入 ai_results.executor，作为结果溯源的执行者）。
// 标识一旦变更，既有结果会被判定为失配并自动重排。
const (
	ImplPHashGoDCT  = "go-dct-phash-v1"
	ImplFaceSidecar = "buffalo_l"
	ImplOCRSidecar  = "rapidocr"
)

// AI 能力的输入档位。phash/embed 用 256 预览图；face/ocr/vlm 需要更大分辨率。
// AI 专用派生档只有这一个新增档位，PreviewSize 的语义与用途不变。
const (
	TierPreview256 = "preview256"
	TierAI1024     = "ai1024"
)

// LegacyInputTier 是迁移前所有 AI 结果实际使用的输入档位：旧代码统一喂 256 预览图。
// 迁移按此如实登记溯源，face/ocr/vlm 因此会被判定为失配并自动改用 ai1024 重排。
const LegacyInputTier = TierPreview256

// Capability 一个 AI 能力的登记项。
type Capability struct {
	ID        string
	Label     string
	InputTier string
	// Priority 越小越先处理（廉价能力优先），决定 worker 认领任务的顺序。
	Priority int
	// AutoDefault 表示该能力默认参与"入库后自动处理"。
	AutoDefault bool
	// Builtin 是唯一的固定实现（没有可切换的候选）；执行者由配置决定的能力留空。
	Builtin []AiImplementation
	// SettingKey 是切换执行者时要写入的配置键；空表示不可切换。
	// 有了它，消费端不必自己维护"能力 → 配置键"的对照表。
	SettingKey string
}

// Capabilities 全部能力的权威登记，顺序即处理优先级（廉价能力优先）。
var Capabilities = []Capability{
	{ID: CapPHash, Label: "感知哈希", InputTier: TierPreview256, Priority: 10, AutoDefault: true,
		Builtin: []AiImplementation{
			{ID: ImplPHashGoDCT, Label: "Go DCT pHash", Note: "进程内计算，无外部依赖"},
		}},
	{ID: CapEmbed, Label: "图像向量", InputTier: TierPreview256, Priority: 20, AutoDefault: true,
		SettingKey: "ai.embed_model"},
	{ID: CapFace, Label: "人脸检测与特征", InputTier: TierAI1024, Priority: 30, AutoDefault: true,
		Builtin: []AiImplementation{
			{ID: ImplFaceSidecar, Label: "InsightFace buffalo_l", Note: "Python 侧车"},
		}},
	{ID: CapOCR, Label: "文字识别", InputTier: TierAI1024, Priority: 40, AutoDefault: true,
		Builtin: []AiImplementation{
			{ID: ImplOCRSidecar, Label: "RapidOCR", Note: "Python 侧车"},
		}},
	{ID: CapVLM, Label: "视觉描述与关键词", InputTier: TierAI1024, Priority: 100,
		SettingKey: "ai.vlm_model"},
}

var capabilityByID = func() map[string]Capability {
	m := make(map[string]Capability, len(Capabilities))
	for _, c := range Capabilities {
		m[c.ID] = c
	}
	return m
}()

// AllCapabilities 全部能力标识，顺序即处理优先级（廉价能力优先）。
var AllCapabilities = capabilityIDs()

// CapabilityByID 返回能力登记；未登记的能力 ok 为 false。
func CapabilityByID(id string) (Capability, bool) {
	c, ok := capabilityByID[id]
	return c, ok
}

// IsValidCapability 报告能力标识是否受支持。
func IsValidCapability(capability string) bool {
	_, ok := capabilityByID[capability]
	return ok
}

// AIInputTier 返回能力对应的输入档位；未登记的能力按 ai1024 处理。
func AIInputTier(capability string) string {
	if c, ok := capabilityByID[capability]; ok {
		return c.InputTier
	}
	return TierAI1024
}

// CapabilityPriority 返回能力的默认优先级；未登记的能力为 0。
func CapabilityPriority(capability string) int {
	if c, ok := capabilityByID[capability]; ok {
		return c.Priority
	}
	return 0
}

// BuiltinExecutor 返回该能力固定实现的标识；无固定实现（执行者可选）时为空。
func (c Capability) BuiltinExecutor() string {
	if len(c.Builtin) == 0 {
		return ""
	}
	return c.Builtin[0].ID
}

func capabilityIDs() []string {
	out := make([]string, 0, len(Capabilities))
	for _, c := range Capabilities {
		out = append(out, c.ID)
	}
	return out
}
