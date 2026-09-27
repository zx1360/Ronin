package server

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"monarch/internal/config"
	"monarch/internal/handler/ops_handler"
	"monarch/internal/router"
	"monarch/internal/service/comix"
	"monarch/internal/service/mdns"
	"monarch/internal/service/ops"
	"monarch/internal/service/tls"
)

// StartServer 启动 HTTP/HTTPS 服务。
//
// 生产模式同时开两个监听：
//   - LAN 监听：HTTPS + X-API-Key，供 Android 与局域网客户端使用；
//   - 回环监听：只绑 127.0.0.1 的 HTTP，供 ops 网页应用与其本机能力接口使用。
//     浏览器无法静默信任自签证书，也无法为 <img>/<a> 注入自定义请求头，
//     因此 ops 必须走一条独立的回环明文通道。
//
// 本地开发模式只有一个监听：调试端口即主服务（HTTP 免鉴权），手机端可直接连局域网 IP。
func StartServer() {
	// 后台预热目录用量缓存（ops/overview 毫秒级响应）
	ops_handler.StartDirUsageRefresher()
	// ops 界面偏好与数据库同目录
	ops.InitPreferences(filepath.Dir(config.DBPath))

	r := router.SetupRouter()
	// 退出时回收子进程：gallery CLI 与 comix 爬虫都不该留在后台
	defer ops.Gallery.KillAllGallery()
	defer comix.Manager.KillAll()

	if config.IsLocalMode {
		port := config.NetConf.LocalDebugPort
		startMDNS(port, false, false)
		log.Printf("服务核心已连线（HTTP/本地模式），端口: %s，ops: http://127.0.0.1:%s/ops/", port, port)
		if err := r.Run(fmt.Sprintf(":%s", port)); err != nil {
			log.Fatalf("HTTP服务启动失败: %v", err)
		}
		return
	}

	localPort := config.NetConf.LocalPort
	startLoopback(r, config.NetConf.LocalDebugPort)

	certDir := "cert"
	certFile := filepath.Join(certDir, "server.crt")
	keyFile := filepath.Join(certDir, "server.key")
	if err := tls.EnsureCert(certFile, keyFile); err != nil {
		log.Fatalf("证书初始化失败: %v", err)
	}

	startMDNS(localPort, true, true)

	log.Printf("服务核心已连线（HTTPS），端口: %s", localPort)
	log.Printf("ops 网页端: http://127.0.0.1:%s/ops/", config.NetConf.LocalDebugPort)
	if err := r.RunTLS(fmt.Sprintf(":%s", localPort), certFile, keyFile); err != nil {
		log.Fatalf("HTTPS服务启动失败: %v", err)
	}
}

// startLoopback 在回环地址上启动 HTTP 监听（不参与 mDNS 注册，仅本机可达）。
func startLoopback(handler http.Handler, port string) {
	srv := &http.Server{
		Addr:              "127.0.0.1:" + port,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
	}
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("回环监听启动失败（ops 网页端不可用）: %v", err)
		}
	}()
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
