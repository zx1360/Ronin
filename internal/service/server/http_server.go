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
	r.Run(fmt.Sprintf(":%s", localPort))
	log.Printf("服务核心已连线，端口: %s", localPort)
}
