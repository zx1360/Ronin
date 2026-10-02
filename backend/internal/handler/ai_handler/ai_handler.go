// Package ai_handler 提供 AI 媒体处理层的 HTTP 接口。
//
// 三类职责：
//   - 运维：状态、队列、入队、重试、中断、模型进程启停、索引重建；
//   - 检索：文本搜图、以图搜图、OCR/标签/人物组合筛选；
//   - 组织：人物分组（改名/合并/删除/重新聚类）、近重复分组。
package ai_handler

import (
	"context"
	"errors"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/service/ai"
)

// engine 返回全局引擎；未装配时以 503 明确回应。
func engine(c *gin.Context) *ai.Engine {
	if ai.Default == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "AI 处理层未装配"})
		return nil
	}
	return ai.Default
}

// schemaGuard 校验 ai schema 是否就绪，未就绪时给出可执行提示。
func schemaGuard(c *gin.Context) bool {
	if ai_repo.SchemaReady(c.Request.Context()) {
		return true
	}
	c.JSON(http.StatusServiceUnavailable, gin.H{
		"error": "ai schema 未初始化，请先执行 references/db/ai.sql",
	})
	return false
}

// Status 处理 GET /API/ai/status
func Status(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	c.JSON(http.StatusOK, e.Status(c.Request.Context()))
}

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
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
		return
	}
	capability := strings.TrimSpace(req.Capability)
	if !model.IsValidCapability(capability) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "未知能力: " + capability})
		return
	}
	// 逐条媒体重生成只是"重新入队指定媒体"，不清理全库产物
	if len(req.MediaIDs) > 0 {
		ids := make([]uuid.UUID, 0, len(req.MediaIDs))
		for _, raw := range req.MediaIDs {
			id, err := uuid.Parse(strings.TrimSpace(raw))
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "媒体 ID 非法: " + raw})
				return
			}
			ids = append(ids, id)
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
	if err := e.Index().Reload(); err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"vectors": e.Index().VectorCount()})
}

// Search 处理 GET /API/ai/search
//
// 参数：q 文本查询；mode=auto|semantic|keyword|filename；tag_ids / include_descendants /
// person_ids / vlm_tags / mime_type / from / to 结构化筛选；limit / offset 分页。
func Search(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}

	req, err := buildSearchRequest(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Minute)
	defer cancel()

	result, err := e.Search(ctx, req)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, result)
}

// SearchByImage 处理 POST /API/ai/search/image（multipart 表单字段 image）。
func SearchByImage(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}

	fileHeader, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少上传文件字段 image"})
		return
	}

	temp, err := os.CreateTemp("", "ai_query_*.img")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建临时文件失败: " + err.Error()})
		return
	}
	tempPath := temp.Name()
	temp.Close()
	defer os.Remove(tempPath)

	if err := c.SaveUploadedFile(fileHeader, tempPath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存上传文件失败: " + err.Error()})
		return
	}

	req, err := buildSearchRequest(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Minute)
	defer cancel()

	result, err := e.SearchByImageBytes(ctx, tempPath, req)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, result)
}

// Similar 处理 GET /API/ai/similar/:id：以图搜图（库内已有媒体）。
func Similar(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	id, ok := pathUUID(c, "id", "媒体 ID ")
	if !ok {
		return
	}
	result, err := e.SimilarMedia(id, queryInt(c, "limit", 40, 1, 200))
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, result)
}

// MediaDetail 处理 GET /API/ai/media/:id：单个媒体的 AI 结果。
func MediaDetail(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	id, ok := pathUUID(c, "id", "媒体 ID ")
	if !ok {
		return
	}
	detail, err := ai_repo.GetMediaDetail(id)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, detail)
}

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

// ListVLMTags 处理 GET /API/ai/tags：AI 标签清单（只读，与人工标签无关）。
func ListVLMTags(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	tags, err := ai_repo.ListVLMTags(queryInt(c, "limit", 500, 1, 2000))
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"tags": tags, "total": len(tags)})
}

// ListPersons 处理 GET /API/ai/persons
func ListPersons(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	persons, err := ai_repo.ListPersons()
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"persons": persons, "total": len(persons)})
}

// ListPersonFaces 处理 GET /API/ai/persons/:id/faces
func ListPersonFaces(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	id, ok := pathUUID(c, "id", "人物 ID ")
	if !ok {
		return
	}
	faces, total, err := ai_repo.ListPersonFaces(id, queryInt(c, "limit", 100, 1, 500), queryInt(c, "offset", 0, 0, 1<<30))
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"faces": faces, "total": total})
}

// UpdatePerson 处理 PATCH /API/ai/persons/:id（改名；name 传空串表示清除）。
func UpdatePerson(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	id, ok := pathUUID(c, "id", "人物 ID ")
	if !ok {
		return
	}
	var req struct {
		Name *string `json:"name"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
		return
	}
	if req.Name != nil {
		trimmed := strings.TrimSpace(*req.Name)
		if trimmed == "" {
			req.Name = nil
		} else {
			req.Name = &trimmed
		}
	}
	if err := ai_repo.RenamePerson(id, req.Name); err != nil {
		writePersonError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"updated": true})
}

// DeletePerson 处理 DELETE /API/ai/persons/:id（人脸回到未分配，不删媒体）。
func DeletePerson(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	id, ok := pathUUID(c, "id", "人物 ID ")
	if !ok {
		return
	}
	if err := ai_repo.DeletePerson(id); err != nil {
		writePersonError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// MergePersons 处理 POST /API/ai/persons/merge
func MergePersons(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	var req struct {
		SourceIDs []string `json:"source_ids"`
		TargetID  string   `json:"target_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
		return
	}
	target, err := uuid.Parse(strings.TrimSpace(req.TargetID))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "target_id 非法"})
		return
	}
	sources := make([]uuid.UUID, 0, len(req.SourceIDs))
	for _, raw := range req.SourceIDs {
		id, err := uuid.Parse(strings.TrimSpace(raw))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "source_ids 含非法 ID: " + raw})
			return
		}
		if id != target {
			sources = append(sources, id)
		}
	}
	if len(sources) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "source_ids 不能为空且不能包含 target_id"})
		return
	}

	moved, err := ai_repo.MergePersons(sources, target)
	if err != nil {
		fail(c, err)
		return
	}
	e.Cluster().Invalidate()
	c.JSON(http.StatusOK, gin.H{"moved_faces": moved})
}

// AssignFaces 处理 POST /API/ai/faces/assign（人工纠正分组）
func AssignFaces(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	var req struct {
		FaceIDs  []string `json:"face_ids"`
		PersonID *string  `json:"person_id"` // null 表示移出分组
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
		return
	}
	if len(req.FaceIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "face_ids 不能为空"})
		return
	}
	faces := make([]uuid.UUID, 0, len(req.FaceIDs))
	for _, raw := range req.FaceIDs {
		id, err := uuid.Parse(strings.TrimSpace(raw))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "face_ids 含非法 ID: " + raw})
			return
		}
		faces = append(faces, id)
	}

	var personID *uuid.UUID
	if req.PersonID != nil && strings.TrimSpace(*req.PersonID) != "" {
		id, err := uuid.Parse(strings.TrimSpace(*req.PersonID))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "person_id 非法"})
			return
		}
		personID = &id
	}

	if err := ai_repo.AssignFaces(faces, personID); err != nil {
		fail(c, err)
		return
	}
	if personID != nil {
		if err := ai_repo.RefreshPersonStats([]uuid.UUID{*personID}); err != nil {
			fail(c, err)
			return
		}
	}
	if _, err := ai_repo.DropEmptyPersons(); err != nil {
		fail(c, err)
		return
	}
	e.Cluster().Invalidate()
	c.JSON(http.StatusOK, gin.H{"assigned": len(faces)})
}

// Recluster 处理 POST /API/ai/recluster
//
// 默认只处理未分配的人脸（保留现有人物与人工命名）；reset=true 会清空全部
// 分组重新聚类，需由调用方显式确认。
func Recluster(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	var req struct {
		Reset bool `json:"reset"`
	}
	_ = c.ShouldBindJSON(&req)

	e.ClusterLock()
	defer e.ClusterUnlock()

	ctx, cancel := context.WithTimeout(c.Request.Context(), 30*time.Minute)
	defer cancel()

	result, err := e.Cluster().Recluster(ctx, ai.ReclusterOptions{Reset: req.Reset})
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"assigned":   result.Assigned,
		"new_person": result.NewPerson,
		"pending":    result.Pending,
		"reset":      req.Reset,
	})
}

// ListCapabilities 处理 GET /API/ai/capabilities
//
// 能力的名称、输入档位、执行者与执行者候选全部由服务端下发：消费端只渲染列表，
// 换模型后旧产物会被自动重排（不匹配即重排），端上无需硬编码任何能力语义。
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
// 字段全部可选：未传（null）表示不改动。写入 <STATIC_DIR>/data/ai_config.json 后
// 立即生效，不必重启进程。
func UpdateSettings(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	var req struct {
		AutoCapabilities   *[]string `json:"auto_capabilities"`
		VLMModel           *string   `json:"vlm_model"`
		IdleTimeoutSeconds *int      `json:"idle_timeout_seconds"`
		JobTimeoutSeconds  *int      `json:"job_timeout_seconds"`
		BatchSize          *int      `json:"batch_size"`
		MaxAttempts        *int      `json:"max_attempts"`
		Workers            *int      `json:"workers"`
		Device             *string   `json:"device"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
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

	update := config.RuntimeConfig{
		AutoCapabilities:   req.AutoCapabilities,
		VLMModel:           req.VLMModel,
		IdleTimeoutSeconds: req.IdleTimeoutSeconds,
		JobTimeoutSeconds:  req.JobTimeoutSeconds,
		BatchSize:          req.BatchSize,
		MaxAttempts:        req.MaxAttempts,
		Workers:            req.Workers,
		Device:             req.Device,
	}
	if err := e.UpdateRuntime(update); err != nil {
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

// ---------- 辅助 ----------

// fail 以 500 回写内部错误。
func fail(c *gin.Context, err error) {
	c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
}

// pathUUID 解析路径参数中的 UUID（label 为中文主体名，如"媒体 ID"）；失败时已写回响应。
func pathUUID(c *gin.Context, param, label string) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param(param))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": label + "非法"})
		return uuid.Nil, false
	}
	return id, true
}

func buildSearchRequest(c *gin.Context) (ai.SearchRequest, error) {
	req := ai.SearchRequest{
		Query:              strings.TrimSpace(c.Query("q")),
		Mode:               strings.TrimSpace(c.Query("mode")),
		MediaID:            strings.TrimSpace(c.Query("media_id")),
		IncludeDescendants: c.Query("include_descendants") == "true",
		MimeType:           strings.TrimSpace(c.Query("mime_type")),
		SortBy:             strings.TrimSpace(c.Query("sort_by")),
		SortOrder:          strings.TrimSpace(c.Query("sort_order")),
		Limit:              queryInt(c, "limit", 60, 1, 200),
		Offset:             queryInt(c, "offset", 0, 0, 1<<30),
	}
	if raw := strings.TrimSpace(c.Query("min_score")); raw != "" {
		value, err := strconv.ParseFloat(raw, 32)
		if err != nil {
			return req, errors.New("min_score 非法")
		}
		req.MinScore = float32(value)
	}
	// ID 列表在这里就校验：非法输入属于客户端错误（400），
	// 交给服务层报错会被统一映射成 500，掩盖真正的原因。
	tagIDs, err := parseUUIDParams(c, "tag_ids")
	if err != nil {
		return req, err
	}
	req.TagIDs = tagIDs
	personIDs, err := parseUUIDParams(c, "person_ids")
	if err != nil {
		return req, err
	}
	req.PersonIDs = personIDs
	for _, raw := range ai_repo.SplitAndTrim(c.Query("vlm_tags")) {
		req.VLMTags = append(req.VLMTags, raw)
	}
	from, err := parseOptionalTime(c, "from")
	if err != nil {
		return req, err
	}
	req.From = from
	to, err := parseOptionalTime(c, "to")
	if err != nil {
		return req, err
	}
	req.To = to
	return req, nil
}

// parseTime 解析带时区的 RFC3339 或不带时区的本机时间。
//
// 时间戳按本机本地时区存库（见 AGENTS_DB.md）；不带时区的写法必须按本地解析，
// 否则 `2024-05-31` 会被当成 UTC 零点，在 UTC+8 下整体偏移 8 小时。
func parseTime(raw string) (time.Time, error) {
	if parsed, err := time.Parse(time.RFC3339, raw); err == nil {
		return parsed, nil
	}
	for _, layout := range []string{"2006-01-02 15:04:05", "2006-01-02T15:04:05"} {
		if parsed, err := time.ParseInLocation(layout, raw, time.Local); err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, errors.New("无法解析时间")
}

// parseUUIDParams 解析逗号分隔的 UUID 查询参数；任一非法即报错（供 400 回写）。
func parseUUIDParams(c *gin.Context, key string) ([]string, error) {
	values := ai_repo.SplitAndTrim(c.Query(key))
	for _, raw := range values {
		if _, err := uuid.Parse(raw); err != nil {
			return nil, errors.New(key + " 含非法 ID: " + raw)
		}
	}
	return values, nil
}

// parseOptionalTime 解析可选的 from/to 时间参数；未提供时返回 nil。
//
// 只写日期（界面上的日期选择器）时按本地日历日解释，且 to 取该日末尾：
// 否则"到 5 月 31 日"会把 5 月 31 日整天排除在外。
func parseOptionalTime(c *gin.Context, key string) (*time.Time, error) {
	raw := strings.TrimSpace(c.Query(key))
	if raw == "" {
		return nil, nil
	}
	if parsed, err := time.ParseInLocation("2006-01-02", raw, time.Local); err == nil {
		if key == "to" {
			parsed = parsed.AddDate(0, 0, 1).Add(-time.Millisecond)
		}
		return &parsed, nil
	}
	parsed, err := parseTime(raw)
	if err != nil {
		return nil, errors.New(key + " 时间格式非法")
	}
	return &parsed, nil
}

func queryInt(c *gin.Context, key string, def, min, max int) int {
	raw := strings.TrimSpace(c.Query(key))
	if raw == "" {
		return def
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < min {
		return def
	}
	if value > max {
		return max
	}
	return value
}

func writePersonError(c *gin.Context, err error) {
	if errors.Is(err, ai_repo.ErrPersonMissing) {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	fail(c, err)
}
