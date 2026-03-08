package server

import (
	"fmt"
	"log"
	"monarch/internal/config"
	"monarch/internal/router"
	"monarch/internal/service/tls"
	"path/filepath"
)

// StartServer 根据运行模式启动 HTTP 或 HTTPS 服务
func StartServer() {
	r := router.SetupRouter()
	localPort := config.NetConf.LocalPort
	addr := fmt.Sprintf(":%s", localPort)

	if config.IsLocalMode {
		log.Printf("服务核心已连线（HTTP/本地模式），端口: %s", localPort)
		if err := r.Run(addr); err != nil {
			log.Fatalf("HTTP服务启动失败: %v", err)
		}
		return
	}

	certDir := "cert"
	certFile := filepath.Join(certDir, "server.crt")
	keyFile := filepath.Join(certDir, "server.key")

	if err := tls.EnsureCert(certFile, keyFile); err != nil {
		log.Fatalf("证书初始化失败: %v", err)
	}

	log.Printf("服务核心已连线（HTTPS），端口: %s", localPort)
	if err := r.RunTLS(addr, certFile, keyFile); err != nil {
		log.Fatalf("HTTPS服务启动失败: %v", err)
	}
}
