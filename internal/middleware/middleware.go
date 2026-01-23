package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
)

// RequestLogger 请求日志中间件
// 记录请求方法、路径、状态码和耗时
func RequestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		// 处理请求
		c.Next()

		// 计算耗时
		latency := time.Since(start)
		status := c.Writer.Status()
		clientIP := c.ClientIP()
		method := c.Request.Method

		if query != "" {
			path = path + "?" + query
		}

		log.Printf("[%s] %3d | %13v | %15s | %s",
			method,
			status,
			latency,
			clientIP,
			path,
		)
	}
}

// Recovery 错误恢复中间件
// 捕获 panic 并返回 500 错误
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				log.Printf("[PANIC] %v", err)
				c.AbortWithStatusJSON(500, gin.H{
					"code":    50000,
					"message": "服务器内部错误",
				})
			}
		}()
		c.Next()
	}
}
