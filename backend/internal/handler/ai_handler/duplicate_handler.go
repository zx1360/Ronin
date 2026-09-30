package ai_handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"monarch/internal/repository/ai_repo"
)

// Duplicates 处理 GET /API/ai/duplicates：基于 pHash 的近重复分组。
func Duplicates(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	groups, err := e.Index().DuplicateGroups(queryInt(c, "max_distance", 4, 1, 4),
		queryInt(c, "min_group", 2, 2, 100))
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"groups":        groups,
		"total":         len(groups),
		"ignored_total": e.Index().IgnoreCount(),
	})
}

// duplicateIgnoreRequest 标记/取消"非重复"的请求体。
type duplicateIgnoreRequest struct {
	MediaIDs []string `json:"media_ids"`
}

// IgnoreDuplicates 处理 POST /API/ai/duplicates/ignore：把选中媒体标记为"非重复"。
//
// 语义是"人工否决"：这些媒体之后的近重复分组中不再出现，随时可恢复。
func IgnoreDuplicates(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	ids, ok := parseMediaIDBody(c)
	if !ok {
		return
	}
	n, err := ai_repo.IgnoreDuplicates(ids)
	if err != nil {
		fail(c, err)
		return
	}
	e.Index().InvalidateIgnores()
	if err := e.Index().EnsureIgnores(); err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"ignored": n, "total": e.Index().IgnoreCount()})
}

// UnignoreDuplicates 处理 POST /API/ai/duplicates/unignore：恢复被标记的媒体。
func UnignoreDuplicates(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	ids, ok := parseMediaIDBody(c)
	if !ok {
		return
	}
	n, err := ai_repo.UnignoreDuplicates(ids)
	if err != nil {
		fail(c, err)
		return
	}
	e.Index().InvalidateIgnores()
	if err := e.Index().EnsureIgnores(); err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"restored": n, "total": e.Index().IgnoreCount()})
}

// ListIgnoredDuplicates 处理 GET /API/ai/duplicates/ignored：已标记"非重复"的媒体。
func ListIgnoredDuplicates(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	assets, err := e.IgnoredDuplicates()
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"media_assets": assets, "total": len(assets)})
}

// parseMediaIDBody 解析请求体中的 media_ids 并校验为合法 UUID；失败时已写回响应。
func parseMediaIDBody(c *gin.Context) ([]uuid.UUID, bool) {
	var req duplicateIgnoreRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
		return nil, false
	}
	if len(req.MediaIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "media_ids 不能为空"})
		return nil, false
	}
	ids := make([]uuid.UUID, 0, len(req.MediaIDs))
	for _, raw := range req.MediaIDs {
		id, err := uuid.Parse(strings.TrimSpace(raw))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "媒体 ID 非法: " + raw})
			return nil, false
		}
		ids = append(ids, id)
	}
	return ids, true
}
