package common

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Response 统一API响应结构
type Response struct {
	Code    int         `json:"code"`            // 业务状态码
	Message string      `json:"message"`         // 提示信息
	Data    interface{} `json:"data,omitempty"`  // 响应数据
	Error   string      `json:"error,omitempty"` // 错误详情（仅失败时返回）
}

// 常用业务状态码
const (
	CodeSuccess       = 0     // 成功
	CodeBadRequest    = 40000 // 请求参数错误
	CodeUnauthorized  = 40100 // 未授权
	CodeForbidden     = 40300 // 禁止访问
	CodeNotFound      = 40400 // 资源不存在
	CodeInternalError = 50000 // 服务器内部错误
)

// Success 成功响应
func Success(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, Response{
		Code:    CodeSuccess,
		Message: "success",
		Data:    data,
	})
}

// SuccessWithMessage 成功响应（带自定义消息）
func SuccessWithMessage(c *gin.Context, message string, data interface{}) {
	c.JSON(http.StatusOK, Response{
		Code:    CodeSuccess,
		Message: message,
		Data:    data,
	})
}

// Fail 失败响应
func Fail(c *gin.Context, httpStatus int, code int, message string) {
	c.JSON(httpStatus, Response{
		Code:    code,
		Message: message,
	})
}

// FailWithError 失败响应（带错误详情）
func FailWithError(c *gin.Context, httpStatus int, code int, message string, err error) {
	resp := Response{
		Code:    code,
		Message: message,
	}
	if err != nil {
		resp.Error = err.Error()
	}
	c.JSON(httpStatus, resp)
}

// BadRequest 请求参数错误
func BadRequest(c *gin.Context, message string) {
	Fail(c, http.StatusBadRequest, CodeBadRequest, message)
}

// NotFound 资源不存在
func NotFound(c *gin.Context, message string) {
	Fail(c, http.StatusNotFound, CodeNotFound, message)
}

// InternalError 服务器内部错误
func InternalError(c *gin.Context, message string, err error) {
	FailWithError(c, http.StatusInternalServerError, CodeInternalError, message, err)
}
