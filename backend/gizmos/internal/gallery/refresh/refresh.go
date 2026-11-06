// Package refresh 重建画廊的缩略图和预览图。
package refresh

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"

	"monarch/gizmos/internal/gallery/model"
	"monarch/gizmos/internal/gallery/processor"
	"monarch/gizmos/internal/gallery/repository"
	"monarch/internal/galleryfs"
)

// Config refresh 模式配置。
type Config struct {
	MediaDir      string
	ThumbsDir     string
	PreviewDir    string
	Concurrency   int
	Resize        int
	ResizePreview int
	ResizeThumb   int
}

// Stats refresh 统计信息。
type Stats struct {
	TotalRecords   int64
	MissingSources int64
	Thumbnails     int64
	Previews       int64
	FailedRecords  int64
}

// sizePlan 派生图尺寸计划。
type sizePlan struct {
	runResizeThumb   bool
	runResizePreview bool
	thumbSize        int
	previewSize      int
}

// regenerateRequest 单个资产的派生图生成意图。
type regenerateRequest struct {
	needThumb   bool
	needPreview bool
}

// Refresher refresh 执行器。
type Refresher struct {
	config     Config
	sizePlan   sizePlan
	repository *repository.Repository
}

// NewRefresher 创建 refresh 执行器。
func NewRefresher(cfg Config) (*Refresher, error) {
	if cfg.Concurrency <= 0 {
		cfg.Concurrency = 4
	}
	if cfg.MediaDir == "" || cfg.ThumbsDir == "" || cfg.PreviewDir == "" {
		return nil, fmt.Errorf("refresh 路径配置不完整")
	}

	plan, err := buildSizePlan(cfg.Resize, cfg.ResizePreview, cfg.ResizeThumb)
	if err != nil {
		return nil, err
	}

	return &Refresher{
		config:     cfg,
		sizePlan:   plan,
		repository: repository.NewRepository(),
	}, nil
}

func (r *Refresher) Run(ctx context.Context) (*Stats, error) {
	assets, err := r.repository.GetActiveAssets(ctx)
	if err != nil {
		return nil, fmt.Errorf("读取媒体记录失败: %w", err)
	}
	stats := &Stats{TotalRecords: int64(len(assets))}
	jobs := make(chan *model.MediaAsset)
	var workers sync.WaitGroup
	for range r.config.Concurrency {
		workers.Go(func() {
			for asset := range jobs {
				if ctx.Err() != nil {
					return
				}
				r.refreshAsset(ctx, asset, stats)
			}
		})
	}

send:
	for _, asset := range assets {
		select {
		case jobs <- asset:
		case <-ctx.Done():
			break send
		}
	}
	close(jobs)
	workers.Wait()

	if err := ctx.Err(); err != nil {
		return stats, err
	}
	if stats.FailedRecords > 0 {
		return stats, fmt.Errorf("%d 条媒体的派生图处理失败", stats.FailedRecords)
	}
	return stats, nil
}

func (r *Refresher) refreshAsset(ctx context.Context, asset *model.MediaAsset, stats *Stats) {
	relative, ok := galleryfs.RelativePath(asset.FilePath)
	if !ok {
		log.Printf("源路径无效，已保留记录: %q", asset.FilePath)
		atomic.AddInt64(&stats.MissingSources, 1)
		return
	}
	source := filepath.Join(r.config.MediaDir, relative)
	info, err := os.Stat(source)
	if err != nil || !info.Mode().IsRegular() {
		log.Printf("原件不可用，已保留记录: %q (%v)", asset.FilePath, err)
		atomic.AddInt64(&stats.MissingSources, 1)
		return
	}
	req := regenerateRequest{
		needThumb:   r.sizePlan.runResizeThumb || derivedMissing(r.config.ThumbsDir, asset.ThumbPath),
		needPreview: r.sizePlan.runResizePreview || derivedMissing(r.config.PreviewDir, asset.PreviewPath),
	}
	if !req.needThumb && !req.needPreview {
		return
	}
	if err := r.regenerateAsset(ctx, asset, relative, source, req); err != nil {
		log.Printf("派生图处理失败: %q (%v)", asset.FilePath, err)
		atomic.AddInt64(&stats.FailedRecords, 1)
		return
	}
	if req.needThumb {
		atomic.AddInt64(&stats.Thumbnails, 1)
	}
	if req.needPreview {
		atomic.AddInt64(&stats.Previews, 1)
	}
}

func derivedMissing(baseDir string, relPath *string) bool {
	if relPath == nil || strings.TrimSpace(*relPath) == "" {
		return true
	}
	relative, ok := galleryfs.RelativePath(*relPath)
	if !ok {
		return true
	}
	_, err := os.Stat(filepath.Join(baseDir, relative))
	return err != nil
}

func (r *Refresher) regenerateAsset(ctx context.Context, asset *model.MediaAsset, relSource, sourcePath string, req regenerateRequest) error {
	ext := strings.ToLower(filepath.Ext(relSource))
	baseName := strings.TrimSuffix(filepath.Base(relSource), filepath.Ext(relSource))
	yearMonth := filepath.Dir(relSource)
	if yearMonth == "." {
		yearMonth = ""
	}

	// GIF 保持动态格式，其余统一 jpg
	derivedExt := ".jpg"
	isGIF := ext == ".gif"
	if isGIF {
		derivedExt = ".gif"
	}

	thumbRel := joinRelative(yearMonth, baseName+"_thumb"+derivedExt)
	previewRel := joinRelative(yearMonth, baseName+"_preview"+derivedExt)
	thumbFullPath := filepath.Join(r.config.ThumbsDir, thumbRel)
	previewFullPath := filepath.Join(r.config.PreviewDir, previewRel)

	if req.needThumb {
		if err := os.MkdirAll(filepath.Dir(thumbFullPath), 0755); err != nil {
			return fmt.Errorf("创建缩略图目录失败: %w", err)
		}
	}
	if req.needPreview {
		if err := os.MkdirAll(filepath.Dir(previewFullPath), 0755); err != nil {
			return fmt.Errorf("创建预览图目录失败: %w", err)
		}
	}

	err := processor.Generate(sourcePath, thumbFullPath, previewFullPath, processor.GenerateRequest{
		NeedThumb:   req.needThumb,
		NeedPreview: req.needPreview,
		ThumbSize:   r.sizePlan.thumbSize,
		PreviewSize: r.sizePlan.previewSize,
	}, model.IsVideo(ext), isGIF)
	if err != nil {
		return err
	}

	if req.needThumb {
		asset.ThumbPath = strPtr(thumbRel)
	}
	if req.needPreview {
		asset.PreviewPath = strPtr(previewRel)
	}

	return r.repository.UpdateDerivatives(ctx, asset)
}

// buildSizePlan 把三个 --resize* 参数折算为"是否重建 + 目标尺寸"。
func buildSizePlan(resize, resizePreview, resizeThumb int) (sizePlan, error) {
	if resize < 0 || resizePreview < 0 || resizeThumb < 0 {
		return sizePlan{}, fmt.Errorf("resize/resizePreview/resizeThumb 不能为负数")
	}

	plan := sizePlan{
		thumbSize:   processor.ThumbSize,
		previewSize: processor.PreviewSize,
	}

	// --resize 同时作用于缩略图与预览图，随后可被单独参数覆盖
	if resize > 0 {
		plan.runResizeThumb = true
		plan.runResizePreview = true
		plan.thumbSize = resize
		plan.previewSize = resize
	}
	if resizeThumb > 0 {
		plan.runResizeThumb = true
		plan.thumbSize = resizeThumb
	}
	if resizePreview > 0 {
		plan.runResizePreview = true
		plan.previewSize = resizePreview
	}

	return plan, nil
}

func joinRelative(dirPart, fileName string) string {
	if dirPart == "" || dirPart == "." {
		return fileName
	}
	return filepath.Join(dirPart, fileName)
}

func strPtr(s string) *string {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	v := s
	return &v
}
