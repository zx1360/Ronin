package router

import (
	"strings"

	"github.com/gin-gonic/gin"

	"monarch/internal/handler/util_handler"
)

// selectiveAuth 按请求路径选择性应用 API Key 鉴权：
//
//	免鉴权：/API/test、/API/comic/*、/static/comics/*、/API/ops/local/*、/ops/*
//	需鉴权：其余所有路由
//
// 网页运维端（/ops 页面与其本机能力接口）由 LocalOnly 中间件限定仅本机回环访问：
// 页面要靠本机接口取回密钥（先有鸡还是先有蛋），而"只有本机能连"本来就比共享密钥更严。
func selectiveAuth() gin.HandlerFunc {
	auth := util_handler.APIKeyAuth()
	return func(c *gin.Context) {
		path := c.Request.URL.Path
		if strings.HasPrefix(path, "/API/test") ||
			strings.HasPrefix(path, "/API/comic") ||
			strings.HasPrefix(path, "/static/comics") ||
			strings.HasPrefix(path, "/API/ops/local") ||
			path == "/ops" ||
			strings.HasPrefix(path, "/ops/") {
			c.Next()
			return
		}
		auth(c)
	}
}
