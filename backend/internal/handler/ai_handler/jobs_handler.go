package ai_handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

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
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
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
	// 入队前才拦"未启用"：先把请求本身校验干净，才能对畸形请求如实报 400。
	if !enabledGuard(c, e) {
		return
	}

	scope := strings.TrimSpace(req.Scope)
	if scope == "" {
		if len(req.MediaIDs) > 0 {
			scope = "ids"
		} else {
			scope = "missing"
		}
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
		ids := make([]uuid.UUID, 0, len(req.MediaIDs))
		for _, raw := range req.MediaIDs {
			id, err := uuid.Parse(strings.TrimSpace(raw))
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "媒体 ID 非法: " + raw})
				return
			}
			ids = append(ids, id)
		}
		for _, capability := range req.Capabilities {
			n, err := ai_repo.Enqueue(capability, ids)
			if err != nil {
				fail(c, err)
				return
			}
			affected[capability] = n
		}
	} else {
		for _, capability := range req.Capabilities {
			n, err := ai_repo.EnqueueMissing(capability, limit, 50)
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
	_ = c.ShouldBindJSON(&req)
	capability := strings.TrimSpace(req.Capability)
	if capability != "" && !model.IsValidCapability(capability) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
		return
	}

	ids := make([]uuid.UUID, 0, len(req.MediaIDs))
	for _, raw := range req.MediaIDs {
		if id, err := uuid.Parse(strings.TrimSpace(raw)); err == nil {
			ids = append(ids, id)
		}
	}
	if !enabledGuard(c, e) {
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
