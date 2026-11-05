package util_handler

import (
	"crypto/subtle"
	"fmt"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

// APIKeyAuth 校验密钥，并按 TCP 对端地址记录鉴权失败。回环地址不封禁。
func APIKeyAuth(banLogPath string) gin.HandlerFunc {
	limiter := newIPRateLimiter(banLogPath)
	localOnly := LocalOnly()
	return func(c *gin.Context) {
		peerIsLocal := isLoopbackAddr(c.Request.RemoteAddr)
		clientIP, _, _ := net.SplitHostPort(c.Request.RemoteAddr)

		if !peerIsLocal {
			if expiry := limiter.banExpiry(clientIP); !expiry.IsZero() {
				respondBanned(c, expiry)
				return
			}
		}

		expectedKey := os.Getenv("API_KEY_SERVER")
		if expectedKey == "" {
			if peerIsLocal {
				localOnly(c)
				return
			}
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "服务端未配置 API 密钥"})
			return
		}

		apiKey := c.GetHeader("X-API-Key")
		useQuery := apiKey == "" && peerIsLocal && (c.Request.Method == http.MethodGet || c.Request.Method == http.MethodHead)
		if useQuery {
			apiKey = c.Query("api_key")
		}
		if subtle.ConstantTimeCompare([]byte(apiKey), []byte(expectedKey)) == 1 {
			if useQuery {
				localOnly(c)
				return
			}
			c.Next()
			return
		}

		if !peerIsLocal {
			if expiry := limiter.recordFailure(clientIP); !expiry.IsZero() {
				respondBanned(c, expiry)
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
func respondBanned(c *gin.Context, expiry time.Time) {
	c.JSON(http.StatusForbidden, gin.H{
		"error":   "ip_banned",
		"message": fmt.Sprintf("由于频繁无效请求，此 IP 已被临时封禁，解封时间: %s", expiry.Format(timeLayout)),
	})
	c.Abort()
}
