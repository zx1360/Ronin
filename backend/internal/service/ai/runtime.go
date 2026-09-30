package ai

import (
	"context"
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

// SetVLMModel 记录 VLM 标注模型的人工选择（空串 = 恢复 .env 默认）。
func (e *Engine) SetVLMModel(model string) error {
	if err := e.rt.store.Update(config.RuntimeConfig{VLMModel: &model}); err != nil {
		return err
	}
	e.rt.mu.Lock()
	e.rt.vlmModel = model
	e.rt.mu.Unlock()
	e.Wake()
	return nil
}

// VLMModel 返回当前生效的 VLM 模型（人工选择优先，其次 .env 默认值）。
func (e *Engine) VLMModel() string {
	e.rt.mu.RLock()
	model := e.rt.vlmModel
	e.rt.mu.RUnlock()
	if model != "" {
		return model
	}
	return e.rt.Config().OllamaVLM
}

// VLMAltModel 返回备选（无审查版）模型名。
func (e *Engine) VLMAltModel() string { return e.rt.Config().OllamaVLMAlt }

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
	Model      string `json:"model"`
	Label      string `json:"label"`
	Installed  bool   `json:"installed"`
	IsCurrent  bool   `json:"is_current"`
	InputsTier string `json:"input_tier"`
}

// executorCandidates 返回该能力的执行者候选与当前选择。
//
// 只有 VLM 有多个候选（标准版 / 无审查版，同一模型承接标注与对话）；
// 其余能力固定一种实现，仍然下发列表以便消费端统一渲染而不必在端上硬编码。
func (e *Engine) ExecutorCandidates(capability, current string) []ExecutorCandidate {
	apply := func(candidates []ExecutorCandidate) []ExecutorCandidate {
		for i := range candidates {
			candidates[i].IsCurrent = candidates[i].Model == current
			candidates[i].InputsTier = e.inputTier(capability)
		}
		return candidates
	}

	switch capability {
	case model.CapVLM:
		cfg := e.rt.Config()
		installed := e.installedModels()
		labels := map[string]string{
			cfg.OllamaVLM:    "标准版",
			cfg.OllamaVLMAlt: "无审查版",
		}
		seen := map[string]bool{}
		candidates := make([]ExecutorCandidate, 0, 2)
		for _, name := range []string{cfg.OllamaVLM, cfg.OllamaVLMAlt} {
			if name == "" || seen[name] {
				continue
			}
			seen[name] = true
			candidates = append(candidates, ExecutorCandidate{
				Model:     name,
				Label:     labelOr(labels[name], name),
				Installed: installed[name],
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
			Label:     spec.Executor,
			Installed: true,
		}})
	}
}

// labelOr 返回标签，空则退回模型名。
func labelOr(label, fallback string) string {
	if label != "" {
		return label
	}
	return fallback
}

// installedModels 返回本机已安装的 Ollama 模型集合（不可达时返回空集合）。
func (e *Engine) installedModels() map[string]bool {
	names := map[string]bool{}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	tags, err := e.ollama.ListModels(ctx)
	if err != nil {
		return names
	}
	for _, name := range tags {
		names[name] = true
	}
	return names
}
