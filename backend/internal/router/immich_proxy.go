package router

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const immichUpstreamAddr = "http://127.0.0.1:2283"

var immichProxyMethods = []string{
	http.MethodGet,
	http.MethodPost,
	http.MethodPut,
	http.MethodPatch,
	http.MethodDelete,
	http.MethodHead,
	http.MethodOptions,
}

func registerImmichProxyRoutes(r *gin.Engine) {
	proxy, err := newImmichReverseProxy(immichUpstreamAddr)
	if err != nil {
		log.Printf("immich proxy init failed, serving 503 on /api: %v", err)
		unavailable := immichProxyUnavailableHandler()
		registerImmichProxyMethodRoutes(r, unavailable)
		return
	}

	handler := func(c *gin.Context) {
		proxy.ServeHTTP(c.Writer, c.Request)
		c.Abort()
	}

	registerImmichProxyMethodRoutes(r, handler)
}

func registerImmichProxyMethodRoutes(r *gin.Engine, handler gin.HandlerFunc) {
	for _, method := range immichProxyMethods {
		r.Handle(method, "/api", handler)
		r.Handle(method, "/api/*proxyPath", handler)
	}
}

func newImmichReverseProxy(rawTarget string) (*httputil.ReverseProxy, error) {
	targetURL, err := url.Parse(rawTarget)
	if err != nil {
		return nil, fmt.Errorf("invalid immich upstream address %q: %w", rawTarget, err)
	}

	transport := &http.Transport{
		Proxy:                 http.ProxyFromEnvironment,
		DialContext:           (&net.Dialer{Timeout: 5 * time.Second, KeepAlive: 30 * time.Second}).DialContext,
		MaxIdleConns:          100,
		MaxIdleConnsPerHost:   50,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   5 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}

	proxy := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.SetURL(targetURL)
			pr.SetXForwarded()

			// Force upstream Host to local Immich target for compatibility.
			pr.Out.Host = targetURL.Host

			if clientIP := extractRemoteIP(pr.In.RemoteAddr); clientIP != "" {
				pr.Out.Header.Set("X-Real-IP", clientIP)
			}
		},
		Transport: transport,
		ErrorHandler: func(rw http.ResponseWriter, req *http.Request, err error) {
			log.Printf("immich proxy request failed: %s %s: %v", req.Method, req.URL.String(), err)
			rw.Header().Set("Content-Type", "application/json; charset=utf-8")
			rw.WriteHeader(http.StatusBadGateway)
			_, _ = rw.Write([]byte(`{"error":"immich_upstream_unavailable","message":"Immich service is unavailable"}`))
		},
	}

	return proxy, nil
}

func immichProxyUnavailableHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{
			"error":   "immich_proxy_not_ready",
			"message": "Immich proxy is not available",
		})
	}
}

func extractRemoteIP(remoteAddr string) string {
	trimmed := strings.TrimSpace(remoteAddr)
	if trimmed == "" {
		return ""
	}

	host, _, err := net.SplitHostPort(trimmed)
	if err != nil {
		return trimmed
	}

	return host
}
