// @title Monarch API
// @version 1.0
// @description Go HTTP server as the single source of truth for client integration.
// @BasePath /
// @schemes http https
// @securityDefinitions.apikey ApiKeyAuth
// @in header
// @name X-API-Key
package main

import (
	"flag"
	"monarch/internal/config"
	"monarch/internal/service/db"
	"monarch/internal/service/server"
)

func main() {
	mode := flag.String("mode", "", "启动模式: local=本地开发(HTTP+无鉴权), 默认生产模式(HTTPS+鉴权)")
	flag.Parse()

	// 加载配置（确保config.NetworkConf已正确配置）
	config.Load()
	config.IsLocalMode = *mode == "local"

	db.Init(config.DbConf)
	defer db.Close()

	// 启动服务
	server.StartServer()
}
