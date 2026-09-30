package ai_handler

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
)

// Status 处理 GET /API/ai/status
func Status(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	c.JSON(http.StatusOK, e.Status(c.Request.Context()))
}

// Capabilities 处理 GET /API/ai/capabilities
//
// 下发每个能力的输入档位、当前执行者与候选清单。消费端只渲染这份清单，
// 不在端上硬编码能力名或模型名；改配置走 /API/settings（仅本机回环可写）。
func Capabilities(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"enabled":      e.Config().Enabled,
		"capabilities": e.CapabilityInfos(c.Request.Context()),
		"auto":         ai_repo.AutoCapabilities(e.Config().AutoCaps),
	})
}

// Cancel 处理 POST /API/ai/cancel：中断当前批次并暂停队列。
//
// 只中断批次而不暂停没有意义——worker 会立刻认领下一批，用户看到的就是
// "点了中断还在跑"。恢复请调用 /resume。
func Cancel(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	aborted := e.PauseRun()
	c.JSON(http.StatusOK, gin.H{
		"cancelled": aborted,
		"paused":    true,
		"message":   "处理队列已暂停；调用 /API/ai/resume 继续",
	})
}

// Resume 处理 POST /API/ai/resume：恢复被暂停的处理队列。
func Resume(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	e.ResumeRun()
	c.JSON(http.StatusOK, gin.H{"paused": false})
}

// StartModel 处理 POST /API/ai/process/:capability/start：预热（拉起进程/模型）。
func StartModel(c *gin.Context) {
	e := engine(c)
	if e == nil || !enabledGuard(c, e) {
		return
	}
	capability := c.Param("capability")

	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Minute)
	defer cancel()

	switch capability {
	case model.CapVLM:
		if err := e.OllamaProvider().EnsureReady(ctx, e.VLMModel()); err != nil {
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
	if err := e.Index().Reload(); err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"vectors": e.Index().VectorCount()})
}
