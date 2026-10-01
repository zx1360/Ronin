package util_handler

import (
	"net"
	"net/http"

	"github.com/gin-gonic/gin"
)

// LocalOnly 限制接口仅本机（回环地址）可访问，供网页运维端的本机能力接口使用。
//
// 只认 TCP 对端地址：X-Forwarded-For / X-Real-IP 可被伪造，不能作为"本机"的依据
// （反代场景下网页端的本机能力接口本就不该暴露）。
func LocalOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !isLoopbackAddr(c.Request.RemoteAddr) {
			c.JSON(http.StatusForbidden, gin.H{"error": "该接口仅限本机访问"})
			c.Abort()
			return
		}
		c.Next()
	}
}

// isLoopbackAddr 判断 "host:port" 形式的对端地址是否为本机回环地址。
func isLoopbackAddr(remoteAddr string) bool {
	host := remoteAddr
	if parsedHost, _, err := net.SplitHostPort(remoteAddr); err == nil {
		host = parsedHost
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}
