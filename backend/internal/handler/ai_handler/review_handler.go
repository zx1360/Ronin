package ai_handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"monarch/internal/repository/ai_repo"
	"monarch/internal/service/review"
)

// ListReviewPresets 处理 GET /API/ai/review/presets
func ListReviewPresets(c *gin.Context) {
	if err := ai_repo.EnsureReviewPresets(); err != nil {
		fail(c, err)
		return
	}
	presets, err := ai_repo.ListReviewPresets()
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"presets": presets})
}

// UpsertReviewPreset 处理 POST /API/ai/review/presets
func UpsertReviewPreset(c *gin.Context) {
	var req ai_repo.ReviewPreset
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
		return
	}
	if err := ai_repo.UpsertReviewPreset(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	presets, err := ai_repo.ListReviewPresets()
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"presets": presets})
}

// DeleteReviewPreset 处理 DELETE /API/ai/review/presets/:id
func DeleteReviewPreset(c *gin.Context) {
	if err := ai_repo.DeleteReviewPreset(strings.TrimSpace(c.Param("id"))); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	presets, err := ai_repo.ListReviewPresets()
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"presets": presets})
}

// GenerateReview 处理 POST /API/ai/review
//
// 统计由后端算出；模型只负责叙述。模型不可用时仍返回统计（完整降级），
// 因此前端始终有内容可展示。
func GenerateReview(c *gin.Context) {
	var req struct {
		Days     int    `json:"days"`
		PresetID string `json:"preset_id"`
		Force    bool   `json:"force"`
	}
	// 允许空请求体：全部走默认值
	if c.Request.ContentLength > 0 {
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
			return
		}
	}

	result, err := review.Recent(c.Request.Context(), req.Days, req.PresetID, req.Force)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, result)
}
