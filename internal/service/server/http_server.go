package server

import (
	"fmt"
	"log"
	"monarch/internal/config"
	"monarch/internal/router"
)

// 启动HTTP服务
func StartServer() {
	r := router.SetupRouter()
	localPort := config.NetConf.LocalPort

	log.Printf("服务核心已连线，端口: %s", localPort)

	// Run() 是阻塞调用，启动日志需要在它之前打印
	if err := r.Run(fmt.Sprintf(":%s", localPort)); err != nil {
		log.Fatalf("HTTP服务启动失败: %v", err)
	}
}
