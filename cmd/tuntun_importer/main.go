package main

import (
	"gizmos/internal/db"
	"gizmos/internal/tuntun"
	"log"
)

const (
	sourceDir = "D:\\products\\Go\\monarch\\static\\tuntun_1\\raw"    // 源文件目录
	destDir   = "D:\\products\\Go\\monarch\\static\\tuntun_1\\medias" // 目标文件目录
)

func main() {
	// 1. 加载数据库配置
	cfg := db.LoadConfigFromEnv()

	// 2. 连接数据库
	pgDB, err := db.NewPostgresDB(cfg)
	if err != nil {
		log.Fatalf("failed to connect to postgres: %v", err)
	}
	defer pgDB.Close()
	log.Println("successfully connected to postgres")

	// 3. 初始化仓库和服务
	repo := tuntun.NewRepo(pgDB)
	service := tuntun.NewService(repo)

	// 4. 初始化表结构
	if err := repo.InitSchema(); err != nil {
		log.Fatalf("failed to init schema: %v", err)
	}
	log.Println("successfully initialized database schema")

	// 5. 同步媒体文件
	log.Printf("starting sync media files from %s to %s...\n", sourceDir, destDir)
	if err := service.SyncMediaFiles(sourceDir, destDir); err != nil {
		log.Fatalf("sync media files failed: %v", err)
	}
	log.Println("sync media files completed successfully")
}
