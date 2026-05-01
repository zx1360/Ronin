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
	"gizmos/internal/gallery/refresh"
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
	mode := flag.String("mode", "ingest", "运行模式: ingest(摄入) | execute(执行删除) | refresh(刷新修复)")
	galleryDir := flag.String("gallery-root", defaultGalleryDir, "Gallery 根目录")
	concurrency := flag.Int("concurrency", 10, "并发处理数")
	batchSize := flag.Int("batch", 160, "批量写入大小")
	resize := flag.Int("resize", 0, "refresh 模式: 同时设置预览图最大边和缩略图边长（像素，>0 生效）")
	resizePreview := flag.Int("resizePreview", 0, "refresh 模式: 单独设置预览图最大边（像素，>0 生效）")
	resizeThumb := flag.Int("resizeThumb", 0, "refresh 模式: 单独设置缩略图边长（像素，>0 生效）")
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

	case "refresh":
		refresher, err := refresh.NewRefresher(refresh.Config{
			MediaDir:      paths.mediaDir,
			ThumbsDir:     paths.thumbsDir,
			PreviewDir:    paths.previewDir,
			Concurrency:   *concurrency,
			Resize:        *resize,
			ResizePreview: *resizePreview,
			ResizeThumb:   *resizeThumb,
		})
		if err != nil {
			log.Fatalf("refresh 配置无效: %v", err)
		}

		stats, err := refresher.Run(ctx)
		if err != nil {
			log.Fatalf("refresh 执行失败: %v", err)
		}
		printRefreshStats(stats)

	default:
		log.Fatalf("未知模式: %s (可选: ingest, execute, refresh)", *mode)
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

// printRefreshStats 打印 refresh 统计信息
func printRefreshStats(stats *refresh.Stats) {
	fmt.Println()
	fmt.Println("========== refresh统计 ==========")
	fmt.Printf("总记录数: %d\n", stats.TotalRecords)
	fmt.Printf("步骤1 无效源记录: %d\n", stats.Step1InvalidSourceRecords)
	fmt.Printf("步骤1 删除成功: %d\n", stats.Step1DeletedRecords)
	fmt.Printf("步骤1 删除失败: %d\n", stats.Step1DeleteFailedRecords)
	fmt.Printf("步骤2 重建候选: %d\n", stats.Step2ResizeCandidates)
	fmt.Printf("步骤2 重建缩略图: %d\n", stats.Step2ResizedThumbFiles)
	fmt.Printf("步骤2 重建预览图: %d\n", stats.Step2ResizedPreviewFiles)
	fmt.Printf("步骤2 失败记录: %d\n", stats.Step2FailedRecords)
	fmt.Printf("步骤3 缺失候选: %d\n", stats.Step3MissingCandidates)
	fmt.Printf("步骤3 修复成功: %d\n", stats.Step3FixedRecords)
	fmt.Printf("步骤3 修复失败: %d\n", stats.Step3FailedRecords)
	fmt.Println("================================")
}
