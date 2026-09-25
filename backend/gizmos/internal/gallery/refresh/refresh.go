// Package refresh 实现 gallery refresh 模式：
//  1. 清理 file_path 为空或源文件缺失的记录并删除派生文件；
//  2. 可选按指定尺寸重建缩略图/预览图；
//  3. 修复缺失的缩略图/预览图并更新数据库。
package refresh

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"

	"gizmos/internal/gallery/model"
	"gizmos/internal/gallery/processor"
	"gizmos/internal/gallery/repository"
)

var (
	errInvalidSourcePath = errors.New("invalid source path")
	errSourceNotFound    = errors.New("source file not found")
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
	TotalRecords              int64
	Step1InvalidSourceRecords int64
	Step1DeletedRecords       int64
	Step1DeleteFailedRecords  int64
	Step2ResizeCandidates     int64
	Step2ResizedThumbFiles    int64
	Step2ResizedPreviewFiles  int64
	Step2FailedRecords        int64
	Step3MissingCandidates    int64
	Step3FixedRecords         int64
	Step3FailedRecords        int64
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

// Run 执行 refresh 三步流程。
func (r *Refresher) Run(ctx context.Context) (*Stats, error) {
	stats := &Stats{}

	log.Println("========== 开始 refresh 流程 ==========")
	log.Printf("媒体目录: %s", r.config.MediaDir)
	log.Printf("缩略图目录: %s", r.config.ThumbsDir)
	log.Printf("预览图目录: %s", r.config.PreviewDir)
	log.Printf("并发数: %d", r.config.Concurrency)
	if r.sizePlan.runResizeThumb || r.sizePlan.runResizePreview {
		log.Printf("尺寸重建启用: thumb=%v(%d), preview=%v(%d)",
			r.sizePlan.runResizeThumb, r.sizePlan.thumbSize,
			r.sizePlan.runResizePreview, r.sizePlan.previewSize)
	} else {
		log.Println("尺寸重建未启用 (未提供 resize/resizePreview/resizeThumb)")
	}

	for _, step := range []func(context.Context, *Stats) error{
		r.step1CleanupInvalidSources,
		r.step2OptionalResize,
		r.step3FixMissingDerivatives,
	} {
		if err := step(ctx, stats); err != nil {
			return stats, err
		}
	}

	log.Println("========== refresh 流程完成 ==========")
	return stats, nil
}

// step1CleanupInvalidSources 删除路径非法或源文件缺失的记录及其派生文件。
func (r *Refresher) step1CleanupInvalidSources(ctx context.Context, stats *Stats) error {
	assets, err := r.repository.GetAllAssets(ctx)
	if err != nil {
		return fmt.Errorf("步骤1查询媒体记录失败: %w", err)
	}
	stats.TotalRecords = int64(len(assets))

	for _, asset := range assets {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		// 路径非法或源文件确实不存在时才判定为无效记录
		srcPath, ok := resolveRelativePath(r.config.MediaDir, asset.FilePath)
		if ok {
			if _, statErr := os.Stat(srcPath); statErr == nil {
				continue
			} else if !os.IsNotExist(statErr) {
				log.Printf("[Step1] 跳过记录: 源文件检查失败(非不存在错误): id=%s, file_path=%q, err=%v",
					asset.ID, asset.FilePath, statErr)
				continue
			}
		}

		atomic.AddInt64(&stats.Step1InvalidSourceRecords, 1)
		if delErr := r.deleteAssetRecordAndDerivatives(ctx, asset); delErr != nil {
			atomic.AddInt64(&stats.Step1DeleteFailedRecords, 1)
			log.Printf("[Step1] 删除无效记录失败: id=%s, file_path=%q, err=%v", asset.ID, asset.FilePath, delErr)
			continue
		}
		atomic.AddInt64(&stats.Step1DeletedRecords, 1)
	}
	return nil
}

// step2OptionalResize 按指定尺寸重建全部活跃资产的派生图。
func (r *Refresher) step2OptionalResize(ctx context.Context, stats *Stats) error {
	if !r.sizePlan.runResizeThumb && !r.sizePlan.runResizePreview {
		return nil
	}

	assets, err := r.repository.GetActiveAssets(ctx)
	if err != nil {
		return fmt.Errorf("步骤2查询活跃媒体记录失败: %w", err)
	}
	stats.Step2ResizeCandidates = int64(len(assets))

	r.runWorkers(ctx, assets, "Step2", stats, func(asset *model.MediaAsset) (regenerateRequest, bool) {
		return regenerateRequest{
			needThumb:   r.sizePlan.runResizeThumb,
			needPreview: r.sizePlan.runResizePreview,
		}, true
	}, func(result regenerateResult) {
		if result.thumbGenerated {
			atomic.AddInt64(&stats.Step2ResizedThumbFiles, 1)
		}
		if result.previewGenerated {
			atomic.AddInt64(&stats.Step2ResizedPreviewFiles, 1)
		}
	}, func() { atomic.AddInt64(&stats.Step2FailedRecords, 1) })

	if ctx.Err() != nil {
		return ctx.Err()
	}
	return nil
}

// step3FixMissingDerivatives 只补齐缺失的缩略图/预览图。
func (r *Refresher) step3FixMissingDerivatives(ctx context.Context, stats *Stats) error {
	assets, err := r.repository.GetActiveAssets(ctx)
	if err != nil {
		return fmt.Errorf("步骤3查询活跃媒体记录失败: %w", err)
	}

	r.runWorkers(ctx, assets, "Step3", stats, func(asset *model.MediaAsset) (regenerateRequest, bool) {
		req := regenerateRequest{
			needThumb:   r.isThumbMissing(asset),
			needPreview: r.isPreviewMissing(asset),
		}
		if !req.needThumb && !req.needPreview {
			return req, false
		}
		atomic.AddInt64(&stats.Step3MissingCandidates, 1)
		return req, true
	}, func(result regenerateResult) {
		if result.thumbGenerated || result.previewGenerated {
			atomic.AddInt64(&stats.Step3FixedRecords, 1)
		}
	}, func() { atomic.AddInt64(&stats.Step3FailedRecords, 1) })

	if ctx.Err() != nil {
		return ctx.Err()
	}
	return nil
}

// regenerateResult 实际生成了哪些派生图。
type regenerateResult struct {
	thumbGenerated   bool
	previewGenerated bool
}

// runWorkers 以固定并发度处理资产；plan 返回 false 表示跳过该资产。
// onFailure 用于累计调用方各自的失败计数，日志前缀由 step 决定。
func (r *Refresher) runWorkers(
	ctx context.Context,
	assets []*model.MediaAsset,
	step string,
	stats *Stats,
	plan func(*model.MediaAsset) (regenerateRequest, bool),
	onSuccess func(regenerateResult),
	onFailure func(),
) {
	if len(assets) == 0 {
		return
	}

	taskChan := make(chan *model.MediaAsset, r.config.Concurrency*2)
	var wg sync.WaitGroup

	for i := 0; i < r.config.Concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for asset := range taskChan {
				if ctx.Err() != nil {
					return
				}

				req, ok := plan(asset)
				if !ok {
					continue
				}
				result, err := r.regenerateAsset(ctx, asset, req)
				if err != nil {
					// 源文件已不可用时清理记录，不再计入本步失败
					if errors.Is(err, errInvalidSourcePath) || errors.Is(err, errSourceNotFound) {
						if delErr := r.deleteAssetRecordAndDerivatives(ctx, asset); delErr != nil {
							log.Printf("[%s][Worker %d] 删除无效记录失败: id=%s, err=%v", step, workerID, asset.ID, delErr)
							onFailure()
							continue
						}
						atomic.AddInt64(&stats.Step1InvalidSourceRecords, 1)
						atomic.AddInt64(&stats.Step1DeletedRecords, 1)
						continue
					}
					log.Printf("[%s][Worker %d] 处理失败: id=%s, file_path=%q, err=%v",
						step, workerID, asset.ID, asset.FilePath, err)
					onFailure()
					continue
				}
				onSuccess(*result)
			}
		}(i)
	}

sendLoop:
	for _, asset := range assets {
		select {
		case <-ctx.Done():
			break sendLoop
		case taskChan <- asset:
		}
	}
	close(taskChan)
	wg.Wait()
}

// deleteAssetRecordAndDerivatives 删除派生文件与数据库记录。
func (r *Refresher) deleteAssetRecordAndDerivatives(ctx context.Context, asset *model.MediaAsset) error {
	r.removeDerivedFile(r.config.ThumbsDir, asset.ThumbPath)
	r.removeDerivedFile(r.config.PreviewDir, asset.PreviewPath)
	if err := r.repository.DeleteAssetRecord(ctx, asset.ID); err != nil {
		return fmt.Errorf("删除数据库记录失败: %w", err)
	}
	return nil
}

func (r *Refresher) removeDerivedFile(baseDir string, relPath *string) {
	if relPath == nil {
		return
	}
	fullPath, ok := resolveRelativePath(baseDir, *relPath)
	if !ok {
		return
	}
	if err := os.Remove(fullPath); err != nil && !os.IsNotExist(err) {
		log.Printf("删除派生文件失败: %s, err=%v", fullPath, err)
	}
}

func (r *Refresher) isThumbMissing(asset *model.MediaAsset) bool {
	return derivedMissing(r.config.ThumbsDir, asset.ThumbPath)
}

func (r *Refresher) isPreviewMissing(asset *model.MediaAsset) bool {
	return derivedMissing(r.config.PreviewDir, asset.PreviewPath)
}

// derivedMissing 报告派生文件是否缺失（路径为空或非法同样视为缺失）。
func derivedMissing(baseDir string, relPath *string) bool {
	if relPath == nil || strings.TrimSpace(*relPath) == "" {
		return true
	}
	fullPath, ok := resolveRelativePath(baseDir, *relPath)
	if !ok {
		return true
	}
	_, err := os.Stat(fullPath)
	return err != nil
}

// regenerateAsset 重建单个资产的派生图并回写数据库。
func (r *Refresher) regenerateAsset(ctx context.Context, asset *model.MediaAsset, req regenerateRequest) (*regenerateResult, error) {
	if !req.needThumb && !req.needPreview {
		return &regenerateResult{}, nil
	}

	sourcePath, ok := resolveRelativePath(r.config.MediaDir, asset.FilePath)
	if !ok {
		return nil, errInvalidSourcePath
	}
	if _, err := os.Stat(sourcePath); err != nil {
		if os.IsNotExist(err) {
			return nil, errSourceNotFound
		}
		return nil, fmt.Errorf("访问源文件失败: %w", err)
	}

	relSource := normalizeRelativePath(asset.FilePath)
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
			return nil, fmt.Errorf("创建缩略图目录失败: %w", err)
		}
	}
	if req.needPreview {
		if err := os.MkdirAll(filepath.Dir(previewFullPath), 0755); err != nil {
			return nil, fmt.Errorf("创建预览图目录失败: %w", err)
		}
	}

	err := processor.Generate(sourcePath, thumbFullPath, previewFullPath, processor.GenerateRequest{
		NeedThumb:   req.needThumb,
		NeedPreview: req.needPreview,
		ThumbSize:   r.sizePlan.thumbSize,
		PreviewSize: r.sizePlan.previewSize,
	}, model.IsVideo(ext), isGIF)
	if err != nil {
		return nil, err
	}

	if req.needThumb {
		asset.ThumbPath = strPtr(thumbRel)
	}
	if req.needPreview {
		asset.PreviewPath = strPtr(previewRel)
	}

	if err := r.repository.UpdateMediaAssetFull(ctx, asset); err != nil {
		return nil, fmt.Errorf("更新数据库失败: %w", err)
	}

	return &regenerateResult{
		thumbGenerated:   req.needThumb,
		previewGenerated: req.needPreview,
	}, nil
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

// resolveRelativePath 把相对路径安全地解析到 baseDir 下，拒绝越界路径。
func resolveRelativePath(baseDir, relPath string) (string, bool) {
	normalized := normalizeRelativePath(relPath)
	if normalized == "" || filepath.IsAbs(normalized) {
		return "", false
	}
	if normalized == "." || normalized == ".." ||
		strings.HasPrefix(normalized, ".."+string(filepath.Separator)) {
		return "", false
	}
	return filepath.Join(baseDir, normalized), true
}

func normalizeRelativePath(p string) string {
	trimmed := strings.TrimSpace(p)
	if trimmed == "" {
		return ""
	}
	return filepath.Clean(filepath.FromSlash(trimmed))
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
