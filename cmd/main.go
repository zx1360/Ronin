package main

import (
	"monarch/internal/config"
	"monarch/internal/service/db"
	"monarch/internal/service/server"
)

func main() {
	// 加载配置（确保config.NetworkConf已正确配置）
	config.Load()
	db.Init(config.DbConf)
	defer db.Close()

	// 启动HTTP服务
	server.StartServer()
}
