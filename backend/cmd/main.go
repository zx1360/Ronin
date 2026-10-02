// Monarch HTTP 服务入口。
//
// 单进程单端口（LOCAL_PORT）：HTTP 监听 + `X-API-Key` 鉴权；网页运维端在 `/ops/`，
// 与本机能力接口一样只接受回环地址访问。
package main

import (
	"flag"
	"log"
	"path/filepath"

	"monarch/internal/config"
	"monarch/internal/handler/ops_handler"
	"monarch/internal/service/ai"
	"monarch/internal/service/db"
	"monarch/internal/service/gallery"
	"monarch/internal/service/server"
)

func main() {
	// 没有命令行参数；保留 flag.Parse() 让 `-h` 能打印用法并退出
	// （契约快照脚本 references/scripts/generate_refs.ps1 会采集它）。
	flag.Parse()

	if err := config.Load(); err != nil {
		log.Fatalf("配置加载失败: %v", err)
	}

	// 运行时可调的 AI 配置.
	// .env 里的同名项只作为首次初始化的种子值。
	store := config.NewConfigStore(
		filepath.Join(config.AppConf.StaticDir, "data", "ai_config.json"), config.AiConf)
	if err := store.Load(); err != nil {
		log.Fatalf("AI 配置加载失败: %v", err)
	}

	db.Init(config.DbConf)
	defer db.Close()

	// 网页运维端（ops）的界面偏好存 static/data/ops_web.json，由服务端读写
	opsStore := config.NewOpsStore(filepath.Join(config.AppConf.StaticDir, "data", "ops_web.json"))
	if err := opsStore.Load(); err != nil {
		log.Fatalf("网页端偏好加载失败: %v", err)
	}
	ops_handler.SetStore(opsStore)

	store.ApplyTo(&config.AiConf)

	// AI 处理层：未启用或 ai schema 缺失时自行降级，不影响主服务启动
	ai.Default = ai.New(store, config.AiConf)
	// 任务队列的暂停状态随网页端偏好一起持久化：服务重启后不默认开跑
	ai.Default.SetPauseStore(opsStore)
	ai.Default.Start()
	defer ai.Default.Stop()

	// gallery CLI 任务随服务退出一起中断（任务状态只存在内存里，留着也没人管）
	defer gallery.Manager.KillAll()

	server.StartServer()
}
