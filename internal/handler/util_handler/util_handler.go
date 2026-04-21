package util_handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// @Summary 健康检查
// @Tags util
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} map[string]string
// @Router /api/test [get]
func Test(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"message": "服务端响应正常.",
	})
}
