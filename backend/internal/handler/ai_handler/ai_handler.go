package ai_handler

import (
	"encoding/json"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/service/ai"
	"net/http"
	"strconv"
	"strings"
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
		"error": "ai schema 未初始化，请先执行 references/db/sqlite.sql",
	})
	return false
}

// fail 以 500 回写内部错误。
func fail(c *gin.Context, err error) {
	c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
}

func bindJSON[T any](c *gin.Context, target *T) bool {
	var value *T
	if err := json.NewDecoder(c.Request.Body).Decode(&value); err != nil || value == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体须为有效 JSON 对象，且字段类型正确"})
		return false
	}
	*target = *value
	return true
}

// 非法 ID 必须整批拒绝，不能过滤成空列表后扩大为全库操作。
func bodyUUIDs(c *gin.Context, field string, values []string) ([]uuid.UUID, bool) {
	ids := make([]uuid.UUID, 0, len(values))
	seen := make(map[uuid.UUID]bool, len(values))
	for _, raw := range values {
		id, err := uuid.Parse(strings.TrimSpace(raw))
		if err != nil || id == uuid.Nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": field + " 含非法 ID: " + raw})
			return nil, false
		}
		if !seen[id] {
			ids = append(ids, id)
			seen[id] = true
		}
	}
	return ids, true
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
