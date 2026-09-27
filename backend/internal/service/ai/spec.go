package ai

import (
	"context"
	"strings"

	"monarch/internal/model"
)

// 本文件集中定义"能力的执行者与候选"，是结果溯源（ai_results）与
// /API/ai/capabilities 的唯一真相源：消费端只渲染后端下发的清单。

// capabilityLabels 能力的展示名。
var capabilityLabels = map[string]string{
	model.CapPHash: "感知哈希",
	model.CapEmbed: "图像向量",
	model.CapFace:  "人脸检测与特征",
	model.CapOCR:   "文字识别",
	model.CapVLM:   "视觉描述与关键词",
}

// buildinImplementations 无法选择的固定实现（本机只有一个可用实现）。
var buildinImplementations = map[string][]model.AiImplementation{
	model.CapPHash: {{ID: model.ImplPHashGoDCT, Label: "Go DCT pHash", Note: "进程内计算，无外部依赖"}},
	model.CapFace:  {{ID: model.ImplFaceSidecar, Label: "InsightFace buffalo_l", Note: "Python 侧车"}},
	model.CapOCR:   {{ID: model.ImplOCRSidecar, Label: "RapidOCR", Note: "Python 侧车"}},
}

// Executor 返回能力当前的执行者标识（写入 ai_results.executor）。
func (e *Engine) Executor(capability string) string {
	switch capability {
	case model.CapPHash:
		return model.ImplPHashGoDCT
	case model.CapEmbed:
		return strings.TrimSpace(e.cfg.EmbedModel)
	case model.CapFace:
		return model.ImplFaceSidecar
	case model.CapOCR:
		return model.ImplOCRSidecar
	case model.CapVLM:
		return e.VLMModel()
	default:
		return ""
	}
}

// InputTier 返回能力的输入档位。
func (e *Engine) InputTier(capability string) string { return model.AIInputTier(capability) }

// executorSettingKeys 可切换执行者的能力对应的配置键；其余能力只有一个实现，无需切换。
var executorSettingKeys = map[string]string{
	model.CapEmbed: "ai.embed_model",
	model.CapVLM:   "ai.vlm_model",
}

// CapabilityInfos 下发全部能力的输入档位、当前执行者与候选清单。
//
// 消费端（前端 / ops 页面）只负责渲染，不在端上硬编码能力名、模型名与配置键。
func (e *Engine) CapabilityInfos(ctx context.Context) []model.AiCapabilityInfo {
	infos := make([]model.AiCapabilityInfo, 0, len(model.AllCapabilities))
	for _, capability := range model.AllCapabilities {
		ready, reason := e.CapabilityReady(ctx, capability)
		infos = append(infos, model.AiCapabilityInfo{
			Capability: capability,
			Label:      capabilityLabels[capability],
			InputTier:  e.InputTier(capability),
			Selected:   e.Executor(capability),
			Ready:      ready,
			Reason:     reason,
			Candidates: e.candidates(capability),
			SettingKey: executorSettingKeys[capability],
		})
	}
	return infos
}

// candidates 返回能力的候选执行者；当前选择始终排在首位。
func (e *Engine) candidates(capability string) []model.AiImplementation {
	switch capability {
	case model.CapEmbed:
		return embedCandidates(e.cfg.EmbedModel)
	case model.CapVLM:
		return vlmCandidates(e.cfg.OllamaVLM, e.cfg.OllamaVLMAlt, e.VLMModel())
	default:
		return buildinImplementations[capability]
	}
}

// embedCandidates 返回向量模型的候选。
//
// 侧车把权重固定在 `tools/ai/models/siglip/`，请求里的 `model` 只是"向量空间标识"，
// 不会切换实际权重。因此这里只有当前值一个候选：改这个标识等于声明"权重换了"，
// 会让既有向量失效并自动重排——这正是不该随手给出一堆假候选的原因。
func embedCandidates(current string) []model.AiImplementation {
	current = strings.TrimSpace(current)
	if current == "" {
		return nil
	}
	return []model.AiImplementation{{
		ID:    current,
		Label: current,
		Note:  "向量空间标识；权重固定为 tools/ai/models/siglip",
	}}
}

// vlmCandidates 列出 Ollama 模型候选：标准版与备选（无审查）版。
func vlmCandidates(def, alt, selected string) []model.AiImplementation {
	out := make([]model.AiImplementation, 0, 2)
	seen := map[string]bool{}
	add := func(id, label, note string) {
		id = strings.TrimSpace(id)
		if id == "" || seen[id] {
			return
		}
		seen[id] = true
		out = append(out, model.AiImplementation{ID: id, Label: label, Note: note})
	}
	// 当前选择排首位，其次标准版与备选版。
	add(selected, selected, "当前使用")
	add(def, def, "默认（标准版）")
	add(alt, alt, "备选（无审查版，保留视觉能力）")
	return out
}
