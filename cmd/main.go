package main

import (
	"log"
	"monarch/internal/config"
	"monarch/internal/service/db"
	"monarch/internal/service/server"
)

func main() {
	// 加载配置
	if err := config.Load(); err != nil {
		log.Fatalf("加载配置失败: %v", err)
	}
	db.Init(config.DbConf)
	defer db.Close()

	// 启动HTTP服务
	server.StartServer()
}
