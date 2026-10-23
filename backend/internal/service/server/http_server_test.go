package server

import (
	"context"
	cryptotls "crypto/tls"
	"io"
	"net"
	"net/http"
	"path/filepath"
	"testing"
	"time"

	"monarch/internal/service/tls"
)

func TestServeShutdown(t *testing.T) {
	dir := t.TempDir()
	cert, key := filepath.Join(dir, "server.crt"), filepath.Join(dir, "server.key")
	if err := tls.EnsureCert(cert, key); err != nil {
		t.Fatal(err)
	}
	for _, failTLS := range []bool{false, true} {
		t.Run(map[bool]string{false: "取消上下文", true: "单端启动失败"}[failTLS], func(t *testing.T) {
			secure, err := net.Listen("tcp", "127.0.0.1:0")
			if err != nil {
				t.Fatal(err)
			}
			defer secure.Close()
			local, err := net.Listen("tcp", "127.0.0.1:0")
			if err != nil {
				t.Fatal(err)
			}
			defer local.Close()
			ctx, cancel := context.WithCancel(t.Context())
			defer cancel()
			handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path == "/stream" {
					w.(http.Flusher).Flush()
					<-r.Context().Done()
					return
				}
				_, _ = io.WriteString(w, "ok")
			})
			finished := make(chan error, 1)
			certFile := cert
			if failTLS {
				certFile = filepath.Join(dir, "missing.crt")
			}
			go func() { finished <- serve(ctx, handler, secure, local, certFile, key) }()
			if !failTLS {
				transport := &http.Transport{TLSClientConfig: &cryptotls.Config{InsecureSkipVerify: true}}
				defer transport.CloseIdleConnections()
				client := &http.Client{Timeout: 3 * time.Second, Transport: transport}
				for _, url := range []string{"https://" + secure.Addr().String(), "http://" + local.Addr().String()} {
					response, err := client.Get(url)
					if err != nil {
						t.Fatal(err)
					}
					body, _ := io.ReadAll(response.Body)
					response.Body.Close()
					if string(body) != "ok" {
						t.Fatal("双端口响应不符")
					}
				}
				response, err := client.Get("http://" + local.Addr().String() + "/stream")
				if err != nil {
					t.Fatal(err)
				}
				defer response.Body.Close()
				cancel()
			}
			select {
			case err := <-finished:
				if (err != nil) != failTLS {
					t.Fatalf("退出结果不符: %v", err)
				}
			case <-time.After(3 * time.Second):
				t.Fatal("HTTP 未在取消或失败后退出")
			}
			for _, listener := range []net.Listener{secure, local} {
				reopened, err := net.Listen("tcp", listener.Addr().String())
				if err != nil {
					t.Fatalf("监听未释放: %v", err)
				}
				reopened.Close()
			}
		})
	}
}
