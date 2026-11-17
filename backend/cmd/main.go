package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"monarch/internal/config"
	"monarch/internal/handler/ops_handler"
	"monarch/internal/service/ai"
	"monarch/internal/service/comix"
	"monarch/internal/service/db"
	"monarch/internal/service/gallery"
	"monarch/internal/service/server"
)

func main() {
	// 解析 -h 供契约快照采集。
	flag.Parse()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := run(ctx); err != nil {
		log.Print(err)
		os.Exit(1)
	}
}

func run(parent context.Context) error {
	ctx, cancel := context.WithCancel(parent)
	defer cancel()
	if err := config.Load(); err != nil {
		return err
	}

	// .env 提供运行时配置的初始值。
	store := config.NewConfigStore(
		filepath.Join(config.AppConf.DataDir, "ai_config.json"), config.AiConf)
	if err := store.Load(); err != nil {
		return err
	}

	if err := db.Init(config.DbConf); err != nil {
		return err
	}
	defer db.Close()

	opsStore := config.NewOpsStore(filepath.Join(config.AppConf.DataDir, "ops_web.json"))
	if err := opsStore.Load(); err != nil {
		return err
	}
	ops_handler.SetStore(opsStore)

	store.ApplyTo(&config.AiConf)

	ai.Default = ai.New(store, config.AiConf)
	ai.Default.SetPauseStore(opsStore)
	ai.Default.Start(ctx)
	defer ai.Default.Stop()

	defer gallery.Manager.Close()
	defer comix.Manager.Close()

	err := server.StartServer(ctx)
	cancel()
	return err
}
