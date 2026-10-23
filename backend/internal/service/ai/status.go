package ai

import (
	"context"
	"fmt"
	"strings"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
)

// sidecarRequirement 某能力对侧车依赖的要求。
type sidecarRequirement struct {
	packages []string // python 包（探针返回的 key）
	models   []string // 模型（探针返回的 key）
}

// sidecarRequires 侧车能力的依赖清单，与 tools/ai/ronin_ai/probe.py 的返回键一致。
var sidecarRequires = map[string]sidecarRequirement{
	model.CapEmbed: {
		packages: []string{"onnxruntime", "numpy", "PIL", "tokenizers"},
		models:   []string{"siglip_vision", "siglip_text", "siglip_tokenizer"},
	},
	model.CapFace: {
		packages: []string{"onnxruntime", "numpy", "cv2"},
		models:   []string{"face_buffalo_l"},
	},
	model.CapOCR: {
		packages: []string{"onnxruntime", "rapidocr"},
	},
}

// CapabilityReady 报告某能力当前是否可执行；不可用时给出可读原因。
func (e *Engine) CapabilityReady(ctx context.Context, capability string) (bool, string) {
	if !model.IsValidCapability(capability) {
		return false, "未知能力"
	}
	if capability == model.CapPHash {
		return true, "" // 纯 Go 实现，无外部依赖
	}
	if capability == model.CapVLM {
		if strings.TrimSpace(e.VLMModel()) == "" {
			return false, "尚未选定标注模型：本机没有可用的 Ollama 模型"
		}
		if ok, reason := e.ollama.Ready(ctx, e.VLMModel()); !ok {
			return false, reason
		}
		return true, ""
	}

	sidecar := e.sidecarFor(capability)
	if sidecar == nil {
		return false, "该能力无对应侧车"
	}
	if ok, reason := sidecar.Installed(); !ok {
		return false, reason
	}
	probe := sidecar.Probe(ctx)
	if probe == nil || !probe.OK {
		reason := "侧车探测失败"
		if probe != nil && probe.Error != "" {
			reason = probe.Error
		}
		return false, reason
	}

	requirement := sidecarRequires[capability]
	for _, pkg := range requirement.packages {
		if _, ok := probe.Packages[pkg]; !ok {
			return false, fmt.Sprintf("缺少 python 包 %s（运行 tools/ai/install.ps1）", pkg)
		}
	}
	for _, name := range requirement.models {
		if !probe.Models[name] {
			return false, fmt.Sprintf("缺少模型 %s（运行 tools/ai/install.ps1）", name)
		}
	}
	return true, ""
}

func (e *Engine) sidecarFor(capability string) *Sidecar {
	switch capability {
	case model.CapEmbed:
		return e.embed
	case model.CapFace:
		return e.face
	case model.CapOCR:
		return e.ocr
	default:
		return nil
	}
}

// CapabilityStatus 单个能力的就绪与运行状态。
type CapabilityStatus struct {
	model.CapabilitySpec
	Ready        bool                `json:"ready"`
	Reason       string              `json:"reason,omitempty"`
	Sidecar      *SidecarState       `json:"sidecar,omitempty"`
	Candidates   []ExecutorCandidate `json:"executor_candidates,omitempty"`
	MissingMedia int                 `json:"missing_media"` // 尚无该产物的媒体数
	StaleMedia   int                 `json:"stale_media"`   // 输入档位/执行者已变、待显式重生成的媒体数
	Pending      int                 `json:"pending"`
	Failed       int                 `json:"failed"`
	Done         int                 `json:"done"`
}

// IndexState 向量索引状态。
type IndexState struct {
	Model       string `json:"model"`
	Vectors     int    `json:"vectors"`
	Loaded      bool   `json:"loaded"`
	MemoryBytes int64  `json:"memory_estimate_bytes"`
}

// Status AI 处理层整体状态（供 /API/ai/status 与桌面端展示）。
type Status struct {
	Enabled          bool                     `json:"enabled"`
	SchemaReady      bool                     `json:"schema_ready"`
	Started          bool                     `json:"started"`
	ConfigPath       string                   `json:"config_path"`
	EmbedModel       string                   `json:"embed_model"`
	Device           string                   `json:"device"`
	Workers          int                      `json:"workers"`
	BatchSize        int                      `json:"batch_size"`
	IdleTimeoutS     int                      `json:"idle_timeout_seconds"`
	JobTimeoutS      int                      `json:"job_timeout_seconds"`
	MaxAttempts      int                      `json:"max_attempts"`
	Paused           bool                     `json:"paused"`
	AutoCapabilities []string                 `json:"auto_capabilities"`
	Capabilities     []CapabilityStatus       `json:"capabilities"`
	Queue            []model.AiCapabilityStat `json:"queue"`
	PendingTotal     int                      `json:"pending_total"`
	FailedTotal      int                      `json:"failed_total"`
	// MediaTotal 未删除媒体总数：能力进度的分母。
	// 「尚无产物」是另一个口径（人脸能力里"这张图本来就没有脸"也是正常的 0 产物），
	// 把它加进分母会把同一批媒体算两遍。
	MediaTotal  int          `json:"media_total"`
	LastRun     *RunInfo     `json:"last_run,omitempty"`
	Index       IndexState   `json:"index"`
	Cluster     ClusterState `json:"cluster"`
	Ollama      OllamaState  `json:"ollama"`
	PersonCount int          `json:"person_count"`
}

// Status 按需采集统计与依赖诊断；日常轮询使用 Progress。
func (e *Engine) Status(ctx context.Context) *Status {
	cfg := e.Config()
	status := &Status{
		Enabled:      cfg.Enabled,
		SchemaReady:  ai_repo.SchemaReady(ctx),
		Started:      e.started,
		EmbedModel:   cfg.EmbedModel,
		Device:       cfg.Device,
		Workers:      cfg.Workers,
		BatchSize:    cfg.BatchSize,
		IdleTimeoutS: int(cfg.IdleTimeout.Seconds()),
		JobTimeoutS:  int(cfg.JobTimeout.Seconds()),
		MaxAttempts:  cfg.MaxAttempts,
		Paused:       e.paused.Load(),
		LastRun:      e.LastRun(),
		Ollama:       e.ollama.snapshot(e.VLMModel()),
		Cluster:      e.cluster.State(),
		Index: IndexState{
			Model:   cfg.EmbedModel,
			Vectors: e.index.VectorCount(),
			Loaded:  e.index.Loaded(),
		},
	}

	if !cfg.Enabled {
		return status
	}
	status.Ollama = e.ollamaState(ctx)
	if !status.SchemaReady {
		return status
	}

	status.AutoCapabilities = e.AutoCapabilities()
	status.ConfigPath = e.ConfigPath()
	status.Index.MemoryBytes = int64(status.Index.Vectors) * int64(dimEstimate)

	stats, err := ai_repo.Stats()
	if err == nil {
		status.Queue = stats
	}
	if total, err := ai_repo.CountUndeletedMedia(); err == nil {
		status.MediaTotal = total
	}
	if persons, err := ai_repo.ListPersons(); err == nil {
		status.PersonCount = len(persons)
	}

	byCap := map[string]model.AiCapabilityStat{}
	for _, stat := range status.Queue {
		byCap[stat.Capability] = stat
		status.PendingTotal += stat.Pending + stat.Running
		status.FailedTotal += stat.Failed
	}

	missing, _ := ai_repo.CountMediaMissingAll()
	specs := e.CapabilitySpecs()

	for _, spec := range specs {
		ready, reason := e.CapabilityReady(ctx, spec.Capability)
		item := CapabilityStatus{
			CapabilitySpec: spec,
			Ready:          ready,
			Reason:         reason,
			Candidates:     e.ExecutorCandidates(spec.Capability, spec.Executor),
		}
		if stat, ok := byCap[spec.Capability]; ok {
			item.Pending = stat.Pending + stat.Running
			item.Failed = stat.Failed
			item.Done = stat.Done
		}
		if sidecar := e.sidecarFor(spec.Capability); sidecar != nil {
			state := sidecar.State(ctx)
			item.Sidecar = &state
		}
		item.MissingMedia = missing[spec.Capability]
		// 输入档位/执行者变更后可显式重生成的数量。
		if stale, err := ai_repo.CountStaleInput(spec.Capability, spec.InputSig); err == nil {
			item.StaleMedia = stale
		}
		status.Capabilities = append(status.Capabilities, item)
	}
	return status
}

// ollamaState 采集 Ollama 状态，并补上"当前正在推理的模型"这一运行时信息。
func (e *Engine) ollamaState(ctx context.Context) OllamaState {
	state := e.ollama.State(ctx, e.VLMModel())
	state.ActiveModel = e.ActiveModel()
	state.LastSwitch = e.LastSwitchNotice()
	return state
}

// dimEstimate 向量维度估算（SigLIP base 为 768；仅用于内存占用展示）。
var dimEstimate = 768

// Index 暴露索引以便 handler 触发重建。
func (e *Engine) Index() *Index { return e.index }

// Cluster 暴露聚类器以便 handler 调用。
func (e *Engine) Cluster() *Clusterer { return e.cluster }

// ClusterLock 串行化人工聚类操作（重新聚类耗时较长，避免并发重复执行）。
func (e *Engine) ClusterLock() { e.clusterRun.Lock() }

// ClusterUnlock 释放聚类串行锁。
func (e *Engine) ClusterUnlock() { e.clusterRun.Unlock() }

// Sidecar 暴露指定能力的侧车以便"启动/停止模型"。
func (e *Engine) Sidecar(capability string) *Sidecar { return e.sidecarFor(capability) }

// OllamaProvider 暴露 Ollama 以便状态与启停。
func (e *Engine) OllamaProvider() *Ollama { return e.ollama }
