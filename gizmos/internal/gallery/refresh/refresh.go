// Package refresh 实现 gallery refresh 模式：
// 1) 清理 file_path 为空或源文件缺失的记录并删除派生文件；
// 2) 可选按输入尺寸重建缩略图/预览图；
// 3) 修复缺失的缩略图/预览图并更新数据库。
package refresh

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"image"
	"image/gif"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/disintegration/imaging"
	_ "golang.org/x/image/webp"

	"gizmos/internal/gallery/model"
	"gizmos/internal/gallery/repository"
)

const (
	defaultThumbSize   = 256
	defaultPreviewSize = 256
	jpegQuality        = 85
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

type sizePlan struct {
	runResizeThumb   bool
	runResizePreview bool
	thumbSize        int
	previewSize      int
}

type regenerateRequest struct {
	needThumb   bool
	needPreview bool
	thumbSize   int
	previewSize int
}

type regenerateResult struct {
	thumbGenerated   bool
	previewGenerated bool
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

	if err := r.step1CleanupInvalidSources(ctx, stats); err != nil {
		return stats, err
	}

	if err := r.step2OptionalResize(ctx, stats); err != nil {
		return stats, err
	}

	if err := r.step3FixMissingDerivatives(ctx, stats); err != nil {
		return stats, err
	}

	log.Println("========== refresh 流程完成 ==========")
	return stats, nil
}

func (r *Refresher) step1CleanupInvalidSources(ctx context.Context, stats *Stats) error {
	assets, err := r.repository.GetAllAssets(ctx)
	if err != nil {
		return fmt.Errorf("步骤1查询媒体记录失败: %w", err)
	}

	stats.TotalRecords = int64(len(assets))

	for _, asset := range assets {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		srcPath, ok := resolveRelativePath(r.config.MediaDir, asset.FilePath)
		if ok {
			if _, statErr := os.Stat(srcPath); statErr == nil {
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

func (r *Refresher) step2OptionalResize(ctx context.Context, stats *Stats) error {
	if !r.sizePlan.runResizeThumb && !r.sizePlan.runResizePreview {
		return nil
	}

	assets, err := r.repository.GetActiveAssets(ctx)
	if err != nil {
		return fmt.Errorf("步骤2查询活跃媒体记录失败: %w", err)
	}

	stats.Step2ResizeCandidates = int64(len(assets))
	if len(assets) == 0 {
		return nil
	}

	taskChan := make(chan *model.MediaAsset, r.config.Concurrency*2)
	var wg sync.WaitGroup

	for i := 0; i < r.config.Concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for asset := range taskChan {
				select {
				case <-ctx.Done():
					return
				default:
				}

				res, regenErr := r.regenerateAsset(ctx, asset, regenerateRequest{
					needThumb:   r.sizePlan.runResizeThumb,
					needPreview: r.sizePlan.runResizePreview,
					thumbSize:   r.sizePlan.thumbSize,
					previewSize: r.sizePlan.previewSize,
				})
				if regenErr != nil {
					if errors.Is(regenErr, errInvalidSourcePath) || errors.Is(regenErr, errSourceNotFound) {
						if delErr := r.deleteAssetRecordAndDerivatives(ctx, asset); delErr != nil {
							log.Printf("[Step2][Worker %d] 删除无效记录失败: id=%s, err=%v", workerID, asset.ID, delErr)
							atomic.AddInt64(&stats.Step2FailedRecords, 1)
							continue
						}
						atomic.AddInt64(&stats.Step1InvalidSourceRecords, 1)
						atomic.AddInt64(&stats.Step1DeletedRecords, 1)
						continue
					}

					atomic.AddInt64(&stats.Step2FailedRecords, 1)
					log.Printf("[Step2][Worker %d] 重建失败: id=%s, file_path=%q, err=%v", workerID, asset.ID, asset.FilePath, regenErr)
					continue
				}

				if res.thumbGenerated {
					atomic.AddInt64(&stats.Step2ResizedThumbFiles, 1)
				}
				if res.previewGenerated {
					atomic.AddInt64(&stats.Step2ResizedPreviewFiles, 1)
				}
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

	if ctx.Err() != nil {
		return ctx.Err()
	}
	return nil
}

func (r *Refresher) step3FixMissingDerivatives(ctx context.Context, stats *Stats) error {
	assets, err := r.repository.GetActiveAssets(ctx)
	if err != nil {
		return fmt.Errorf("步骤3查询活跃媒体记录失败: %w", err)
	}
	if len(assets) == 0 {
		return nil
	}

	taskChan := make(chan *model.MediaAsset, r.config.Concurrency*2)
	var wg sync.WaitGroup

	for i := 0; i < r.config.Concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for asset := range taskChan {
				select {
				case <-ctx.Done():
					return
				default:
				}

				needThumb := r.isThumbMissing(asset)
				needPreview := r.isPreviewMissing(asset)
				if !needThumb && !needPreview {
					continue
				}
				atomic.AddInt64(&stats.Step3MissingCandidates, 1)

				res, regenErr := r.regenerateAsset(ctx, asset, regenerateRequest{
					needThumb:   needThumb,
					needPreview: needPreview,
					thumbSize:   r.sizePlan.thumbSize,
					previewSize: r.sizePlan.previewSize,
				})
				if regenErr != nil {
					if errors.Is(regenErr, errInvalidSourcePath) || errors.Is(regenErr, errSourceNotFound) {
						if delErr := r.deleteAssetRecordAndDerivatives(ctx, asset); delErr != nil {
							log.Printf("[Step3][Worker %d] 删除无效记录失败: id=%s, err=%v", workerID, asset.ID, delErr)
							atomic.AddInt64(&stats.Step3FailedRecords, 1)
							continue
						}
						atomic.AddInt64(&stats.Step1InvalidSourceRecords, 1)
						atomic.AddInt64(&stats.Step1DeletedRecords, 1)
						continue
					}

					atomic.AddInt64(&stats.Step3FailedRecords, 1)
					log.Printf("[Step3][Worker %d] 修复缺失失败: id=%s, file_path=%q, err=%v", workerID, asset.ID, asset.FilePath, regenErr)
					continue
				}

				if res.thumbGenerated || res.previewGenerated {
					atomic.AddInt64(&stats.Step3FixedRecords, 1)
				}
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

	if ctx.Err() != nil {
		return ctx.Err()
	}
	return nil
}

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
	if asset.ThumbPath == nil || strings.TrimSpace(*asset.ThumbPath) == "" {
		return true
	}
	fullPath, ok := resolveRelativePath(r.config.ThumbsDir, *asset.ThumbPath)
	if !ok {
		return true
	}
	_, err := os.Stat(fullPath)
	return err != nil
}

func (r *Refresher) isPreviewMissing(asset *model.MediaAsset) bool {
	if asset.PreviewPath == nil || strings.TrimSpace(*asset.PreviewPath) == "" {
		return true
	}
	fullPath, ok := resolveRelativePath(r.config.PreviewDir, *asset.PreviewPath)
	if !ok {
		return true
	}
	_, err := os.Stat(fullPath)
	return err != nil
}

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

	thumbExt := ".jpg"
	previewExt := ".jpg"
	if ext == ".gif" {
		thumbExt = ".gif"
		previewExt = ".gif"
	}

	thumbFileName := baseName + "_thumb" + thumbExt
	previewFileName := baseName + "_preview" + previewExt
	thumbRel := joinRelative(yearMonth, thumbFileName)
	previewRel := joinRelative(yearMonth, previewFileName)
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

	isVideo := model.IsVideo(ext)
	isAnimatedGif := ext == ".gif"

	if isVideo {
		if err := processVideo(sourcePath, thumbFullPath, previewFullPath, req, asset.ID.String()); err != nil {
			return nil, err
		}
	} else if isAnimatedGif {
		if err := processAnimatedGif(sourcePath, thumbFullPath, previewFullPath, req); err != nil {
			return nil, err
		}
	} else {
		if err := processImage(sourcePath, thumbFullPath, previewFullPath, req); err != nil {
			return nil, err
		}
	}

	if req.needThumb {
		asset.ThumbPath = strPtr(thumbRel)
	}
	if req.needPreview {
		asset.PreviewPath = strPtr(previewRel)
	}
	asset.UpdatedAt = time.Now()

	if err := r.repository.UpdateMediaAssetFull(ctx, asset); err != nil {
		return nil, fmt.Errorf("更新数据库失败: %w", err)
	}

	return &regenerateResult{
		thumbGenerated:   req.needThumb,
		previewGenerated: req.needPreview,
	}, nil
}

func processImage(srcPath, thumbPath, previewPath string, req regenerateRequest) error {
	if !req.needThumb && !req.needPreview {
		return nil
	}

	src, err := openImageWithFallback(srcPath)
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	if req.needThumb {
		thumb := imaging.Fill(src, req.thumbSize, req.thumbSize, imaging.Center, imaging.Lanczos)
		if err := imaging.Save(thumb, thumbPath, imaging.JPEGQuality(jpegQuality)); err != nil {
			return fmt.Errorf("保存缩略图失败: %w", err)
		}
	}

	if req.needPreview {
		preview := imaging.Fit(src, req.previewSize, req.previewSize, imaging.Lanczos)
		if err := imaging.Save(preview, previewPath, imaging.JPEGQuality(jpegQuality)); err != nil {
			return fmt.Errorf("保存预览图失败: %w", err)
		}
	}

	return nil
}

func processVideo(srcPath, thumbPath, previewPath string, req regenerateRequest, uniqueID string) error {
	if !req.needThumb && !req.needPreview {
		return nil
	}

	duration, err := getVideoDuration(srcPath)
	if err != nil {
		duration = 10.0
	}

	seekTime := duration * 0.1
	if seekTime < 0.1 {
		seekTime = 0.1
	}

	tempFrame := filepath.Join(os.TempDir(), fmt.Sprintf("gallery_refresh_%s.jpg", uniqueID))
	defer os.Remove(tempFrame)

	cmd := exec.Command("ffmpeg",
		"-ss", fmt.Sprintf("%.2f", seekTime),
		"-i", srcPath,
		"-vframes", "1",
		"-q:v", "2",
		"-y",
		tempFrame,
	)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("ffmpeg 提取帧失败: %w, 输出: %s", err, string(output))
	}

	if _, err := os.Stat(tempFrame); os.IsNotExist(err) {
		return fmt.Errorf("ffmpeg 未能生成帧图片")
	}

	return processImage(tempFrame, thumbPath, previewPath, req)
}

func processAnimatedGif(srcPath, thumbPath, previewPath string, req regenerateRequest) error {
	if !req.needThumb && !req.needPreview {
		return nil
	}

	file, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("打开 GIF 失败: %w", err)
	}
	defer file.Close()

	if req.needThumb {
		gifImg, err := gif.DecodeAll(file)
		if err != nil {
			return fmt.Errorf("解码 GIF 失败: %w", err)
		}

		thumbGif, err := resizeGif(gifImg, req.thumbSize, req.thumbSize, true)
		if err != nil {
			return fmt.Errorf("生成 GIF 缩略图失败: %w", err)
		}

		thumbFile, err := os.Create(thumbPath)
		if err != nil {
			return fmt.Errorf("创建缩略图文件失败: %w", err)
		}
		if err := gif.EncodeAll(thumbFile, thumbGif); err != nil {
			thumbFile.Close()
			return fmt.Errorf("编码 GIF 缩略图失败: %w", err)
		}
		if err := thumbFile.Close(); err != nil {
			return fmt.Errorf("关闭缩略图文件失败: %w", err)
		}

		if req.needPreview {
			if _, err := file.Seek(0, 0); err != nil {
				return fmt.Errorf("重置 GIF 读取位置失败: %w", err)
			}
		}
	}

	if req.needPreview {
		gifImg, err := gif.DecodeAll(file)
		if err != nil {
			return fmt.Errorf("解码 GIF（预览）失败: %w", err)
		}

		previewGif, err := resizeGif(gifImg, req.previewSize, req.previewSize, false)
		if err != nil {
			return fmt.Errorf("生成 GIF 预览图失败: %w", err)
		}

		previewFile, err := os.Create(previewPath)
		if err != nil {
			return fmt.Errorf("创建预览图文件失败: %w", err)
		}
		if err := gif.EncodeAll(previewFile, previewGif); err != nil {
			previewFile.Close()
			return fmt.Errorf("编码 GIF 预览图失败: %w", err)
		}
		if err := previewFile.Close(); err != nil {
			return fmt.Errorf("关闭预览图文件失败: %w", err)
		}
	}

	return nil
}

func resizeGif(g *gif.GIF, width, height int, crop bool) (*gif.GIF, error) {
	if len(g.Image) == 0 {
		return nil, fmt.Errorf("GIF 没有帧")
	}

	bounds := g.Image[0].Bounds()

	var newWidth, newHeight int
	if crop {
		newWidth, newHeight = width, height
	} else {
		ratio := float64(bounds.Dx()) / float64(bounds.Dy())
		if ratio > 1 {
			newWidth = width
			newHeight = int(float64(width) / ratio)
		} else {
			newHeight = height
			newWidth = int(float64(height) * ratio)
		}
	}

	newGif := &gif.GIF{
		Image:           make([]*image.Paletted, len(g.Image)),
		Delay:           g.Delay,
		LoopCount:       g.LoopCount,
		Disposal:        g.Disposal,
		BackgroundIndex: g.BackgroundIndex,
	}

	for i, frame := range g.Image {
		img := imaging.Clone(frame)

		var resized image.Image
		if crop {
			resized = imaging.Fill(img, newWidth, newHeight, imaging.Center, imaging.Lanczos)
		} else {
			resized = imaging.Fit(img, newWidth, newHeight, imaging.Lanczos)
		}

		palettedImg := image.NewPaletted(resized.Bounds(), frame.Palette)
		for y := resized.Bounds().Min.Y; y < resized.Bounds().Max.Y; y++ {
			for x := resized.Bounds().Min.X; x < resized.Bounds().Max.X; x++ {
				palettedImg.Set(x, y, resized.At(x, y))
			}
		}
		newGif.Image[i] = palettedImg
	}

	newGif.Config.Width = newWidth
	newGif.Config.Height = newHeight
	newGif.Config.ColorModel = g.Config.ColorModel

	return newGif, nil
}

func openImageWithFallback(srcPath string) (image.Image, error) {
	src, err := imaging.Open(srcPath, imaging.AutoOrientation(true))
	if err == nil {
		return src, nil
	}

	log.Printf("原生解码失败 (%v)，使用 ffmpeg 后备: %s", err, filepath.Base(srcPath))
	tempJPEG := filepath.Join(os.TempDir(), fmt.Sprintf("gallery_refresh_conv_%d_%s.jpg",
		os.Getpid(), strings.TrimSuffix(filepath.Base(srcPath), filepath.Ext(srcPath))))
	defer os.Remove(tempJPEG)

	cmd := exec.Command("ffmpeg",
		"-i", srcPath,
		"-qmin", "1",
		"-q:v", "2",
		"-y",
		tempJPEG,
	)
	if output, err := cmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("ffmpeg 转换图片失败: %w, 输出: %s", err, string(output))
	}

	src, err = imaging.Open(tempJPEG, imaging.AutoOrientation(true))
	if err != nil {
		return nil, fmt.Errorf("打开 ffmpeg 转换后的图片失败: %w", err)
	}
	return src, nil
}

func getVideoDuration(videoPath string) (float64, error) {
	cmd := exec.Command("ffprobe",
		"-v", "error",
		"-show_entries", "format=duration",
		"-of", "default=noprint_wrappers=1:nokey=1",
		videoPath,
	)

	var out bytes.Buffer
	cmd.Stdout = &out

	if err := cmd.Run(); err != nil {
		return 0, err
	}

	duration, err := strconv.ParseFloat(strings.TrimSpace(out.String()), 64)
	if err != nil {
		return 0, err
	}

	return duration, nil
}

func buildSizePlan(resize, resizePreview, resizeThumb int) (sizePlan, error) {
	if resize < 0 || resizePreview < 0 || resizeThumb < 0 {
		return sizePlan{}, fmt.Errorf("resize/resizePreview/resizeThumb 不能为负数")
	}

	plan := sizePlan{
		thumbSize:   defaultThumbSize,
		previewSize: defaultPreviewSize,
	}

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

func resolveRelativePath(baseDir, relPath string) (string, bool) {
	normalized := normalizeRelativePath(relPath)
	if normalized == "" {
		return "", false
	}
	if filepath.IsAbs(normalized) {
		return "", false
	}
	if normalized == "." || normalized == ".." {
		return "", false
	}
	if strings.HasPrefix(normalized, ".."+string(filepath.Separator)) {
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
