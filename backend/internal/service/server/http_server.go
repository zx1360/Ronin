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

// StartServer 同时监听两个端口，接口完全一致，只有协议不同：
//
//	LOCAL_PORT      HTTPS（自签证书，供 Android 等局域网消费端）
//	LOCAL_HTTP_PORT HTTP （供本机浏览器打开运维页面，免证书警告）
//
// 不需要"启动模式"开关：网页运维端与它的本机能力接口只接受回环地址
// （见 router 的 LocalOnly），与走哪个端口无关；其余接口两个端口都要 X-API-Key。
func StartServer() {
	// 后台预热目录用量缓存（ops/overview 毫秒级响应）
	util_handler.StartDirUsageRefresher()

	r := router.SetupRouter()

	httpsPort := config.NetConf.LocalPort
	httpPort := config.NetConf.LocalHTTPPort

	certFile := filepath.Join("cert", "server.crt")
	keyFile := filepath.Join("cert", "server.key")
	if err := tls.EnsureCert(certFile, keyFile); err != nil {
		log.Fatalf("证书初始化失败: %v", err)
	}

	// mDNS 广播 HTTPS 端口：局域网消费端沿用原有连法
	startMDNS(httpsPort)

	errCh := make(chan error, 2)

	go func() {
		log.Printf("HTTPS 已监听 :%s（网页运维端: https://127.0.0.1:%s/ops/）", httpsPort, httpsPort)
		if err := r.RunTLS(":"+httpsPort, certFile, keyFile); err != nil {
			errCh <- fmt.Errorf("HTTPS 服务启动失败: %w", err)
		}
	}()

	go func() {
		log.Printf("HTTP  已监听 :%s（网页运维端: http://127.0.0.1:%s/ops/）", httpPort, httpPort)
		if err := r.Run(":" + httpPort); err != nil {
			errCh <- fmt.Errorf("HTTP 服务启动失败: %w", err)
		}
	}()

	// 任一监听失败即整体退出：少一个端口属于配置问题，不该悄悄降级
	log.Fatalf("%v", <-errCh)
}

// startMDNS 启动 mDNS 服务注册（供 Android 端自动发现，指向 HTTPS 端口）。
func startMDNS(portStr string) {
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
			IsHTTPS:  true,
			HasAuth:  true,
		})
		if err != nil {
			log.Printf("[mDNS] 服务注册失败: %v", err)
		}
	}()
}
