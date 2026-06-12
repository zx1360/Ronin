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

	// 先设置运行模式 (Validate 依赖此值)
	config.IsLocalMode = *mode == "local"

	// 加载并校验配置
	if err := config.Load(); err != nil {
		panic("配置加载失败: " + err.Error())
	}

	db.Init(config.DbConf)
	defer db.Close()

	// 启动服务
	server.StartServer()
}
