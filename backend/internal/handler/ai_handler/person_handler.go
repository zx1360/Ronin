package ai_handler

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"monarch/internal/repository/ai_repo"
	"monarch/internal/service/ai"
)

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

func writePersonError(c *gin.Context, err error) {
	if errors.Is(err, ai_repo.ErrPersonMissing) {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	fail(c, err)
}
