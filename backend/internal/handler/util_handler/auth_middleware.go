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
// 未设置 API_KEY_SERVER 时视为未启用鉴权，直接放行。
//
// **本机回环地址永不封禁**：网页运维端拿到密钥之前就会有请求打进来（引导阶段、
// 密钥轮换期），把本机锁在门外既没意义又难以自愈。判定只认 TCP 对端地址，
// 不看 X-Forwarded-For，避免远端伪造本机地址绕过封禁。
func APIKeyAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		peerIsLocal := isLoopbackAddr(c.Request.RemoteAddr)
		clientIP := extractIP(c)

		if !peerIsLocal && limiter.IsBanned(clientIP) {
			respondBanned(c, clientIP)
			return
		}

		expectedKey := os.Getenv("API_KEY_SERVER")
		if expectedKey == "" {
			c.Next()
			return
		}

		apiKey := c.GetHeader("X-API-Key")
		if apiKey == "" {
			// 浏览器无法给 <img>/<a> 附加请求头，图片等直接嵌入的资源
			// 只能用查询参数携带密钥（网页运维端与 Monarch 同机同源）。
			apiKey = c.Query("api_key")
		}
		if apiKey == expectedKey {
			c.Next()
			return
		}

		if !peerIsLocal {
			limiter.RecordFailure(clientIP)
			if limiter.IsBanned(clientIP) {
				respondBanned(c, clientIP)
				return
			}
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
