package server

import (
	"fmt"
	"log"
	"monarch/internal/config"
	"monarch/internal/handler/util_handler"
	"monarch/internal/router"
	"monarch/internal/service/mdns"
	"monarch/internal/service/tls"
	"os"
	"path/filepath"
	"strconv"
)

// StartServer 根据运行模式启动 HTTP 或 HTTPS 服务
func StartServer() {
	// 后台预热目录用量缓存（ops/overview 毫秒级响应）
	util_handler.StartDirUsageRefresher()

	r := router.SetupRouter()

	if config.IsLocalMode {
		port := config.NetConf.LocalDebugPort
		log.Printf("服务核心已连线（HTTP/本地模式），端口: %s", port)

		// 启动 mDNS 服务发现 (本地模式, HTTP)
		startMDNS(port, false, false)

		if err := r.Run(fmt.Sprintf(":%s", port)); err != nil {
			log.Fatalf("HTTP服务启动失败: %v", err)
		}
		return
	}

	localPort := config.NetConf.LocalPort
	addr := fmt.Sprintf(":%s", localPort)

	certDir := "cert"
	certFile := filepath.Join(certDir, "server.crt")
	keyFile := filepath.Join(certDir, "server.key")

	if err := tls.EnsureCert(certFile, keyFile); err != nil {
		log.Fatalf("证书初始化失败: %v", err)
	}

	// 启动 mDNS 服务发现 (生产模式, HTTPS, 鉴权)
	startMDNS(localPort, true, true)

	log.Printf("服务核心已连线（HTTPS），端口: %s", localPort)
	if err := r.RunTLS(addr, certFile, keyFile); err != nil {
		log.Fatalf("HTTPS服务启动失败: %v", err)
	}
}

// startMDNS 启动 mDNS 服务注册
func startMDNS(portStr string, isHTTPS bool, hasAuth bool) {
	port, err := strconv.Atoi(portStr)
	if err != nil {
		log.Printf("[mDNS] 端口解析失败，跳过服务注册: %v", err)
		return
	}

	hostname, _ := os.Hostname()
	instance := fmt.Sprintf("Monarch on %s", hostname)

	go func() {
		_, err := mdns.Register(mdns.ServiceInfo{
			Instance: instance,
			Port:     port,
			IsHTTPS:  isHTTPS,
			HasAuth:  hasAuth,
		})
		if err != nil {
			log.Printf("[mDNS] 服务注册失败: %v", err)
		}
	}()
}
