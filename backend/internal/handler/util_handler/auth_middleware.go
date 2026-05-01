package util_handler

import (
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

// APIKeyAuth API 密钥验证中间件
// 从请求 header 中验证 X-API-Key
func APIKeyAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		apiKey := c.GetHeader("X-API-Key")
		expectedKey := os.Getenv("API_KEY")

		// 如果环境变量未设置，则跳过验证
		if expectedKey == "" {
			c.Next()
			return
		}

		if apiKey == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "缺少 API 密钥"})
			c.Abort()
			return
		}

		if apiKey != expectedKey {
			c.JSON(http.StatusForbidden, gin.H{"error": "无效的 API 密钥"})
			c.Abort()
			return
		}

		c.Next()
	}
}
