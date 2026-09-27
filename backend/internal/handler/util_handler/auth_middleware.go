package util_handler

import (
	"fmt"
	"net"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
)

// APIKeyAuth API 密钥验证中间件（含 IP 频控）。
//
// 回环请求直接放行：ops 网页应用走 `http://127.0.0.1:<debug port>`，浏览器无法
// 静默携带自定义请求头；能连上回环的进程本来就已经在本机执行，信任边界没有降低。
// 其余来源必须带 X-API-Key；同一 IP 短时间鉴权失败达到阈值即封禁数天。
func APIKeyAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		if isLoopbackRequest(c) {
			c.Next()
			return
		}

		clientIP := extractIP(c)

		if limiter.IsBanned(clientIP) {
			respondBanned(c, clientIP)
			return
		}

		expectedKey := config.NetConf.APIKeyServer
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

// RequireLoopback 只放行本机回环请求，用于 ops 的本机能力接口
// （进程与任务生命周期、路径定位、配置读写等）。
func RequireLoopback() gin.HandlerFunc {
	return func(c *gin.Context) {
		if isLoopbackRequest(c) {
			c.Next()
			return
		}
		c.JSON(http.StatusForbidden, gin.H{
			"error":   "loopback_only",
			"message": "该接口只能从本机回环地址访问",
		})
		c.Abort()
	}
}

// isLoopbackRequest 报告请求是否直连自回环。
//
// 只认 TCP 直连地址：X-Forwarded-For 可被局域网客户端随意伪造，
// 一旦参与判定就等于把本机能力开放给了整个网络。
func isLoopbackRequest(c *gin.Context) bool {
	host, _, err := net.SplitHostPort(c.Request.RemoteAddr)
	if err != nil {
		host = c.Request.RemoteAddr
	}
	ip := net.ParseIP(strings.TrimSpace(host))
	if ip == nil {
		return false
	}
	return ip.IsLoopback()
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
