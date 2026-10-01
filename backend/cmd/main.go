// Monarch HTTP 服务入口。
//
// 默认以生产模式启动（HTTPS + X-API-Key 鉴权）；`-mode local` 使用本地开发
// 模式（HTTP 且免鉴权）。
package main

import (
	"flag"
	"log"
	"path/filepath"

	"monarch/internal/config"
	"monarch/internal/handler/ops_handler"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/service/ai"
	"monarch/internal/service/db"
	"monarch/internal/service/gallery"
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

	// 运行时可调的 AI 配置存 static/data/ai_config.json（由桌面端界面读写）；
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

	migrateLegacyAISettings(store)
	store.ApplyTo(&config.AiConf)

	// AI 处理层：未启用或 ai schema 缺失时自行降级，不影响主服务启动
	ai.Default = ai.New(store, config.AiConf)
	ai.Default.Start()
	defer ai.Default.Stop()

	// gallery CLI 任务随服务退出一起中断（任务状态只存在内存里，留着也没人管）
	defer gallery.Manager.KillAll()

	server.StartServer()
}

// migrateLegacyAISettings 把旧版存在数据库 settings 表里的 AI 设置搬到配置文件。
//
// 只在首次生成配置文件时执行一次：若配置文件已存在，说明用户已在界面上配置过，
// 不再用旧值覆盖。旧表数据保持原样，便于回滚到旧版本。
func migrateLegacyAISettings(store *config.ConfigStore) {
	if !store.FirstLoad() {
		return
	}
	update := config.RuntimeConfig{}
	if caps, ok := ai_repo.LegacyAutoCapabilities(); ok {
		update.AutoCapabilities = &caps
	}
	if vlmModel, ok := ai_repo.LegacyVLMModel(); ok {
		update.VLMModel = &vlmModel
	}
	if update.AutoCapabilities == nil && update.VLMModel == nil {
		return
	}
	if err := store.Update(update); err != nil {
		log.Printf("迁移旧版 AI 设置失败（沿用默认值）: %v", err)
		return
	}
	log.Printf("已把旧版 AI 设置迁移到 %s", store.Path())
}
