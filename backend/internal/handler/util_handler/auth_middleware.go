package util_handler

import (
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

// APIKeyAuth API 密钥验证中间件（含 IP 频控）
//
//	短时间内同一 IP 鉴权失败达到阈值 → 封禁该 IP 数天 → 持久化记录到 ./static/logs.txt
func APIKeyAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := extractIP(c)

		// 1. 检查是否已被封禁
		if limiter.IsBanned(clientIP) {
			expiry, _ := limiter.GetBanExpiry(clientIP)
			c.JSON(http.StatusForbidden, gin.H{
				"error":   "ip_banned",
				"message": fmt.Sprintf("由于频繁无效请求，此 IP 已被临时封禁，解封时间: %s", expiry.Format("2006-01-02 15:04:05")),
			})
			c.Abort()
			return
		}

		apiKey := c.GetHeader("X-API-Key")
		expectedKey := os.Getenv("API_KEY_SERVER")

		// 如果环境变量未设置，则跳过验证
		if expectedKey == "" {
			c.Next()
			return
		}

		// 2. 鉴权校验
		if apiKey == "" || apiKey != expectedKey {
			// 记录失败
			limiter.RecordFailure(clientIP)

			// 记录后再次检查是否因本次失败触发封禁
			if limiter.IsBanned(clientIP) {
				expiry, _ := limiter.GetBanExpiry(clientIP)
				c.JSON(http.StatusForbidden, gin.H{
					"error":   "ip_banned",
					"message": fmt.Sprintf("由于频繁无效请求，此 IP 已被临时封禁，解封时间: %s", expiry.Format("2006-01-02 15:04:05")),
				})
				c.Abort()
				return
			}

			if apiKey == "" {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "缺少 API 密钥"})
			} else {
				c.JSON(http.StatusForbidden, gin.H{"error": "无效的 API 密钥"})
			}
			c.Abort()
			return
		}

		c.Next()
	}
}

// extractIP 从 gin.Context 提取客户端真实 IP
func extractIP(c *gin.Context) string {
	if ip := c.GetHeader("X-Forwarded-For"); ip != "" {
		return ip
	}
	if ip := c.GetHeader("X-Real-IP"); ip != "" {
		return ip
	}
	return c.ClientIP()
}

// BanExpiry 临时暴露：给运维接口查询某 IP 封禁状态
func BanExpiry(ip string) (time.Time, bool) {
	return limiter.GetBanExpiry(ip)
}
