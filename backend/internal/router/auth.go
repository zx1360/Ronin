package router

import (
	"strings"

	"github.com/gin-gonic/gin"

	"monarch/internal/handler/util_handler"
)

// selectiveAuth 按请求路径选择性应用 API Key 鉴权：
//
//	免鉴权：/API/test、漫画只读 GET、/API/ops/local/*、/ops/*
//	需鉴权：其余所有路由
//
// 网页运维端及其本机接口由 LocalOnly 校验回环连接、Host 与浏览器来源。
func selectiveAuth(banLogPath string) gin.HandlerFunc {
	auth := util_handler.APIKeyAuth(banLogPath)
	return func(c *gin.Context) {
		path := c.Request.URL.Path
		if path == "/API/test" ||
			(c.Request.Method == "GET" && (strings.HasPrefix(path, "/API/comic/") || strings.HasPrefix(path, "/static/comics/"))) ||
			strings.HasPrefix(path, "/API/ops/local/") ||
			path == "/ops" ||
			strings.HasPrefix(path, "/ops/") {
			c.Next()
			return
		}
		auth(c)
	}
}
