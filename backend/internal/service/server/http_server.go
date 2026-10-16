package server

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"monarch/internal/config"
	"monarch/internal/router"
	"monarch/internal/service/mdns"
	"monarch/internal/service/tls"
)

// StartServer 提供 HTTPS 与仅回环 HTTP；取消上下文或任一监听失败时关闭两端。
func StartServer(ctx context.Context) error {
	certFile := filepath.Join("cert", "server.crt")
	keyFile := filepath.Join("cert", "server.key")
	if err := tls.EnsureCert(certFile, keyFile); err != nil {
		return fmt.Errorf("证书初始化失败: %w", err)
	}
	secure, err := net.Listen("tcp", ":"+config.NetConf.LocalPort)
	if err != nil {
		return fmt.Errorf("HTTPS 监听失败: %w", err)
	}
	defer secure.Close()
	local, err := net.Listen("tcp", "127.0.0.1:"+config.NetConf.LocalHTTPPort)
	if err != nil {
		return fmt.Errorf("HTTP 监听失败: %w", err)
	}
	defer local.Close()

	stopMDNS := startMDNS(config.NetConf.LocalPort)
	defer stopMDNS()
	log.Printf("HTTPS 已监听 %s；HTTP 已监听 %s", secure.Addr(), local.Addr())
	return serve(ctx, router.SetupRouter(), secure, local, certFile, keyFile)
}

func serve(ctx context.Context, handler http.Handler, secure, local net.Listener, certFile, keyFile string) error {
	defer secure.Close()
	defer local.Close()
	requests, cancel := context.WithCancel(ctx)
	defer cancel()
	servers := []*http.Server{
		{Handler: handler, ReadHeaderTimeout: 10 * time.Second},
		{Handler: handler, ReadHeaderTimeout: 10 * time.Second},
	}
	for _, server := range servers {
		server.BaseContext = func(net.Listener) context.Context { return requests }
	}
	finished := make(chan error, 2)
	go func() { finished <- servers[0].ServeTLS(secure, certFile, keyFile) }()
	go func() { finished <- servers[1].Serve(local) }()
	remaining := 2
	var result error
	select {
	case <-ctx.Done():
	case err := <-finished:
		remaining--
		if !errors.Is(err, http.ErrServerClosed) {
			result = err
		}
	}
	cancel()
	shutdown, stop := context.WithTimeout(context.Background(), 10*time.Second)
	defer stop()
	for _, server := range servers {
		if err := server.Shutdown(shutdown); err != nil {
			result = errors.Join(result, err)
			_ = server.Close()
		}
	}
	for ; remaining > 0; remaining-- {
		<-finished
	}
	return result
}

func startMDNS(portStr string) func() {
	port, err := strconv.Atoi(portStr)
	if err != nil {
		log.Printf("[mDNS] 端口解析失败，跳过注册: %v", err)
		return func() {}
	}
	hostname, _ := os.Hostname()
	server, err := mdns.Register(mdns.ServiceInfo{
		Instance: fmt.Sprintf("Monarch on %s", hostname), Port: port,
		IsHTTPS: true, HasAuth: true,
	})
	if err != nil {
		log.Printf("[mDNS] 服务注册失败: %v", err)
		return func() {}
	}
	return func() { _ = server.Shutdown() }
}
