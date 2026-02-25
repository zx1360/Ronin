// 由于之前nodejs的归档格式问题，Gallery 旧版使用按年月划分的文件夹存储媒体文件，
// 例如 2022_01、2022-02 等目录。该工具用于将这些旧版文件迁移到新的按月归档格式中，
// 并生成相应的缩略图和预览图，同时将重复文件移动到已删除目录中。
package main

import (
	"context"
	"crypto/sha256"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/google/uuid"

	"gizmos/internal/gallery/model"
	"gizmos/internal/gallery/processor"
	"gizmos/internal/gallery/repository"
	"gizmos/internal/service/config"
	"gizmos/internal/service/db"
)

const (
	galleryDir = "D:\\Assests\\Gallery"
)

var (
	deletedDir = filepath.Join(galleryDir, "Deleted")
	mediaDir   = filepath.Join(galleryDir, "Media")
	previewDir = filepath.Join(galleryDir, "Preview")
	rawDir     = filepath.Join(galleryDir, "Raw")
	thumbsDir  = filepath.Join(galleryDir, "Thumbs")
)

// 匹配 yyyy_mm 或 yyyy-mm 格式的目录名
var yearMonthPattern = regexp.MustCompile(`^(\d{4})[_-](\d{2})$`)

// Stats 统计信息
type Stats struct {
	TotalFiles     int64
	ProcessedFiles int64
	DuplicateFiles int64
	FailedFiles    int64
}

// MigrationPipeline 迁移流水线
type MigrationPipeline struct {
	rawDir      string
	mediaDir    string
	thumbsDir   string
	previewDir  string
	deletedDir  string
	concurrency int
	batchSize   int
	processor   *processor.Processor
	repository  *repository.Repository
}

// FileTask 文件处理任务
type FileTask struct {
	FilePath   string
	YearMonth  string // yyyy-mm 格式
	CapturedAt time.Time
}

func main() {
	// 命令行参数
	concurrency := flag.Int("concurrency", 4, "并发处理数")
	batchSize := flag.Int("batch", 50, "批量写入大小")
	dryRun := flag.Bool("dry-run", false, "仅扫描不执行，用于预览")
	flag.Parse()

	fmt.Println("========== Gallery 迁移工具 ==========")
	fmt.Printf("Raw 目录: %s\n", rawDir)
	fmt.Printf("Media 目录: %s\n", mediaDir)
	fmt.Printf("并发数: %d\n", *concurrency)
	fmt.Printf("试运行模式: %v\n", *dryRun)
	fmt.Println("=======================================")

	// 初始化数据库
	db.Init(config.DbConf)
	defer db.Close()

	// 创建上下文
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

	// 创建迁移流水线
	pipeline := &MigrationPipeline{
		rawDir:      rawDir,
		mediaDir:    mediaDir,
		thumbsDir:   thumbsDir,
		previewDir:  previewDir,
		deletedDir:  deletedDir,
		concurrency: *concurrency,
		batchSize:   *batchSize,
		processor:   processor.NewProcessor(thumbsDir, previewDir),
		repository:  repository.NewRepository(),
	}

	// 运行迁移
	stats, err := pipeline.Run(ctx, *dryRun)
	if err != nil {
		log.Fatalf("迁移失败: %v", err)
	}

	// 打印统计
	fmt.Println()
	fmt.Println("========== 迁移统计 ==========")
	fmt.Printf("总文件数: %d\n", stats.TotalFiles)
	fmt.Printf("处理成功: %d\n", stats.ProcessedFiles)
	fmt.Printf("重复文件: %d\n", stats.DuplicateFiles)
	fmt.Printf("处理失败: %d\n", stats.FailedFiles)
	fmt.Println("==============================")
}

// Run 运行迁移流水线
func (p *MigrationPipeline) Run(ctx context.Context, dryRun bool) (*Stats, error) {
	stats := &Stats{}

	// 确保目录存在
	if err := p.ensureDirectories(); err != nil {
		return nil, fmt.Errorf("创建目录失败: %w", err)
	}

	// 扫描文件任务
	log.Println("扫描 Raw 目录中的旧归档文件...")
	tasks, err := p.scanLegacyFiles()
	if err != nil {
		return nil, fmt.Errorf("扫描文件失败: %w", err)
	}

	log.Printf("找到 %d 个待迁移文件", len(tasks))
	stats.TotalFiles = int64(len(tasks))

	if dryRun {
		log.Println("试运行模式，不执行实际操作")
		// 打印前20个文件作为预览
		for i, task := range tasks {
			if i >= 20 {
				log.Printf("... 还有 %d 个文件", len(tasks)-20)
				break
			}
			log.Printf("  [%s] %s", task.YearMonth, filepath.Base(task.FilePath))
		}
		return stats, nil
	}

	// 工作队列
	taskChan := make(chan FileTask, p.concurrency*2)
	resultChan := make(chan *model.MediaAsset, p.concurrency*2)
	doneChan := make(chan struct{})

	// 批量写入协程
	go p.batchWriter(ctx, resultChan, doneChan, stats)

	// 启动工作协程
	var wg sync.WaitGroup
	for i := 0; i < p.concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			p.worker(ctx, workerID, taskChan, resultChan, stats)
		}(i)
	}

	// 分发任务
	for _, task := range tasks {
		select {
		case <-ctx.Done():
			break
		case taskChan <- task:
		}
	}
	close(taskChan)

	// 等待工作完成
	wg.Wait()
	close(resultChan)

	// 等待写入完成
	<-doneChan

	// 清理空目录
	log.Println("清理 Raw 目录中的空文件夹...")
	p.cleanEmptyDirsRecursive(p.rawDir)

	return stats, nil
}

// scanLegacyFiles 扫描旧归档文件
func (p *MigrationPipeline) scanLegacyFiles() ([]FileTask, error) {
	var tasks []FileTask

	// 遍历 rawDir 下的子目录
	entries, err := os.ReadDir(p.rawDir)
	if err != nil {
		return nil, err
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		dirName := entry.Name()
		// 匹配 yyyy_mm 或 yyyy-mm 格式
		matches := yearMonthPattern.FindStringSubmatch(dirName)
		if matches == nil {
			log.Printf("跳过不匹配的目录: %s", dirName)
			continue
		}

		year := matches[1]
		month := matches[2]
		// 转换为标准格式 yyyy-mm
		yearMonth := fmt.Sprintf("%s-%s", year, month)

		// 解析日期（使用该月第一天作为 captured_at）
		capturedAt, err := time.Parse("2006-01", yearMonth)
		if err != nil {
			log.Printf("解析日期失败 %s: %v", dirName, err)
			continue
		}

		// 扫描该目录下的所有媒体文件
		subDirPath := filepath.Join(p.rawDir, dirName)
		err = filepath.Walk(subDirPath, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if info.IsDir() {
				return nil
			}

			ext := strings.ToLower(filepath.Ext(path))
			if model.IsSupportedFile(ext) {
				tasks = append(tasks, FileTask{
					FilePath:   path,
					YearMonth:  yearMonth,
					CapturedAt: capturedAt,
				})
			}
			return nil
		})
		if err != nil {
			log.Printf("扫描目录 %s 失败: %v", dirName, err)
		}
	}

	return tasks, nil
}

// worker 工作协程
func (p *MigrationPipeline) worker(ctx context.Context, workerID int, taskChan <-chan FileTask, resultChan chan<- *model.MediaAsset, stats *Stats) {
	for task := range taskChan {
		select {
		case <-ctx.Done():
			return
		default:
		}

		asset, err := p.processFile(ctx, task)
		if err != nil {
			if err == ErrDuplicate {
				atomic.AddInt64(&stats.DuplicateFiles, 1)
				log.Printf("[Worker %d] 重复文件: %s", workerID, filepath.Base(task.FilePath))
			} else {
				atomic.AddInt64(&stats.FailedFiles, 1)
				log.Printf("[Worker %d] 处理失败: %s - %v", workerID, filepath.Base(task.FilePath), err)
			}
			continue
		}

		resultChan <- asset
		atomic.AddInt64(&stats.ProcessedFiles, 1)
		log.Printf("[Worker %d] 处理完成: %s -> %s", workerID, filepath.Base(task.FilePath), task.YearMonth)
	}
}

// ErrDuplicate 重复文件错误
var ErrDuplicate = fmt.Errorf("duplicate file")

// processFile 处理单个文件
func (p *MigrationPipeline) processFile(ctx context.Context, task FileTask) (*model.MediaAsset, error) {
	filePath := task.FilePath

	// 获取文件信息
	stat, err := os.Stat(filePath)
	if err != nil {
		return nil, fmt.Errorf("获取文件信息失败: %w", err)
	}

	ext := strings.ToLower(filepath.Ext(filePath))
	fileName := filepath.Base(filePath)

	// 计算哈希
	hash, err := calculateHash(filePath)
	if err != nil {
		return nil, fmt.Errorf("计算哈希失败: %w", err)
	}

	// 检查哈希是否存在
	dbCtx, cancel := db.GetDefaultCtx()
	defer cancel()

	exists, err := p.repository.HashExists(dbCtx, hash)
	if err != nil {
		return nil, fmt.Errorf("检查哈希失败: %w", err)
	}

	if exists {
		// 移动到删除目录
		if err := p.moveToDeleted(filePath); err != nil {
			log.Printf("移动重复文件失败: %v", err)
		}
		return nil, ErrDuplicate
	}

	// 移动文件到 mediaDir
	mediaSubDir := filepath.Join(p.mediaDir, task.YearMonth)
	if err := os.MkdirAll(mediaSubDir, 0755); err != nil {
		return nil, fmt.Errorf("创建媒体目录失败: %w", err)
	}

	newFileName := p.generateUniqueFileName(mediaSubDir, fileName)
	newMediaPath := filepath.Join(mediaSubDir, newFileName)

	if err := moveFile(filePath, newMediaPath); err != nil {
		return nil, fmt.Errorf("移动文件失败: %w", err)
	}

	// 构建 FileInfo 用于生成缩略图
	isVideo := model.IsVideo(ext)
	isAnimated := model.IsAnimatedImage(ext)
	mimeType := model.GetMimeType(ext)

	fileInfo := &model.FileInfo{
		OriginalPath: newMediaPath,
		FileName:     newFileName,
		Extension:    ext,
		SizeBytes:    stat.Size(),
		Hash:         hash,
		MimeType:     mimeType,
		CapturedAt:   task.CapturedAt,
		IsVideo:      isVideo,
		IsAnimated:   isAnimated,
	}

	// 生成缩略图和预览图
	processResult, err := p.processor.Process(fileInfo, newMediaPath, task.YearMonth)
	if err != nil {
		log.Printf("生成缩略图/预览图失败: %v", err)
		processResult = &processor.ProcessResult{}
	}

	// 构建媒体资产
	thumbPath := processResult.ThumbPath
	previewPath := processResult.PreviewPath

	asset := &model.MediaAsset{
		ID:          uuid.New(),
		CapturedAt:  task.CapturedAt,
		FilePath:    filepath.Join(task.YearMonth, newFileName),
		ThumbPath:   strPtr(thumbPath),
		PreviewPath: strPtr(previewPath),
		Hash:        hash,
		SizeBytes:   stat.Size(),
		MimeType:    &mimeType,
		IsDeleted:   false,
		SyncCount:   0,
		GroupID:     nil,
	}

	return asset, nil
}

// batchWriter 批量写入数据库
func (p *MigrationPipeline) batchWriter(ctx context.Context, resultChan <-chan *model.MediaAsset, doneChan chan<- struct{}, stats *Stats) {
	defer close(doneChan)

	batch := make([]*model.MediaAsset, 0, p.batchSize)
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	flush := func() {
		if len(batch) == 0 {
			return
		}

		dbCtx, cancel := db.GetLongCtx()
		defer cancel()

		if err := p.repository.BatchInsertMediaAssets(dbCtx, batch); err != nil {
			log.Printf("批量写入失败: %v", err)
			atomic.AddInt64(&stats.FailedFiles, int64(len(batch)))
		} else {
			log.Printf("批量写入成功: %d 条记录", len(batch))
		}

		batch = batch[:0]
	}

	for {
		select {
		case asset, ok := <-resultChan:
			if !ok {
				flush()
				return
			}
			batch = append(batch, asset)
			if len(batch) >= p.batchSize {
				flush()
			}

		case <-ticker.C:
			flush()

		case <-ctx.Done():
			flush()
			return
		}
	}
}

// moveToDeleted 移动文件到删除目录
func (p *MigrationPipeline) moveToDeleted(filePath string) error {
	fileName := filepath.Base(filePath)
	dst := filepath.Join(p.deletedDir, "duplicates", fileName)
	return moveFileWithDir(filePath, dst)
}

// generateUniqueFileName 生成唯一文件名
func (p *MigrationPipeline) generateUniqueFileName(dir, originalName string) string {
	name := originalName
	ext := filepath.Ext(originalName)
	baseName := strings.TrimSuffix(originalName, ext)

	counter := 1
	for {
		fullPath := filepath.Join(dir, name)
		if _, err := os.Stat(fullPath); os.IsNotExist(err) {
			return name
		}
		name = fmt.Sprintf("%s_%d%s", baseName, counter, ext)
		counter++
	}
}

// ensureDirectories 确保目录存在
func (p *MigrationPipeline) ensureDirectories() error {
	dirs := []string{p.rawDir, p.mediaDir, p.thumbsDir, p.previewDir, p.deletedDir}
	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
	}
	return nil
}

// cleanEmptyDirsRecursive 递归清理空目录
func (p *MigrationPipeline) cleanEmptyDirsRecursive(rootDir string) {
	var dirs []string
	filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() && path != rootDir {
			dirs = append(dirs, path)
		}
		return nil
	})

	// 从后往前遍历（最深的目录在后面）
	for i := len(dirs) - 1; i >= 0; i-- {
		dir := dirs[i]
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		if len(entries) == 0 {
			if err := os.Remove(dir); err == nil {
				log.Printf("清理空目录: %s", dir)
			}
		}
	}
}

// calculateHash 计算文件 SHA-256 哈希
func calculateHash(filePath string) ([]byte, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return nil, err
	}

	return hasher.Sum(nil), nil
}

// moveFile 移动文件
func moveFile(src, dst string) error {
	if err := os.Rename(src, dst); err == nil {
		return nil
	}

	// 跨文件系统时，复制后删除
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()

	if _, err := dstFile.ReadFrom(srcFile); err != nil {
		return err
	}

	srcInfo, err := os.Stat(src)
	if err == nil {
		os.Chmod(dst, srcInfo.Mode())
	}

	return os.Remove(src)
}

// moveFileWithDir 移动文件（自动创建目录）
func moveFileWithDir(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}
	return moveFile(src, dst)
}

// strPtr 字符串指针辅助函数
func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
