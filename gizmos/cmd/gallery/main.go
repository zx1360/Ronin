package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"gizmos/internal/gallery/pipeline"
	"gizmos/internal/service/config"
	"gizmos/internal/service/db"
)

const (
	defaultGalleryDir = "D:\\Assests\\Gallery"
)

type galleryPaths struct {
	deletedDir string
	mediaDir   string
	previewDir string
	rawDir     string
	thumbsDir  string
}

func buildGalleryPaths(root string) galleryPaths {
	return galleryPaths{
		deletedDir: filepath.Join(root, "Deleted"),
		mediaDir:   filepath.Join(root, "Media"),
		previewDir: filepath.Join(root, "Preview"),
		rawDir:     filepath.Join(root, "Raw"),
		thumbsDir:  filepath.Join(root, "Thumbs"),
	}
}

func main() {
	// 解析命令行参数
	mode := flag.String("mode", "ingest", "运行模式: ingest(摄入) 或 execute(执行删除)")
	galleryDir := flag.String("gallery-root", defaultGalleryDir, "Gallery 根目录")
	concurrency := flag.Int("concurrency", 10, "并发处理数")
	batchSize := flag.Int("batch", 160, "批量写入大小")
	flag.Parse()

	paths := buildGalleryPaths(*galleryDir)

	// 打印配置信息
	fmt.Println("========== Gallery CLI ==========")
	fmt.Printf("运行模式: %s\n", *mode)
	fmt.Printf("Gallery 目录: %s\n", *galleryDir)
	fmt.Printf("  - Raw (待处理): %s\n", paths.rawDir)
	fmt.Printf("  - Media (媒体): %s\n", paths.mediaDir)
	fmt.Printf("  - Thumbs (缩略图): %s\n", paths.thumbsDir)
	fmt.Printf("  - Preview (预览图): %s\n", paths.previewDir)
	fmt.Printf("  - Deleted (已删除): %s\n", paths.deletedDir)
	fmt.Println("=================================")

	// 初始化数据库连接
	db.Init(config.DbConf)
	defer db.Close()

	// 创建带取消的上下文（支持优雅退出）
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 监听中断信号
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		log.Println("\n收到中断信号，正在优雅退出...")
		cancel()
	}()

	// 创建流水线配置
	pipelineConfig := pipeline.Config{
		RawDir:      paths.rawDir,
		MediaDir:    paths.mediaDir,
		ThumbsDir:   paths.thumbsDir,
		PreviewDir:  paths.previewDir,
		DeletedDir:  paths.deletedDir,
		Concurrency: *concurrency,
		BatchSize:   *batchSize,
	}

	// 创建流水线
	p := pipeline.NewPipeline(pipelineConfig)

	// 根据模式运行
	switch *mode {
	case "ingest":
		stats, err := p.RunIngestion(ctx)
		if err != nil {
			log.Fatalf("摄入流水线执行失败: %v", err)
		}
		printStats("摄入", stats)

	case "execute":
		stats, err := p.RunExecution(ctx)
		if err != nil {
			log.Fatalf("执行流水线执行失败: %v", err)
		}
		printStats("执行", stats)

	default:
		log.Fatalf("未知模式: %s (可选: ingest, execute)", *mode)
	}
}

// printStats 打印统计信息
func printStats(mode string, stats *pipeline.Stats) {
	fmt.Println()
	fmt.Printf("========== %s统计 ==========\n", mode)
	fmt.Printf("总文件数: %d\n", stats.TotalFiles)
	fmt.Printf("处理成功: %d\n", stats.ProcessedFiles)
	fmt.Printf("重复文件: %d\n", stats.DuplicateFiles)
	fmt.Printf("处理失败: %d\n", stats.FailedFiles)
	fmt.Printf("删除文件: %d\n", stats.DeletedFiles)
	fmt.Println("================================")
}
