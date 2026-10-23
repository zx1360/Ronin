package ai

import (
	"context"
	"time"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
)

// Progress 只读取队列和内存进程状态，不探测外部依赖或统计媒体产物。
type Progress struct {
	Enabled      bool                     `json:"enabled"`
	SchemaReady  bool                     `json:"schema_ready"`
	Started      bool                     `json:"started"`
	Paused       bool                     `json:"paused"`
	Queue        []model.AiCapabilityStat `json:"queue"`
	PendingTotal int                      `json:"pending_total"`
	FailedTotal  int                      `json:"failed_total"`
	LastRun      *RunInfo                 `json:"last_run"`
	Index        IndexState               `json:"index"`
	Cluster      ClusterState             `json:"cluster"`
	Sidecars     []SidecarProcessState    `json:"sidecars"`
	Ollama       OllamaProcessState       `json:"ollama"`
}

func (e *Engine) Progress(ctx context.Context) *Progress {
	cfg := e.Config()
	state := &Progress{
		Enabled: cfg.Enabled, SchemaReady: ai_repo.SchemaReady(ctx), Started: e.started,
		Paused: e.paused.Load(), LastRun: e.LastRun(), Cluster: e.cluster.State(),
		Index:  IndexState{Model: cfg.EmbedModel, Vectors: e.index.VectorCount(), Loaded: e.index.Loaded()},
		Ollama: e.ollama.ProcessState(), Sidecars: []SidecarProcessState{},
	}
	state.Index.MemoryBytes = int64(state.Index.Vectors) * int64(dimEstimate)
	state.Ollama.ActiveModel, state.Ollama.LastSwitch = e.ActiveModel(), e.LastSwitchNotice()
	for _, sidecar := range []*Sidecar{e.embed, e.face, e.ocr} {
		state.Sidecars = append(state.Sidecars, sidecar.ProcessState())
	}
	if cfg.Enabled && state.SchemaReady {
		state.Queue, _ = ai_repo.Stats()
		for _, item := range state.Queue {
			state.PendingTotal += item.Pending + item.Running
			state.FailedTotal += item.Failed
		}
	}
	return state
}

type ChatInfo struct {
	Model            string              `json:"model"`
	ActiveModel      string              `json:"active_model"`
	Candidates       []ExecutorCandidate `json:"candidates"`
	NumCtx           int                 `json:"num_ctx"`
	KeepAliveSeconds int                 `json:"keep_alive_seconds"`
	Ready            bool                `json:"ready"`
}

func (e *Engine) ChatInfo(ctx context.Context) ChatInfo {
	cfg := e.Config()
	info := ChatInfo{Model: e.VLMModel(), ActiveModel: e.ActiveModel(), NumCtx: cfg.OllamaVLMCTX,
		KeepAliveSeconds: int(cfg.OllamaKeepAlive.Seconds()), Candidates: []ExecutorCandidate{}}
	if cfg.Enabled {
		info.Ready = e.ollama.State(ctx, info.Model).ModelReady
		info.Candidates = e.ExecutorCandidates(model.CapVLM, "ollama:"+info.Model)
	}
	return info
}

func (e *Engine) RefreshDiagnostics() {
	e.ollama.modelsMu.Lock()
	e.ollama.modelsAt = time.Time{}
	e.ollama.modelsMu.Unlock()
	for _, sidecar := range e.sidecars() {
		sidecar.probeMu.Lock()
		sidecar.probe = nil
		sidecar.probeMu.Unlock()
	}
}
