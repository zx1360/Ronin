package ai

import (
	"context"
	"strings"

	"monarch/internal/model"
)

// 本文件把 model.Capabilities 这份唯一登记翻译成运行时视图（执行者、候选清单），
// 是结果溯源（ai_results）与 /API/ai/capabilities 的出口：消费端只渲染后端下发的清单。

// Executor 返回能力当前的执行者标识（写入 ai_results.executor）：执行者可由配置切换的
// 能力取配置值，其余取登记里的固定实现。
func (e *Engine) Executor(capability string) string {
	switch capability {
	case model.CapEmbed:
		return strings.TrimSpace(e.cfg.EmbedModel)
	case model.CapVLM:
		return e.VLMModel()
	}
	if c, ok := model.CapabilityByID(capability); ok {
		return c.BuiltinExecutor()
	}
	return ""
}

// InputTier 返回能力的输入档位。
func (e *Engine) InputTier(capability string) string { return model.AIInputTier(capability) }

// CapabilityInfos 下发全部能力的输入档位、当前执行者与候选清单。
//
// 消费端（前端 / ops 页面）只负责渲染，不在端上硬编码能力名、模型名与配置键。
func (e *Engine) CapabilityInfos(ctx context.Context) []model.AiCapabilityInfo {
	infos := make([]model.AiCapabilityInfo, 0, len(model.Capabilities))
	for _, c := range model.Capabilities {
		ready, reason := e.CapabilityReady(ctx, c.ID)
		infos = append(infos, model.AiCapabilityInfo{
			Capability: c.ID,
			Label:      c.Label,
			InputTier:  c.InputTier,
			Selected:   e.Executor(c.ID),
			Ready:      ready,
			Reason:     reason,
			Candidates: e.candidates(c.ID),
			SettingKey: c.SettingKey,
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
	}
	if c, ok := model.CapabilityByID(capability); ok {
		return c.Builtin
	}
	return nil
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
