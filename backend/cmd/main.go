// Monarch HTTP 服务入口。
//
// 默认以生产模式启动（HTTPS + X-API-Key 鉴权）；`-mode local` 使用本地开发
// 模式（HTTP 且免鉴权）。
package main

import (
	"flag"
	"log"

	"monarch/internal/config"
	"monarch/internal/service/ai"
	"monarch/internal/service/db"
	"monarch/internal/service/server"
)

func main() {
	mode := flag.String("mode", "", "启动模式: local=本地开发(HTTP+无鉴权), 默认生产模式(HTTPS+鉴权)")
	flag.Parse()

	// 先设置运行模式（Validate 依赖此值）
	config.IsLocalMode = *mode == "local"

	if err := config.Load(); err != nil {
		log.Fatalf("配置加载失败: %v", err)
	}

	db.Init(config.DbConf)
	defer db.Close()

	// AI 处理层：未启用或 ai schema 缺失时自行降级，不影响主服务启动
	ai.Default = ai.New(config.AiConf)
	ai.Default.Start()
	defer ai.Default.Stop()

	server.StartServer()
}
