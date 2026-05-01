// Package pipeline 实现媒体文件的摄入和执行流水线
package pipeline

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"

	"gizmos/internal/gallery/model"
	"gizmos/internal/gallery/processor"
	"gizmos/internal/gallery/repository"
	"gizmos/internal/gallery/scanner"
	"gizmos/internal/service/db"
)

// Config 流水线配置
type Config struct {
	RawDir      string // 原始文件目录
	MediaDir    string // 媒体存储目录
	ThumbsDir   string // 缩略图目录
	PreviewDir  string // 预览图目录
	DeletedDir  string // 删除文件目录
	Concurrency int    // 并发数
	BatchSize   int    // 批量写入大小
}

// Pipeline 流水线
type Pipeline struct {
	config     Config
	scanner    *scanner.Scanner
	processor  *processor.Processor
	repository *repository.Repository
}

// Stats 统计信息
type Stats struct {
	TotalFiles     int64
	ProcessedFiles int64
	DuplicateFiles int64
	FailedFiles    int64
	DeletedFiles   int64
}

// NewPipeline 创建新的流水线
func NewPipeline(config Config) *Pipeline {
	if config.Concurrency <= 0 {
		config.Concurrency = 4
	}
	if config.BatchSize <= 0 {
		config.BatchSize = 50
	}

	return &Pipeline{
		config:     config,
		scanner:    scanner.NewScanner(config.RawDir),
		processor:  processor.NewProcessor(config.ThumbsDir, config.PreviewDir),
		repository: repository.NewRepository(),
	}
}

// RunIngestion 运行摄入流水线
func (p *Pipeline) RunIngestion(ctx context.Context) (*Stats, error) {
	log.Println("========== 开始摄入流水线 ==========")
	log.Printf("原始目录: %s", p.config.RawDir)
	log.Printf("媒体目录: %s", p.config.MediaDir)
	log.Printf("并发数: %d", p.config.Concurrency)

	stats := &Stats{}

	// 确保目录存在
	if err := p.ensureDirectories(); err != nil {
		return nil, fmt.Errorf("创建目录失败: %w", err)
	}

	// 扫描文件
	pathChan, errChan := p.scanner.ScanDir()

	// 收集扫描错误
	go func() {
		for err := range errChan {
			log.Printf("扫描警告: %v", err)
		}
	}()

	// 工作队列
	type workItem struct {
		path string
	}
	workChan := make(chan workItem, p.config.Concurrency*2)

	// 结果收集
	resultChan := make(chan *model.MediaAsset, p.config.Concurrency*2)
	doneChan := make(chan struct{})

	// 批量写入协程
	go p.batchWriter(ctx, resultChan, doneChan, stats)

	// 启动工作协程
	var wg sync.WaitGroup
	for i := 0; i < p.config.Concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for work := range workChan {
				select {
				case <-ctx.Done():
					return
				default:
				}

				asset, err := p.processFile(ctx, work.path)
				if err != nil {
					if err == ErrDuplicate {
						atomic.AddInt64(&stats.DuplicateFiles, 1)
						log.Printf("[Worker %d] 重复文件: %s", workerID, filepath.Base(work.path))
					} else {
						atomic.AddInt64(&stats.FailedFiles, 1)
						log.Printf("[Worker %d] 处理失败: %s - %v", workerID, filepath.Base(work.path), err)
					}
					continue
				}

				resultChan <- asset
				atomic.AddInt64(&stats.ProcessedFiles, 1)
				log.Printf("[Worker %d] 处理完成: %s", workerID, filepath.Base(work.path))
			}
		}(i)
	}

	// 分发工作
	for path := range pathChan {
		atomic.AddInt64(&stats.TotalFiles, 1)
		workChan <- workItem{path: path}
	}
	close(workChan)

	// 等待所有工作完成
	wg.Wait()
	close(resultChan)

	// 等待批量写入完成
	<-doneChan

	// 清理 rawDir 中的空目录
	log.Println("清理 Raw 目录中的空文件夹...")
	p.cleanEmptyDirsRecursive(p.config.RawDir)

	log.Println("========== 摄入流水线完成 ==========")
	log.Printf("总文件数: %d", stats.TotalFiles)
	log.Printf("处理成功: %d", stats.ProcessedFiles)
	log.Printf("重复文件: %d", stats.DuplicateFiles)
	log.Printf("处理失败: %d", stats.FailedFiles)

	return stats, nil
}

// ErrDuplicate 重复文件错误
var ErrDuplicate = fmt.Errorf("duplicate file")

// processFile 处理单个文件
func (p *Pipeline) processFile(ctx context.Context, filePath string) (*model.MediaAsset, error) {
	// 1. 提取文件信息
	fileInfo, err := p.scanner.ExtractFileInfo(filePath)
	if err != nil {
		return nil, fmt.Errorf("提取文件信息失败: %w", err)
	}

	// 2. 检查哈希是否存在
	dbCtx, cancel := db.GetDefaultCtx()
	defer cancel()

	exists, err := p.repository.HashExists(dbCtx, fileInfo.Hash)
	if err != nil {
		return nil, fmt.Errorf("检查哈希失败: %w", err)
	}

	if exists {
		// 移动到删除目录
		if err := p.moveToDeleted(filePath); err != nil {
			log.Printf("移动重复文件到删除目录失败: %v", err)
		}
		return nil, ErrDuplicate
	}

	// 3. 计算年月目录
	yearMonth := fileInfo.CapturedAt.Format("2006-01")

	// 4. 移动原文件到媒体目录
	mediaSubDir := filepath.Join(p.config.MediaDir, yearMonth)
	if err := os.MkdirAll(mediaSubDir, 0755); err != nil {
		return nil, fmt.Errorf("创建媒体子目录失败: %w", err)
	}

	// 生成唯一文件名（避免冲突）
	newFileName := p.generateUniqueFileName(mediaSubDir, fileInfo.FileName)
	newMediaPath := filepath.Join(mediaSubDir, newFileName)

	if err := moveFile(filePath, newMediaPath); err != nil {
		return nil, fmt.Errorf("移动文件失败: %w", err)
	}

	// 5. 生成缩略图和预览图
	// 更新 fileInfo 的文件名（可能已更改）
	fileInfo.FileName = newFileName
	processResult, err := p.processor.Process(fileInfo, newMediaPath, yearMonth)
	if err != nil {
		// 处理失败时，尝试将文件移回或删除
		log.Printf("生成缩略图/预览图失败: %v", err)
		// 仍然继续，使用空的缩略图路径
		processResult = &processor.ProcessResult{}
	}

	// 6. 构建媒体资产
	mimeType := fileInfo.MimeType
	thumbPath := processResult.ThumbPath
	previewPath := processResult.PreviewPath

	asset := &model.MediaAsset{
		ID:          uuid.New(),
		CapturedAt:  fileInfo.CapturedAt,
		FilePath:    filepath.Join(yearMonth, newFileName),
		ThumbPath:   strPtr(thumbPath),
		PreviewPath: strPtr(previewPath),
		Hash:        fileInfo.Hash,
		SizeBytes:   fileInfo.SizeBytes,
		MimeType:    &mimeType,
		IsDeleted:   false,
		SyncCount:   0,
		GroupID:     nil,
	}

	return asset, nil
}

// batchWriter 批量写入数据库
func (p *Pipeline) batchWriter(ctx context.Context, resultChan <-chan *model.MediaAsset, doneChan chan<- struct{}, stats *Stats) {
	defer close(doneChan)

	batch := make([]*model.MediaAsset, 0, p.config.BatchSize)
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
			if len(batch) >= p.config.BatchSize {
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

// RunExecution 运行执行流水线（处理删除）
func (p *Pipeline) RunExecution(ctx context.Context) (*Stats, error) {
	log.Println("========== 开始执行流水线 ==========")

	stats := &Stats{}

	// 确保删除目录存在
	if err := os.MkdirAll(p.config.DeletedDir, 0755); err != nil {
		return nil, fmt.Errorf("创建删除目录失败: %w", err)
	}

	// 获取所有标记为删除的资产
	dbCtx, cancel := db.GetLongCtx()
	defer cancel()

	deletedAssets, err := p.repository.GetDeletedAssets(dbCtx)
	if err != nil {
		return nil, fmt.Errorf("获取删除资产失败: %w", err)
	}

	log.Printf("找到 %d 个待删除的资产", len(deletedAssets))

	// 处理每个删除的资产
	var deleteIDs []uuid.UUID
	for _, asset := range deletedAssets {
		select {
		case <-ctx.Done():
			return stats, ctx.Err()
		default:
		}

		// 获取被捆绑的资产
		groupedAssets, err := p.repository.GetGroupedAssets(dbCtx, asset.ID)
		if err != nil {
			log.Printf("获取捆绑资产失败: %v", err)
		}

		// 移动主资产文件
		if err := p.moveAssetToDeleted(asset); err != nil {
			log.Printf("移动资产文件失败: %v", err)
		} else {
			deleteIDs = append(deleteIDs, asset.ID)
			atomic.AddInt64(&stats.DeletedFiles, 1)
		}

		// 移动捆绑的资产文件
		for _, grouped := range groupedAssets {
			if err := p.moveAssetToDeleted(grouped); err != nil {
				log.Printf("移动捆绑资产文件失败: %v", err)
			} else {
				deleteIDs = append(deleteIDs, grouped.ID)
				atomic.AddInt64(&stats.DeletedFiles, 1)
			}
		}
	}

	// 批量删除数据库记录
	if len(deleteIDs) > 0 {
		if err := p.repository.BatchDeleteAssetRecords(dbCtx, deleteIDs); err != nil {
			log.Printf("删除数据库记录失败: %v", err)
		} else {
			log.Printf("删除数据库记录成功: %d 条", len(deleteIDs))
		}
	}

	// 清理空目录
	p.cleanEmptyDirs()

	log.Println("========== 执行流水线完成 ==========")
	log.Printf("删除文件数: %d", stats.DeletedFiles)

	return stats, nil
}

// moveAssetToDeleted 移动资产文件到删除目录，删除缩略图和预览图
func (p *Pipeline) moveAssetToDeleted(asset *model.MediaAsset) error {
	// 从 FilePath 中提取 yyyy-mm 目录（如 "2023-05/xxx.jpg" -> "2023-05"）
	yearMonth := filepath.Dir(asset.FilePath)
	if yearMonth == "." {
		yearMonth = "unknown"
	}

	// 确保目标目录存在
	trashDir := filepath.Join(p.config.DeletedDir, "trash", yearMonth)
	if err := os.MkdirAll(trashDir, 0755); err != nil {
		return fmt.Errorf("创建目标目录失败: %w", err)
	}

	// 生成唯一文件名（处理重名）
	originalFileName := filepath.Base(asset.FilePath)
	uniqueFileName := generateUniqueFileName(trashDir, originalFileName)

	// 移动原文件到 deletedDir/trash/yyyy-mm/
	srcMedia := filepath.Join(p.config.MediaDir, asset.FilePath)
	dstMedia := filepath.Join(trashDir, uniqueFileName)
	if err := moveFile(srcMedia, dstMedia); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("移动原文件失败: %w", err)
	}

	// 删除缩略图（不再移动）
	if asset.ThumbPath != nil && *asset.ThumbPath != "" {
		srcThumb := filepath.Join(p.config.ThumbsDir, *asset.ThumbPath)
		if err := os.Remove(srcThumb); err != nil && !os.IsNotExist(err) {
			log.Printf("删除缩略图失败: %v", err)
		}
	}

	// 删除预览图（不再移动）
	if asset.PreviewPath != nil && *asset.PreviewPath != "" {
		srcPreview := filepath.Join(p.config.PreviewDir, *asset.PreviewPath)
		if err := os.Remove(srcPreview); err != nil && !os.IsNotExist(err) {
			log.Printf("删除预览图失败: %v", err)
		}
	}

	return nil
}

// moveToDeleted 移动文件到删除目录（处理重名）
func (p *Pipeline) moveToDeleted(filePath string) error {
	duplicatesDir := filepath.Join(p.config.DeletedDir, "duplicates")
	if err := os.MkdirAll(duplicatesDir, 0755); err != nil {
		return fmt.Errorf("创建重复文件目录失败: %w", err)
	}

	originalFileName := filepath.Base(filePath)
	uniqueFileName := generateUniqueFileName(duplicatesDir, originalFileName)
	dst := filepath.Join(duplicatesDir, uniqueFileName)
	return moveFile(filePath, dst)
}

// cleanEmptyDirs 清理空目录
func (p *Pipeline) cleanEmptyDirs() {
	dirs := []string{p.config.MediaDir, p.config.ThumbsDir, p.config.PreviewDir}

	for _, dir := range dirs {
		p.cleanEmptyDirsRecursive(dir)
	}
}

// cleanEmptyDirsRecursive 递归清理空目录（从最深层开始）
func (p *Pipeline) cleanEmptyDirsRecursive(rootDir string) {
	// 收集所有子目录（按深度排序，先处理最深的）
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

// ensureDirectories 确保所有必需目录存在
func (p *Pipeline) ensureDirectories() error {
	dirs := []string{
		p.config.RawDir,
		p.config.MediaDir,
		p.config.ThumbsDir,
		p.config.PreviewDir,
		p.config.DeletedDir,
	}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("创建目录 %s 失败: %w", dir, err)
		}
	}
	return nil
}

// generateUniqueFileName 生成唯一文件名（全局函数，供多处复用）
func generateUniqueFileName(dir, originalName string) string {
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

// Pipeline.generateUniqueFileName 方法版本（向后兼容）
func (p *Pipeline) generateUniqueFileName(dir, originalName string) string {
	return generateUniqueFileName(dir, originalName)
}

// moveFile 移动文件
func moveFile(src, dst string) error {
	// 先尝试重命名（同一文件系统内最快）
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

	// 保留原文件权限
	srcInfo, err := os.Stat(src)
	if err == nil {
		os.Chmod(dst, srcInfo.Mode())
	}

	return os.Remove(src)
}

// moveFileWithDir 移动文件（自动创建目标目录）
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
