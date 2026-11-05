package router

import (
	"strings"

	"github.com/gin-gonic/gin"

	"monarch/internal/handler/util_handler"
)

// selectiveAuth 为健康检查和由 LocalOnly 保护的运维路由保留例外。
func selectiveAuth(banLogPath string) gin.HandlerFunc {
	auth := util_handler.APIKeyAuth(banLogPath)
	return func(c *gin.Context) {
		path := c.Request.URL.Path
		if path == "/API/test" ||
			strings.HasPrefix(path, "/API/ops/local/") ||
			path == "/ops" ||
			strings.HasPrefix(path, "/ops/") {
			c.Next()
			return
		}
		auth(c)
	}
}
