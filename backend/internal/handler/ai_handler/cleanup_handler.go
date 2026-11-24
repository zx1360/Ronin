package ai_handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/repository/gallery_repo"
)

func Cleanup(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	ctx := c.Request.Context()
	limit := queryInt(c, "limit", 30, 1, 100)
	offset := queryInt(c, "offset", 0, 0, 1<<30)
	candidates, err := ai_repo.ListDeletionCandidates(ctx, limit+1, offset)
	if err != nil {
		fail(c, err)
		return
	}
	more := len(candidates) > limit
	candidates = candidates[:min(len(candidates), limit)]
	ids := make([]uuid.UUID, 0, len(candidates))
	for _, item := range candidates {
		ids = append(ids, item.MediaID)
	}
	assets, err := gallery_repo.FetchMediaAssetsByIDs(ctx, ids)
	if err != nil {
		fail(c, err)
		return
	}
	byID := make(map[uuid.UUID]model.MediaAsset, len(assets))
	for _, asset := range assets {
		if !asset.IsDeleted {
			byID[asset.ID] = asset
		}
	}
	type recommendation struct {
		Asset  model.MediaAsset `json:"asset"`
		Reason string           `json:"reason"`
	}
	items := make([]recommendation, 0, len(candidates))
	for _, item := range candidates {
		if asset, ok := byID[item.MediaID]; ok {
			items = append(items, recommendation{Asset: asset, Reason: item.Reason})
		}
	}
	progress, err := ai_repo.CleanupProgress(ctx)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"items": items, "has_more": more, "next_offset": offset + len(candidates),
		"queue": progress, "paused": e.Paused(), "enabled": e.Config().Enabled,
	})
}

func ScanCleanup(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	var req struct {
		Limit *int `json:"limit"`
	}
	if !bindJSON(c, &req) {
		return
	}
	limit := 100
	if req.Limit != nil {
		limit = *req.Limit
	}
	if limit < 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "筛选数量不能为负数"})
		return
	}
	if !e.Config().Enabled {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "服务端未启用 AI"})
		return
	}
	if ready, reason := e.CapabilityReady(c.Request.Context(), model.CapCleanup); !ready {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": reason})
		return
	}
	if limit == 0 {
		limit = -1
	}
	n, err := ai_repo.EnqueueMissing(model.CapCleanup, limit, 50, e.InputSignature(model.CapCleanup))
	if err != nil {
		fail(c, err)
		return
	}
	e.Wake()
	c.JSON(http.StatusOK, gin.H{"enqueued": n})
}

func RelatedMedia(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	id, ok := pathUUID(c, "id", "媒体 ID ")
	if !ok {
		return
	}
	result, err := e.RelatedMedia(c.Request.Context(), id)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, result)
}
