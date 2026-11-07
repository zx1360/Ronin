// Package pipeline 实现媒体文件的摄入和执行流水线
package pipeline

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"time"

	"github.com/google/uuid"

	"monarch/gizmos/internal/gallery/model"
	"monarch/gizmos/internal/gallery/processor"
	"monarch/gizmos/internal/gallery/repository"
	"monarch/gizmos/internal/gallery/scanner"
	"monarch/internal/galleryfs"
	"monarch/internal/service/db"
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
	EditedFiles    int64
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

// RunExecution 运行执行流水线
// Phase A: 处理软删除 → 文件移入 trash → 物理删除 DB 记录
// Phase B: 处理编辑 → 应用编辑 → 原文件移入 trash → 新文件写回 → 重建缩略图/预览图 → DB UPDATE
func (p *Pipeline) RunExecution(ctx context.Context, pruneMissing bool) (*Stats, error) {
	log.Println("========== 开始执行流水线 ==========")

	stats := &Stats{}

	// 确保目录存在
	if err := os.MkdirAll(p.config.DeletedDir, 0755); err != nil {
		return nil, fmt.Errorf("创建删除目录失败: %w", err)
	}

	// ========== Phase A: 处理删除 ==========
	log.Println("--- Phase A: 处理删除 ---")

	dbCtx, cancel := db.GetLongCtx()
	defer cancel()

	deletedAssets, err := p.repository.GetDeletedAssets(dbCtx)
	if err != nil {
		return nil, fmt.Errorf("获取删除资产失败: %w", err)
	}

	log.Printf("找到 %d 个待删除的资产", len(deletedAssets))

	var deleteIDs []uuid.UUID
	moved := make(map[uuid.UUID]bool)
	move := func(asset *model.MediaAsset) bool {
		if moved[asset.ID] {
			return true
		}
		if err := p.moveAssetToDeleted(asset, pruneMissing); err != nil {
			log.Printf("移动资产文件失败 [%s]: %v", asset.ID, err)
			stats.FailedFiles++
			return false
		}
		moved[asset.ID] = true
		deleteIDs = append(deleteIDs, asset.ID)
		return true
	}
	for _, asset := range deletedAssets {
		select {
		case <-ctx.Done():
			return stats, ctx.Err()
		default:
		}

		groupedAssets, err := p.repository.GetGroupedAssets(dbCtx, asset.ID)
		if err != nil {
			log.Printf("获取捆绑资产失败: %v", err)
			stats.FailedFiles++
			continue
		}
		groupMoved := true
		for _, grouped := range groupedAssets {
			if !move(grouped) {
				groupMoved = false
			}
		}
		if groupMoved {
			move(asset)
		}
	}

	if err := p.repository.BatchDeleteAssetRecords(dbCtx, deleteIDs); err != nil {
		return stats, fmt.Errorf("删除数据库记录失败，可重试: %w", err)
	}
	stats.DeletedFiles = int64(len(deleteIDs))

	// ========== Phase B: 处理编辑 ==========
	log.Println("--- Phase B: 处理编辑 ---")

	editedAssets, err := p.repository.GetEditedAssets(dbCtx)
	if err != nil {
		return stats, fmt.Errorf("获取编辑资产失败: %w", err)
	} else {
		log.Printf("找到 %d 个待编辑的资产", len(editedAssets))

		for _, asset := range editedAssets {
			select {
			case <-ctx.Done():
				return stats, ctx.Err()
			default:
			}

			if err := p.processEditedAsset(ctx, asset); err != nil {
				log.Printf("处理编辑资产失败 [%s]: %v", asset.ID, err)
				atomic.AddInt64(&stats.FailedFiles, 1)
			} else {
				atomic.AddInt64(&stats.EditedFiles, 1)
				log.Printf("编辑处理完成: %s", asset.FilePath)
			}
		}
	}

	// 清理空目录
	p.cleanEmptyDirs()
	if stats.FailedFiles > 0 {
		return stats, fmt.Errorf("%d 项未能完成，请查看任务日志", stats.FailedFiles)
	}

	log.Println("========== 执行流水线完成 ==========")
	log.Printf("删除文件数: %d", stats.DeletedFiles)
	log.Printf("编辑文件数: %d", stats.EditedFiles)

	return stats, nil
}

// processEditedAsset 处理单个编辑资产
func (p *Pipeline) processEditedAsset(ctx context.Context, asset *model.MediaAsset) (err error) {
	if asset.EditParams == nil {
		return fmt.Errorf("编辑参数为空")
	}

	log.Printf("处理编辑: %s (edit_params=%s)", asset.FilePath, *asset.EditParams)

	// 确定编辑类型
	var editType struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal([]byte(*asset.EditParams), &editType); err != nil {
		return fmt.Errorf("解析编辑类型失败: %w", err)
	}

	// 源文件路径
	srcPath := filepath.Join(p.config.MediaDir, asset.FilePath)

	// 生成临时文件路径
	ext := filepath.Ext(asset.FilePath)
	tmpPath := filepath.Join(os.TempDir(), fmt.Sprintf("gallery_edit_%s%s", asset.ID.String(), ext))
	defer os.Remove(tmpPath)

	// 应用编辑到临时文件
	var editErr error
	switch editType.Type {
	case "image":
		editErr = processor.ApplyImageEdit(srcPath, tmpPath, *asset.EditParams)
	case "video":
		editErr = processor.ApplyVideoEdit(srcPath, tmpPath, *asset.EditParams)
	default:
		return fmt.Errorf("未知编辑类型: %s", editType.Type)
	}

	// 无操作编辑（如旋转 0°+全幅裁切、剪辑全片）：不搬移文件，仅清除 edit_params
	if errors.Is(editErr, processor.ErrNoOp) {
		log.Printf("编辑参数为无操作，清除 edit_params: %s", asset.FilePath)
		dbCtx, dbCancel := db.GetDefaultCtx()
		defer dbCancel()
		if err := p.repository.ClearEditParams(dbCtx, asset.ID); err != nil {
			return fmt.Errorf("清除 edit_params 失败: %w", err)
		}
		return nil
	}
	if editErr != nil {
		return fmt.Errorf("%s 编辑失败: %w", editType.Type, editErr)
	}

	// 移动原文件到 trash
	yearMonth := filepath.Dir(asset.FilePath)
	if yearMonth == "." {
		yearMonth = "unknown"
	}
	trashDir := filepath.Join(p.config.DeletedDir, "trash", yearMonth)
	if err := os.MkdirAll(trashDir, 0755); err != nil {
		return fmt.Errorf("创建 trash 目录失败: %w", err)
	}
	originalFileName := filepath.Base(asset.FilePath)
	trashFileName := generateUniqueFileName(trashDir, originalFileName)
	trashPath := filepath.Join(trashDir, trashFileName)
	if err := moveFile(srcPath, trashPath); err != nil {
		return fmt.Errorf("移动原文件到 trash 失败: %w", err)
	}
	log.Printf("原文件已移入 trash: %s", trashPath)
	original := *asset
	defer func() {
		if err == nil {
			return
		}
		*asset = original
		if restoreErr := copyFileData(trashPath, srcPath); restoreErr != nil {
			err = errors.Join(err, fmt.Errorf("原文件恢复失败，备份在 %s: %w", trashPath, restoreErr))
			return
		}
		_, restoreErr := p.processor.Process(&model.FileInfo{
			FileName: filepath.Base(asset.FilePath), Extension: strings.ToLower(ext),
			IsVideo: model.IsVideo(strings.ToLower(ext)), IsAnimated: model.IsAnimatedImage(strings.ToLower(ext)),
		}, srcPath, yearMonth)
		if restoreErr != nil {
			err = errors.Join(err, fmt.Errorf("原图已恢复，派生图重建失败: %w", restoreErr))
		}
	}()

	// 将编辑后的文件复制到原路径（不使用 moveFile 避免跨盘/句柄锁定问题）
	if err := copyFileData(tmpPath, srcPath); err != nil {
		return fmt.Errorf("新文件写回失败: %w", err)
	}
	// 重新计算 hash
	newHash, err := galleryfs.HashFile(srcPath)
	if err != nil {
		return fmt.Errorf("计算新 hash 失败: %w", err)
	}

	// 获取新文件大小
	newInfo, err := os.Stat(srcPath)
	if err != nil {
		return fmt.Errorf("获取新文件信息失败: %w", err)
	}
	newSize := newInfo.Size()

	// 确定新的 MIME type
	baseName := filepath.Base(asset.FilePath)
	extLower := strings.ToLower(filepath.Ext(baseName))
	newMime := model.GetMimeType(extLower)

	// 先删除旧的缩略图和预览图文件
	if asset.ThumbPath != nil && *asset.ThumbPath != "" {
		oldThumb := filepath.Join(p.config.ThumbsDir, *asset.ThumbPath)
		if err := os.Remove(oldThumb); err != nil && !os.IsNotExist(err) {
			log.Printf("删除旧缩略图失败: %v", err)
		}
	}
	if asset.PreviewPath != nil && *asset.PreviewPath != "" {
		oldPreview := filepath.Join(p.config.PreviewDir, *asset.PreviewPath)
		if err := os.Remove(oldPreview); err != nil && !os.IsNotExist(err) {
			log.Printf("删除旧预览图失败: %v", err)
		}
	}

	// 重建缩略图和预览图
	fileInfo := &model.FileInfo{
		FileName:   baseName,
		Extension:  extLower,
		IsVideo:    model.IsVideo(extLower),
		IsAnimated: model.IsAnimatedImage(extLower),
	}
	processResult, err := p.processor.Process(fileInfo, srcPath, yearMonth)
	if err != nil {
		return fmt.Errorf("重建缩略图/预览图失败: %w", err)
	} else {
		log.Printf("缩略图已重建: %s", processResult.ThumbPath)
		log.Printf("预览图已重建: %s", processResult.PreviewPath)
	}

	// 更新 asset 并写入数据库
	now := time.Now()
	asset.UpdatedAt = now
	asset.Hash = newHash
	asset.SizeBytes = newSize
	asset.MimeType = &newMime
	if processResult.ThumbPath != "" {
		asset.ThumbPath = strPtr(processResult.ThumbPath)
	}
	if processResult.PreviewPath != "" {
		asset.PreviewPath = strPtr(processResult.PreviewPath)
	}

	dbCtx, dbCancel := db.GetDefaultCtx()
	defer dbCancel()

	if err := p.repository.UpdateAssetAfterEdit(dbCtx, asset); err != nil {
		return fmt.Errorf("更新数据库失败: %w", err)
	}

	return nil
}

// moveAssetToDeleted 移动资产文件到删除目录，删除缩略图和预览图
func (p *Pipeline) moveAssetToDeleted(asset *model.MediaAsset, pruneMissing bool) error {
	relative, ok := galleryfs.RelativePath(asset.FilePath)
	if !ok {
		return fmt.Errorf("原件路径无效: %q", asset.FilePath)
	}
	yearMonth := filepath.Dir(relative)
	if yearMonth == "." {
		yearMonth = "unknown"
	}

	// 路径含资产 ID，中断后可确认原件已进入回收目录。
	trashDir := filepath.Join(p.config.DeletedDir, "trash", yearMonth, asset.ID.String())
	srcMedia := filepath.Join(p.config.MediaDir, relative)
	dstMedia := filepath.Join(trashDir, filepath.Base(relative))
	if info, err := os.Stat(srcMedia); os.IsNotExist(err) {
		trashed, err := os.Stat(dstMedia)
		switch {
		case err == nil && trashed.Mode().IsRegular():
		case os.IsNotExist(err) && pruneMissing:
			log.Printf("按显式选项清理缺失原件记录: %q", relative)
		default:
			return fmt.Errorf("找不到原件或对应回收文件: %q", relative)
		}
	} else {
		if err != nil || !info.Mode().IsRegular() {
			return fmt.Errorf("原件不可用: %q (%v)", relative, err)
		}
		if err := os.MkdirAll(trashDir, 0755); err != nil {
			return fmt.Errorf("创建回收目录失败: %w", err)
		}
		if err := moveFile(srcMedia, dstMedia); err != nil {
			return fmt.Errorf("移动原件失败: %w", err)
		}
	}

	for _, derived := range []struct {
		dir  string
		path *string
	}{{p.config.ThumbsDir, asset.ThumbPath}, {p.config.PreviewDir, asset.PreviewPath}} {
		if derived.path == nil {
			continue
		}
		rel, ok := galleryfs.RelativePath(*derived.path)
		if !ok {
			continue
		}
		if err := os.Remove(filepath.Join(derived.dir, rel)); err != nil && !os.IsNotExist(err) {
			log.Printf("删除派生图失败: %v", err)
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
	for _, dir := range []string{p.config.MediaDir, p.config.ThumbsDir, p.config.PreviewDir} {
		p.cleanEmptyDirsRecursive(dir)
	}
}

// cleanEmptyDirsRecursive 递归清理空目录（自最深一层向上）
func (p *Pipeline) cleanEmptyDirsRecursive(rootDir string) {
	var dirs []string
	_ = filepath.WalkDir(rootDir, func(path string, d os.DirEntry, err error) error {
		if err == nil && d.IsDir() && path != rootDir {
			dirs = append(dirs, path)
		}
		return nil
	})

	// WalkDir 是深度优先，父目录必然排在子目录之后，倒序即"先子后父"
	for i := len(dirs) - 1; i >= 0; i-- {
		dir := dirs[i]
		entries, err := os.ReadDir(dir)
		if err != nil || len(entries) > 0 {
			continue
		}
		if err := os.Remove(dir); err == nil {
			log.Printf("清理空目录: %s", dir)
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

// generateUniqueFileName 在 dir 下生成不冲突的文件名（重名时追加 _1、_2…）
func generateUniqueFileName(dir, originalName string) string {
	ext := filepath.Ext(originalName)
	baseName := strings.TrimSuffix(originalName, ext)

	name := originalName
	for counter := 1; ; counter++ {
		if _, err := os.Stat(filepath.Join(dir, name)); os.IsNotExist(err) {
			return name
		}
		name = fmt.Sprintf("%s_%d%s", baseName, counter, ext)
	}
}

// moveFile 移动文件：优先用 rename（同一文件系统内最快），跨盘时退化为复制后删除。
func moveFile(src, dst string) error {
	if err := os.Rename(src, dst); err == nil {
		return nil
	}

	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	if _, err := dstFile.ReadFrom(srcFile); err != nil {
		dstFile.Close()
		return err
	}
	// 必须先关闭再删除源文件：否则目标可能尚未落盘就丢失了源数据
	if err := dstFile.Close(); err != nil {
		return err
	}

	if srcInfo, err := os.Stat(src); err == nil {
		_ = os.Chmod(dst, srcInfo.Mode())
	}
	return os.Remove(src)
}

// strPtr 字符串指针辅助函数（空串视为 nil）
func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// copyFileData 流式复制文件（用于编辑结果写回，避免把整个文件读入内存）
func copyFileData(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("读取源文件失败: %w", err)
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("写入目标文件失败: %w", err)
	}
	if _, err := io.Copy(dstFile, srcFile); err != nil {
		dstFile.Close()
		return fmt.Errorf("写入目标文件失败: %w", err)
	}
	return dstFile.Close()
}
