package ai_handler

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/model"
)

// Status 处理 GET /API/ai/status
func Status(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	if c.Query("refresh") == "true" {
		e.RefreshDiagnostics()
	}
	c.JSON(http.StatusOK, e.Status(c.Request.Context()))
}

func Progress(c *gin.Context) {
	if e := engine(c); e != nil {
		c.JSON(http.StatusOK, e.Progress(c.Request.Context()))
	}
}

func ChatInfo(c *gin.Context) {
	if e := engine(c); e != nil {
		if c.Query("refresh") == "true" {
			e.OllamaProvider().RefreshModels()
		}
		c.JSON(http.StatusOK, e.ChatInfo(c.Request.Context()))
	}
}

// StartModel 处理 POST /API/ai/process/:capability/start：预热（拉起进程/模型）。
func StartModel(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	capability := c.Param("capability")

	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Minute)
	defer cancel()

	switch capability {
	case model.CapVLM:
		if err := e.OllamaProvider().EnsureReady(ctx, e.ResolveVLMModel()); err != nil {
			fail(c, err)
			return
		}
	case model.CapPHash:
		c.JSON(http.StatusOK, gin.H{"started": true, "message": "pHash 在服务进程内完成，无需启动"})
		return
	default:
		sidecar := e.Sidecar(capability)
		if sidecar == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
			return
		}
		if err := sidecar.Warm(ctx); err != nil {
			fail(c, err)
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{"started": true, "capability": capability})
}

// StopModel 处理 POST /API/ai/process/:capability/stop：立即释放进程/模型内存。
func StopModel(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	capability := c.Param("capability")

	switch capability {
	case model.CapVLM:
		e.OllamaProvider().StopServer()
	case model.CapPHash:
		c.JSON(http.StatusOK, gin.H{"stopped": true, "message": "pHash 无常驻进程"})
		return
	default:
		sidecar := e.Sidecar(capability)
		if sidecar == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
			return
		}
		sidecar.Stop()
	}
	c.JSON(http.StatusOK, gin.H{"stopped": true, "capability": capability})
}

// RebuildIndex 处理 POST /API/ai/index/rebuild：丢弃并重建内存向量索引。
func RebuildIndex(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	e.Index().Invalidate()
	if err := e.Index().Reload(c.Request.Context()); err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"vectors": e.Index().VectorCount()})
}

// ListCapabilities 处理 GET /API/ai/capabilities
//
// 能力的名称、输入档位、执行者与执行者候选全部由服务端下发：消费端只渲染列表，
// 消费端按服务端契约展示能力与模型，旧结果须显式重生成。
func ListCapabilities(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	specs := e.CapabilitySpecs()
	cfg := e.Config()
	items := make([]gin.H, 0, len(specs))
	for _, spec := range specs {
		items = append(items, gin.H{
			"capability":          spec.Capability,
			"label":               spec.Label,
			"description":         spec.Description,
			"input_tier":          spec.InputTier,
			"tier_note":           spec.TierNote,
			"executor":            spec.Executor,
			"input_sig":           spec.InputSig,
			"executor_candidates": e.ExecutorCandidates(spec.Capability, spec.Executor),
		})
	}
	c.JSON(http.StatusOK, gin.H{
		"capabilities": items,
		"settings": gin.H{
			"idle_timeout_seconds": int(cfg.IdleTimeout.Seconds()),
			"job_timeout_seconds":  int(cfg.JobTimeout.Seconds()),
			"batch_size":           cfg.BatchSize,
			"max_attempts":         cfg.MaxAttempts,
			"workers":              cfg.Workers,
			"device":               cfg.Device,
			"auto_capabilities":    e.AutoCapabilities(),
			"vlm_model":            e.VLMModel(),
			"config_path":          e.ConfigPath(),
		},
	})
}

// GetSettings 处理 GET /API/ai/settings（保留旧路径，语义与 /capabilities 的 settings 段一致）。
func GetSettings(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	cfg := e.Config()
	c.JSON(http.StatusOK, gin.H{
		"auto_capabilities":    e.AutoCapabilities(),
		"all_capabilities":     model.AllCapabilities,
		"vlm_model":            e.VLMModel(),
		"idle_timeout_seconds": int(cfg.IdleTimeout.Seconds()),
		"job_timeout_seconds":  int(cfg.JobTimeout.Seconds()),
		"batch_size":           cfg.BatchSize,
		"max_attempts":         cfg.MaxAttempts,
		"workers":              cfg.Workers,
		"device":               cfg.Device,
		"config_path":          e.ConfigPath(),
	})
}

// UpdateSettings 处理 PUT /API/ai/settings
//
// 字段全部可选：未传（null）表示不改动。写入 DATA_DIR/ai_config.json 后
// 立即生效，不必重启进程。
func UpdateSettings(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	var req config.RuntimeConfig
	if !bindJSON(c, &req) {
		return
	}

	if req.AutoCapabilities != nil {
		for _, capability := range *req.AutoCapabilities {
			if !model.IsValidCapability(capability) {
				c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
				return
			}
		}
	}
	if req.VLMModel != nil && strings.TrimSpace(*req.VLMModel) != "" {
		// 只接受本机已安装的模型；传空串表示清除选择（下面交给服务端重新自动挑一个）。
		// 归一化后再落库，避免大小写（:4B / :4b）不一致。
		normalized, err := e.NormalizeModel(*req.VLMModel)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		req.VLMModel = &normalized
	}

	if err := e.UpdateRuntime(req); err != nil {
		// 取值非法属于客户端错误，如实回 400 并给出范围提示
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	// 选择被清空时立刻从实时列表重新挑一个：否则标注与对话会在"没有模型"的状态下卡住
	if req.VLMModel != nil && strings.TrimSpace(*req.VLMModel) == "" {
		e.ResolveVLMModel()
	}
	e.Wake()

	cfg := e.Config()
	c.JSON(http.StatusOK, gin.H{
		"auto_capabilities":    e.AutoCapabilities(),
		"vlm_model":            e.VLMModel(),
		"idle_timeout_seconds": int(cfg.IdleTimeout.Seconds()),
		"job_timeout_seconds":  int(cfg.JobTimeout.Seconds()),
		"batch_size":           cfg.BatchSize,
		"max_attempts":         cfg.MaxAttempts,
		"workers":              cfg.Workers,
		"device":               cfg.Device,
		"config_path":          e.ConfigPath(),
	})
}
