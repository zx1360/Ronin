// Package ai_handler 提供 AI 媒体处理层的 HTTP 接口。
//
// 按关注点分文件：
//   - ai_handler.go     守卫与共用辅助（引擎装配、schema、启用开关、参数解析）
//   - status_handler.go 运维：状态、能力清单、队列暂停/继续、模型进程启停、索引重建
//   - jobs_handler.go   队列：任务列表、入队、重试
//   - search_handler.go 检索：文本搜图、以图搜图、AI 标签清单
//   - duplicate_handler.go 去重：近重复分组与"非重复"标记
//   - person_handler.go 组织：人物分组
//   - chat_handler.go   交互式对话（NDJSON 流）
//   - review_handler.go 近期回顾
package ai_handler

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

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
		"error": "AI 数据表缺失（数据库可能不是 Monarch 建的表或文件已损坏）",
	})
	return false
}

// enabledGuard 拦住"需要 worker 才会生效"的操作。
//
// 关闭 AI 后入队只会写进一张没人消费的队列表，启动模型更会真的拉起侧车进程——
// 两者都必须明确失败，而不是给用户一个"已入队/已启动"的假象。
func enabledGuard(c *gin.Context, e *ai.Engine) bool {
	if e.Config().Enabled {
		return true
	}
	c.JSON(http.StatusConflict, gin.H{
		"error": "AI 处理层未启用（可在设置里打开 ai.enabled）",
	})
	return false
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
