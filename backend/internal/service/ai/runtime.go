package ai

import (
	"context"
	"fmt"
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
	// Vision 该模型是否带视觉能力（供界面提示：非视觉模型不适合跑 VLM 标注）
	Vision bool `json:"vision"`
}

// ExecutorCandidates 返回该能力的执行者候选与当前选择。
//
// VLM 的候选实时来自本机 Ollama 已安装模型（配置里的两个候选始终保留，未安装时标注出来），
// 因此用户自行 ollama pull/rm 增删模型后无需改代码或重启：两端都只渲染这里下发的列表。
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
		cfg := e.rt.Config()
		installed := e.installedModelInfo()
		// 配置里的两个候选保留友好名称；其余（用户自行拉的）直接用模型名。
		labels := map[string]string{
			strings.ToLower(cfg.OllamaVLM):    "标准版",
			strings.ToLower(cfg.OllamaVLMAlt): "无审查版",
		}
		seen := map[string]bool{}
		candidates := make([]ExecutorCandidate, 0, len(installed)+2)
		// add 以"已安装时的真实模型名"为准：Ollama 的模型名大小写不敏感，
		// 用配置里的写法发请求会与该模型在库里的名字对不上。
		add := func(configName string, info ModelInfo, ok bool) {
			key := strings.ToLower(strings.TrimSpace(configName))
			if key == "" || seen[key] {
				return
			}
			seen[key] = true
			name := strings.TrimSpace(configName)
			if ok {
				name = info.Name
			}
			candidates = append(candidates, ExecutorCandidate{
				Model:     name,
				Label:     labelOr(labels[key], name),
				Installed: ok,
				Vision:    ok && info.Vision,
			})
		}
		for _, name := range []string{cfg.OllamaVLM, cfg.OllamaVLMAlt} {
			info, ok := installed[strings.ToLower(strings.TrimSpace(name))]
			add(name, info, ok)
		}
		names := make([]string, 0, len(installed))
		for key := range installed {
			names = append(names, key)
		}
		sort.Strings(names)
		for _, key := range names {
			add(installed[key].Name, installed[key], true)
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

// installedModelInfo 返回本机已安装的 Ollama 模型（键为小写模型名；不可达时返回空集合）。
//
// 键统一小写：Ollama 的模型名大小写不敏感（`huihui_ai/qwen3.5-abliterated:4b`
// 与配置里的 `:4B` 是同一个模型），按原样比较会把已安装的候选判成未安装。
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
// 空串表示沿用当前生效模型；非空时必须是本机已安装的模型（Ollama 不可达时无法确认，
// 直接拒绝并说明），因此用户增删模型后两端都能立刻切换，不需要改代码。
func (e *Engine) NormalizeModel(requested string) (string, error) {
	selected := strings.TrimSpace(requested)
	if selected == "" {
		return e.VLMModel(), nil
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
