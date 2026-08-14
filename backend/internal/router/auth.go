package router

import (
	"strings"

	"github.com/gin-gonic/gin"

	"monarch/internal/handler/util_handler"
)

// selectiveAuth 按请求路径选择性应用 API Key 鉴权：
//
//	免鉴权：/API/test、/API/comic/*、/static/comics/*
//	需鉴权：其余所有路由
func selectiveAuth() gin.HandlerFunc {
	auth := util_handler.APIKeyAuth()
	return func(c *gin.Context) {
		path := c.Request.URL.Path
		if strings.HasPrefix(path, "/API/test") ||
			strings.HasPrefix(path, "/API/comic") ||
			strings.HasPrefix(path, "/static/comics") {
			c.Next()
			return
		}
		auth(c)
	}
}
