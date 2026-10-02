package ai

import (
	"context"
	"fmt"
	"log"
	"sort"
	"strings"
	"sync"
	"time"

	"monarch/internal/config"
	"monarch/internal/model"
)

// 运行时配置与能力契约
//
// 引擎持有的配置是可变的：界面改完 <STATIC_DIR>/data/ai_config.json 后立即生效，
// 不必重启进程。所有读取都走快照，避免并发读写。

// runtimeStore 包一层互斥，保证配置副本的读写一致。
type runtimeStore struct {
	store *config.ConfigStore

	mu   sync.RWMutex
	snap config.AiConfig
	// vlmModel 数据库中的人工选择；空串表示沿用 .env 的默认模型
	vlmModel string
}

func newRuntimeStore(store *config.ConfigStore, snap config.AiConfig) *runtimeStore {
	if store == nil { // 单元测试等无配置文件场景：仅用内存副本
		store = config.NewConfigStore("", snap)
	}
	return &runtimeStore{store: store, snap: snap}
}

// Config 返回当前配置副本。
func (r *runtimeStore) Config() config.AiConfig {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.snap
}

// StorePath 返回配置文件路径（空串表示未启用文件存储）。
func (r *runtimeStore) StorePath() string {
	if r.store == nil {
		return ""
	}
	return r.store.Path()
}

// Update 应用运行时配置（写文件 + 刷新引擎使用的副本 + 唤醒 worker）。
func (e *Engine) UpdateRuntime(update config.RuntimeConfig) error {
	if err := e.rt.store.Update(update); err != nil {
		return err
	}
	// 模型选择由引擎侧单独持有（文件里存的是"人工选择"，空串表示沿用 .env 默认值）：
	// 不在这里同步的话，界面切换模型只会写进文件，要重启才生效。
	if update.VLMModel != nil {
		selected := strings.TrimSpace(*update.VLMModel)
		e.rt.mu.Lock()
		e.rt.vlmModel = selected
		e.rt.mu.Unlock()
	}
	return e.reloadRuntime()
}

// reloadRuntime 依据配置文件重建引擎使用的配置副本（模型选择另行维护）。
func (e *Engine) reloadRuntime() error {
	cfg := e.rt.Config()
	e.rt.store.ApplyTo(&cfg)
	e.rt.mu.Lock()
	e.rt.snap = cfg
	e.rt.mu.Unlock()
	e.Wake()
	return nil
}

// VLMModel 返回当前选定的 VLM 标注模型（空串 = 尚未选定；纯读，不做任何写入）。
func (e *Engine) VLMModel() string {
	e.rt.mu.RLock()
	model := e.rt.vlmModel
	e.rt.mu.RUnlock()
	return model
}

// ResolveVLMModel 返回当前选定的标注模型；从未选定时从本机已安装模型里挑一个并落盘。
//
// 只处理"从未选过"（首次部署、或界面清空选择）：挑一次之后不再自动改选——否则一次
// `ollama rm` 就会静默换掉执行者，进而按指纹把全库旧标注重排一遍。选定的模型已不在
// 本机时保留原值，由 CapabilityReady 如实报"未安装"，等用户自己重新选。
func (e *Engine) ResolveVLMModel() string {
	if current := e.VLMModel(); current != "" {
		return current
	}
	// 优先带视觉能力的模型：标注必须有视觉，纯文本模型会整批失败。
	pick := ""
	for _, candidate := range e.ExecutorCandidates(model.CapVLM, "") {
		if !candidate.Installed {
			continue
		}
		if candidate.Vision {
			pick = candidate.Model
			break
		}
		if pick == "" {
			pick = candidate.Model
		}
	}
	if pick == "" {
		return ""
	}
	if err := e.UpdateRuntime(config.RuntimeConfig{VLMModel: &pick}); err != nil {
		log.Printf("[AI] 保存自动选定的标注模型失败: %v", err)
		return pick
	}
	log.Printf("[AI] 未选定标注模型，已自动选用 %s（可在网页端切换）", pick)
	return pick
}

// AutoCapabilities 返回"入库后自动入队"的能力列表。
func (e *Engine) AutoCapabilities() []string {
	return e.rt.Config().AutoCaps
}

// ---------------------------------------------------------------------------
// 能力契约（由服务端唯一下发，消费端只渲染）
// ---------------------------------------------------------------------------

// capabilityStatic 能力的展示与档位信息（执行者按运行时配置补齐）。
type capabilityStatic struct {
	capability  string
	label       string
	description string
	tier        string
	executor    string
}

// capabilityStatics 顺序即处理优先级（廉价能力优先），与 model.AllCapabilities 一致。
var capabilityStatics = []capabilityStatic{
	{
		capability:  model.CapPHash,
		label:       "感知哈希去重",
		description: "服务进程内计算，无外部依赖",
		tier:        model.TierPreview,
		executor:    "go-dct-phash",
	},
	{
		capability:  model.CapEmbed,
		label:       "语义向量",
		description: "文本搜图 / 以图搜图",
		tier:        model.TierPreview,
		executor:    "siglip2-base-patch16-224",
	},
	{
		capability:  model.CapFace,
		label:       "人脸检测与分组",
		description: "SCRFD + ArcFace，自动归入人物",
		tier:        model.TierAI,
		executor:    "insightface-buffalo_l",
	},
	{
		capability:  model.CapOCR,
		label:       "OCR 文字识别",
		description: "PP-OCR，截图与表情包文字可检索",
		tier:        model.TierAI,
		executor:    "rapidocr-ppocr",
	},
	{
		capability:  model.CapVLM,
		label:       "VLM 自动标注",
		description: "Ollama 生成描述与关键词，耗时较长",
		tier:        model.TierAI,
		executor:    "", // 由当前 VLM 模型决定
	},
}

// tierNote 档位的作用说明（供消费端展示，避免端上自行解释档位含义）。
func tierNote(tier string) string {
	if tier == model.TierAI {
		return "长边 1024 的 AI 专用派生档（按需生成并缓存）"
	}
	return "256 预览档"
}

// CapabilitySpecs 返回全部能力的输入档位与执行者契约。
func (e *Engine) CapabilitySpecs() []model.CapabilitySpec {
	cfg := e.rt.Config()
	specs := make([]model.CapabilitySpec, 0, len(capabilityStatics))
	for _, item := range capabilityStatics {
		executor := item.executor
		switch item.capability {
		case model.CapEmbed:
			executor = cfg.EmbedModel
		case model.CapVLM:
			executor = "ollama:" + e.VLMModel()
		}
		specs = append(specs, model.CapabilitySpec{
			Capability:  item.capability,
			Label:       item.label,
			Description: item.description,
			InputTier:   item.tier,
			TierNote:    tierNote(item.tier),
			Executor:    executor,
			InputSig:    model.InputSignature(item.tier, executor),
		})
	}
	return specs
}

// capabilitySpec 返回单个能力的契约。
func (e *Engine) capabilitySpec(capability string) (model.CapabilitySpec, bool) {
	for _, spec := range e.CapabilitySpecs() {
		if spec.Capability == capability {
			return spec, true
		}
	}
	return model.CapabilitySpec{}, false
}

// inputTier 返回该能力应使用的输入档位（未知能力退回 256 档）。
func (e *Engine) inputTier(capability string) string {
	if spec, ok := e.capabilitySpec(capability); ok {
		return spec.InputTier
	}
	return model.TierPreview
}

// InputSignature 返回该能力当前的"输入档位 + 执行者"指纹（未知能力返回空串）。
func (e *Engine) InputSignature(capability string) string {
	if spec, ok := e.capabilitySpec(capability); ok {
		return spec.InputSig
	}
	return ""
}

// ---------------------------------------------------------------------------
// 执行者候选
// ---------------------------------------------------------------------------

// ExecutorCandidate 一个可选的执行者（模型）。
type ExecutorCandidate struct {
	Model string `json:"model"`
	// Installed 本机是否已安装（候选只列已安装模型，该字段恒为 true，留着便于端上统一渲染）
	Installed  bool   `json:"installed"`
	IsCurrent  bool   `json:"is_current"`
	InputsTier string `json:"input_tier"`
	// Vision 该模型是否带视觉能力（供界面提示：非视觉模型不适合跑 VLM 标注）
	Vision bool `json:"vision"`
}

// ExecutorCandidates 返回该能力的执行者候选与当前选择。
//
// VLM 的候选**实时来自本机 Ollama**（按模型名排序，只列已安装的），
// 因此用户自行 ollama pull/rm 增删模型后无需改配置、改代码或重启：两端都只渲染这里下发的列表。
// 其余能力固定一种实现，仍然下发列表以便消费端统一渲染而不必在端上硬编码。
func (e *Engine) ExecutorCandidates(capability, current string) []ExecutorCandidate {
	apply := func(candidates []ExecutorCandidate) []ExecutorCandidate {
		// current 是能力指纹里的执行者（VLM 形如 `ollama:<模型名>`），
		// 与候选的模型名对齐时要去掉提供者前缀，且模型名大小写不敏感。
		currentModel := strings.TrimPrefix(current, "ollama:")
		for i := range candidates {
			candidates[i].IsCurrent = strings.EqualFold(candidates[i].Model, currentModel)
			candidates[i].InputsTier = e.inputTier(capability)
		}
		return candidates
	}

	switch capability {
	case model.CapVLM:
		installed := e.installedModelInfo()
		names := make([]string, 0, len(installed))
		for key := range installed {
			names = append(names, key)
		}
		sort.Strings(names)
		candidates := make([]ExecutorCandidate, 0, len(names))
		for _, key := range names {
			info := installed[key]
			candidates = append(candidates, ExecutorCandidate{
				Model:     info.Name,
				Installed: true,
				Vision:    info.Vision,
			})
		}
		return apply(candidates)
	default:
		spec, ok := e.capabilitySpec(capability)
		if !ok {
			return nil
		}
		return apply([]ExecutorCandidate{{
			Model:     spec.Executor,
			Installed: true,
		}})
	}
}

// installedModelInfo 返回本机已安装的 Ollama 模型（键为小写模型名；不可达时返回空集合）。
//
// 键统一小写：Ollama 的模型名大小写不敏感（同一模型可能被写成 `:4b` 或 `:4B`），
// 按原样比较会把同一个模型判成两个。
func (e *Engine) installedModelInfo() map[string]ModelInfo {
	models := map[string]ModelInfo{}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	infos, err := e.ollama.ListModelInfo(ctx)
	if err != nil {
		return models
	}
	for _, info := range infos {
		models[strings.ToLower(info.Name)] = info
	}
	return models
}

// NormalizeModel 校验客户端指定的模型并归一化为本机实际使用的模型名。
//
// 空串表示沿用当前选定的模型；非空时必须是本机已安装的模型（Ollama 不可达时无法确认，
// 直接拒绝并说明），因此用户增删模型后两端都能立刻切换，不需要改代码。
func (e *Engine) NormalizeModel(requested string) (string, error) {
	selected := strings.TrimSpace(requested)
	if selected == "" {
		if current := e.VLMModel(); current != "" {
			return current, nil
		}
		return "", fmt.Errorf("尚未选定模型：本机没有可用的 Ollama 模型")
	}
	for _, candidate := range e.ExecutorCandidates(model.CapVLM, "ollama:"+e.VLMModel()) {
		if strings.EqualFold(candidate.Model, selected) && candidate.Installed {
			return candidate.Model, nil
		}
	}
	available := e.installedModelNames()
	if len(available) == 0 {
		return "", fmt.Errorf("模型 %s 不可用：本机 Ollama 未运行或未安装任何模型", selected)
	}
	return "", fmt.Errorf("模型 %s 不可用（本机已安装: %s）", selected, strings.Join(available, "、"))
}

// installedModelNames 返回本机已安装模型名（按名称排序，供错误提示）。
func (e *Engine) installedModelNames() []string {
	installed := e.installedModelInfo()
	names := make([]string, 0, len(installed))
	for _, info := range installed {
		names = append(names, info.Name)
	}
	sort.Strings(names)
	return names
}
