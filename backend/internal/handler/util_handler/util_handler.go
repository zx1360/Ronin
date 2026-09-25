package util_handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Test 健康检查（免鉴权），客户端用于探测服务器连通性。
func Test(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"message": "服务端响应正常.",
	})
}
