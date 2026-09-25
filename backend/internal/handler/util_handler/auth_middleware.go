package util_handler

import (
	"fmt"
	"net"
	"net/http"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

// APIKeyAuth API 密钥验证中间件（含 IP 频控）。
//
// 同一 IP 短时间内鉴权失败达到阈值即封禁数天，封禁记录持久化到封禁日志文件；
// 未设置 API_KEY_SERVER 时视为未启用鉴权，直接放行（本地开发场景）。
func APIKeyAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := extractIP(c)

		if limiter.IsBanned(clientIP) {
			respondBanned(c, clientIP)
			return
		}

		expectedKey := os.Getenv("API_KEY_SERVER")
		if expectedKey == "" {
			c.Next()
			return
		}

		apiKey := c.GetHeader("X-API-Key")
		if apiKey == expectedKey {
			c.Next()
			return
		}

		limiter.RecordFailure(clientIP)
		// 本次失败可能刚好触发封禁，此时返回封禁提示而非普通鉴权错误
		if limiter.IsBanned(clientIP) {
			respondBanned(c, clientIP)
			return
		}

		if apiKey == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "缺少 API 密钥"})
		} else {
			c.JSON(http.StatusForbidden, gin.H{"error": "无效的 API 密钥"})
		}
		c.Abort()
	}
}

// respondBanned 写出封禁响应并终止请求链
func respondBanned(c *gin.Context, clientIP string) {
	expiry, _ := limiter.GetBanExpiry(clientIP)
	c.JSON(http.StatusForbidden, gin.H{
		"error":   "ip_banned",
		"message": fmt.Sprintf("由于频繁无效请求，此 IP 已被临时封禁，解封时间: %s", formatTime(expiry)),
	})
	c.Abort()
}

// extractIP 提取客户端真实 IP。
//
// X-Forwarded-For 可能携带代理链，只取最左侧（原始客户端）项，避免用伪造的
// 整串当作独立标识绕过频控。
func extractIP(c *gin.Context) string {
	if forwarded := c.GetHeader("X-Forwarded-For"); forwarded != "" {
		first, _, _ := strings.Cut(forwarded, ",")
		if ip := normalizeIP(first); ip != "" {
			return ip
		}
	}
	if ip := normalizeIP(c.GetHeader("X-Real-IP")); ip != "" {
		return ip
	}
	return c.ClientIP()
}

// normalizeIP 去掉端口与空白；非法值返回空串。
func normalizeIP(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if host, _, err := net.SplitHostPort(raw); err == nil {
		raw = host
	}
	if net.ParseIP(raw) == nil {
		return ""
	}
	return raw
}
