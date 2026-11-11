package ai_handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
)

// ListJobs 处理 GET /API/ai/jobs
func ListJobs(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	capability := strings.TrimSpace(c.Query("capability"))
	if capability != "" && !model.IsValidCapability(capability) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
		return
	}
	limit := queryInt(c, "limit", 50, 1, 500)
	offset := queryInt(c, "offset", 0, 0, 1<<30)

	jobs, total, err := ai_repo.ListJobs(capability, strings.TrimSpace(c.Query("status")), limit, offset)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"jobs": jobs, "total": total, "limit": limit, "offset": offset})
}

// ListFailures 处理 GET /API/ai/failures
//
// 回答"到底哪些媒体文件处理失败了"：返回失败任务 + 媒体路径 + 软删除标记，
// 界面据此展示缩略图、定位文件，并把确认无用的直接标记软删除（复用 gallery 的软删除）。
func ListFailures(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	capability := strings.TrimSpace(c.Query("capability"))
	if capability != "" && !model.IsValidCapability(capability) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
		return
	}
	limit := queryInt(c, "limit", 60, 1, 500)
	offset := queryInt(c, "offset", 0, 0, 1<<30)

	items, total, err := ai_repo.ListFailures(capability, limit, offset)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"failures": items, "total": total, "limit": limit, "offset": offset})
}

// enqueueRequest POST /API/ai/enqueue 请求体。
type enqueueRequest struct {
	Capabilities []string `json:"capabilities"`
	MediaIDs     []string `json:"media_ids"`
	Scope        string   `json:"scope"` // ids(默认,配合 media_ids) / missing(全库缺该产物的媒体)
	Limit        int      `json:"limit"` // scope=missing 时的单次上限
}

// Enqueue 处理 POST /API/ai/enqueue
//
// scope=missing 用于"全库补处理"：只挑尚无该能力任务行的媒体，幂等可重复调用。
func Enqueue(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}

	var req enqueueRequest
	if !bindJSON(c, &req) {
		return
	}
	if len(req.Capabilities) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "capabilities 不能为空"})
		return
	}
	for _, capability := range req.Capabilities {
		if !model.IsValidCapability(capability) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
			return
		}
	}

	scope := strings.TrimSpace(req.Scope)
	if scope == "" {
		if len(req.MediaIDs) > 0 {
			scope = "ids"
		} else {
			scope = "missing"
		}
	}

	if scope != "ids" && scope != "missing" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "scope 必须为 ids 或 missing"})
		return
	}

	limit := req.Limit
	if limit <= 0 || limit > 200000 {
		limit = 200000
	}

	result := gin.H{}
	affected := map[string]int64{}

	if scope == "ids" {
		if len(req.MediaIDs) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "scope=ids 时必须提供 media_ids"})
			return
		}
		ids, ok := bodyUUIDs(c, "media_ids", req.MediaIDs)
		if !ok {
			return
		}
		for _, capability := range req.Capabilities {
			n, err := ai_repo.Enqueue(capability, ids, e.InputSignature(capability))
			if err != nil {
				fail(c, err)
				return
			}
			affected[capability] = n
		}
	} else {
		for _, capability := range req.Capabilities {
			n, err := ai_repo.EnqueueMissing(capability, limit, 50, e.InputSignature(capability))
			if err != nil {
				fail(c, err)
				return
			}
			affected[capability] = n
		}
	}

	result["enqueued"] = affected
	result["scope"] = scope
	e.Wake()
	c.JSON(http.StatusOK, result)
}

// retryRequest POST /API/ai/retry 请求体。
type retryRequest struct {
	Capability string   `json:"capability"`
	MediaIDs   []string `json:"media_ids"`
}

// Retry 处理 POST /API/ai/retry：把失败任务重置为待处理。
func Retry(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}

	var req retryRequest
	if !bindJSON(c, &req) {
		return
	}
	capability := strings.TrimSpace(req.Capability)
	if capability != "" && !model.IsValidCapability(capability) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
		return
	}

	ids, ok := bodyUUIDs(c, "media_ids", req.MediaIDs)
	if !ok {
		return
	}

	n, err := ai_repo.RetryFailed(capability, ids)
	if err != nil {
		fail(c, err)
		return
	}
	e.Wake()
	c.JSON(http.StatusOK, gin.H{"retried": n})
}

// regenerateRequest POST /API/ai/regenerate 请求体。
type regenerateRequest struct {
	Capability string   `json:"capability"`
	MediaIDs   []string `json:"media_ids"` // 留空 = 全库重生成
}

// Regenerate 处理 POST /API/ai/regenerate：单个能力的"全量重生成"。
//
// 破坏性操作：先把该能力的既有产物清空，再把全部未删除媒体重新排队，
// 因此调用方（桌面端）必须二次确认。其它能力的产物完全不受影响。
func Regenerate(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}

	var req regenerateRequest
	if !bindJSON(c, &req) {
		return
	}
	capability := strings.TrimSpace(req.Capability)
	if !model.IsValidCapability(capability) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
		return
	}
	// 逐条媒体重生成只是"重新入队指定媒体"，不清理全库产物
	if len(req.MediaIDs) > 0 {
		ids, ok := bodyUUIDs(c, "media_ids", req.MediaIDs)
		if !ok {
			return
		}
		n, err := ai_repo.RegenerateMedia(capability, ids, e.InputSignature(capability))
		if err != nil {
			fail(c, err)
			return
		}
		e.Wake()
		c.JSON(http.StatusOK, gin.H{"capability": capability, "scope": "ids", "enqueued": n})
		return
	}

	cleared, enqueued, err := ai_repo.Regenerate(capability, e.InputSignature(capability), 50)
	if err != nil {
		fail(c, err)
		return
	}
	e.Wake()
	c.JSON(http.StatusOK, gin.H{
		"capability": capability,
		"scope":      "all",
		"cleared":    cleared,
		"enqueued":   enqueued,
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
