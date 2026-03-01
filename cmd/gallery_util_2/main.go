// 缩略图/预览图修复工具
// 扫描 mediaDir 中所有媒体文件对应的数据库记录，
// 对 thumb_path 或 preview_path 为空或物理文件不存在的记录，
// 重新生成缩略图和预览图并更新数据库。
package main

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"image"
	"image/gif"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/disintegration/imaging"
	"github.com/google/uuid"
	_ "golang.org/x/image/webp"

	"gizmos/internal/gallery/model"
	"gizmos/internal/service/config"
	"gizmos/internal/service/db"
)

const (
	galleryDir  = "D:\\Assests\\Gallery"
	ThumbSize   = 256 // 缩略图尺寸 256×256
	PreviewSize = 256 // 预览图最大边
	JpegQuality = 85  // JPEG 压缩质量
)

var (
	mediaDir   = filepath.Join(galleryDir, "Media")
	thumbsDir  = filepath.Join(galleryDir, "Thumbs")
	previewDir = filepath.Join(galleryDir, "Preview")
)

// Stats 统计信息
type Stats struct {
	TotalRecords  int64
	NeedFix       int64
	FixedRecords  int64
	FailedRecords int64
}

// AssetRecord 从数据库读取的媒体资产记录（所有字段）
type AssetRecord struct {
	ID          uuid.UUID
	CreatedAt   time.Time
	UpdatedAt   time.Time
	CapturedAt  time.Time
	FilePath    string
	ThumbPath   *string
	PreviewPath *string
	Hash        []byte
	SizeBytes   int64
	MimeType    *string
	IsDeleted   bool
	SyncCount   int
	GroupID      *uuid.UUID
}

func main() {
	concurrency := flag.Int("concurrency", 8, "并发处理数")
	flag.Parse()

	fmt.Println("========== 缩略图/预览图修复工具 ==========")
	fmt.Printf("媒体目录:   %s\n", mediaDir)
	fmt.Printf("缩略图目录: %s\n", thumbsDir)
	fmt.Printf("预览图目录: %s\n", previewDir)
	fmt.Printf("并发数:     %d\n", *concurrency)
	fmt.Println("=============================================")

	// 初始化数据库
	db.Init(config.DbConf)
	defer db.Close()

	// 创建可取消上下文
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

	// 查询所有未删除的媒体记录
	log.Println("查询数据库中所有未删除的媒体记录...")
	assets, err := getAllActiveAssets()
	if err != nil {
		log.Fatalf("查询数据库失败: %v", err)
	}

	stats := &Stats{
		TotalRecords: int64(len(assets)),
	}
	log.Printf("共找到 %d 条记录", len(assets))

	// 过滤出需要修复的记录
	var needFix []*AssetRecord
	for _, asset := range assets {
		if needsRegeneration(asset) {
			needFix = append(needFix, asset)
		}
	}

	stats.NeedFix = int64(len(needFix))
	log.Printf("需要修复的记录: %d 条", len(needFix))

	if len(needFix) == 0 {
		log.Println("所有记录均正常，无需修复。")
		return
	}

	// 并发处理
	taskChan := make(chan *AssetRecord, *concurrency*2)

	var wg sync.WaitGroup
	for i := 0; i < *concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for asset := range taskChan {
				select {
				case <-ctx.Done():
					return
				default:
				}

				if err := fixAsset(asset); err != nil {
					atomic.AddInt64(&stats.FailedRecords, 1)
					log.Printf("[Worker %d] 修复失败: %s - %v", workerID, asset.FilePath, err)
				} else {
					atomic.AddInt64(&stats.FixedRecords, 1)
					log.Printf("[Worker %d] 修复完成: %s", workerID, asset.FilePath)
				}
			}
		}(i)
	}

	// 分发任务
	for _, asset := range needFix {
		select {
		case <-ctx.Done():
			break
		case taskChan <- asset:
		}
	}
	close(taskChan)

	// 等待所有 worker 完成
	wg.Wait()

	// 打印统计
	fmt.Println()
	fmt.Println("========== 修复统计 ==========")
	fmt.Printf("总记录数: %d\n", stats.TotalRecords)
	fmt.Printf("需修复数: %d\n", stats.NeedFix)
	fmt.Printf("修复成功: %d\n", stats.FixedRecords)
	fmt.Printf("修复失败: %d\n", stats.FailedRecords)
	fmt.Println("==============================")
}

// ──────────────────────────── 数据库操作 ────────────────────────────

// getAllActiveAssets 查询所有未删除的媒体记录
func getAllActiveAssets() ([]*AssetRecord, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	rows, err := db.Pool.Query(ctx, `
		SELECT id, created_at, updated_at, captured_at, file_path, thumb_path,
		       preview_path, hash, size_bytes, mime_type, is_deleted, sync_count, group_id
		FROM gallery.media_assets
		WHERE is_deleted = false
		ORDER BY file_path
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assets []*AssetRecord
	for rows.Next() {
		a := &AssetRecord{}
		err := rows.Scan(
			&a.ID,
			&a.CreatedAt,
			&a.UpdatedAt,
			&a.CapturedAt,
			&a.FilePath,
			&a.ThumbPath,
			&a.PreviewPath,
			&a.Hash,
			&a.SizeBytes,
			&a.MimeType,
			&a.IsDeleted,
			&a.SyncCount,
			&a.GroupID,
		)
		if err != nil {
			return nil, fmt.Errorf("扫描行数据失败: %w", err)
		}
		assets = append(assets, a)
	}

	return assets, rows.Err()
}

// updateAssetRecord 更新数据库记录（显式赋值所有字段）
func updateAssetRecord(asset *AssetRecord, thumbPath, previewPath string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	now := time.Now()

	_, err := db.Pool.Exec(ctx, `
		UPDATE gallery.media_assets SET
			created_at   = $1,
			updated_at   = $2,
			captured_at  = $3,
			file_path    = $4,
			thumb_path   = $5,
			preview_path = $6,
			hash         = $7,
			size_bytes   = $8,
			mime_type    = $9,
			is_deleted   = $10,
			sync_count   = $11,
			group_id     = $12
		WHERE id = $13
	`,
		asset.CreatedAt,  // $1  created_at: 保留原值
		now,              // $2  updated_at: 更新为当前时间
		asset.CapturedAt, // $3  captured_at: 保留原值
		asset.FilePath,   // $4  file_path: 保留原值
		thumbPath,        // $5  thumb_path: 新缩略图路径
		previewPath,      // $6  preview_path: 新预览图路径
		asset.Hash,       // $7  hash: 保留原值
		asset.SizeBytes,  // $8  size_bytes: 保留原值
		asset.MimeType,   // $9  mime_type: 保留原值
		asset.IsDeleted,  // $10 is_deleted: 保留原值
		asset.SyncCount,  // $11 sync_count: 保留原值
		asset.GroupID,    // $12 group_id: 保留原值
		asset.ID,         // $13 WHERE 条件
	)
	return err
}

// ──────────────────────────── 检查与修复逻辑 ────────────────────────────

// needsRegeneration 判断记录是否需要重新生成缩略图或预览图
func needsRegeneration(asset *AssetRecord) bool {
	// 检查缩略图
	if asset.ThumbPath == nil || *asset.ThumbPath == "" {
		return true
	}
	thumbFullPath := filepath.Join(thumbsDir, *asset.ThumbPath)
	if _, err := os.Stat(thumbFullPath); err != nil {
		return true
	}

	// 检查预览图
	if asset.PreviewPath == nil || *asset.PreviewPath == "" {
		return true
	}
	previewFullPath := filepath.Join(previewDir, *asset.PreviewPath)
	if _, err := os.Stat(previewFullPath); err != nil {
		return true
	}

	return false
}

// fixAsset 修复单个资产的缩略图和预览图
func fixAsset(asset *AssetRecord) error {
	// 构建原文件完整路径
	mediaFullPath := filepath.Join(mediaDir, asset.FilePath)

	// 检查原文件是否存在
	if _, err := os.Stat(mediaFullPath); err != nil {
		return fmt.Errorf("原文件不可访问: %s - %v", mediaFullPath, err)
	}

	// 解析文件信息
	ext := strings.ToLower(filepath.Ext(asset.FilePath))
	baseName := strings.TrimSuffix(filepath.Base(asset.FilePath), filepath.Ext(asset.FilePath))
	yearMonth := filepath.Dir(asset.FilePath) // 例如 "2023-01"

	isVideo := model.IsVideo(ext)
	isAnimatedGif := ext == ".gif"

	// 确定缩略图和预览图的输出扩展名
	thumbExt := ".jpg"
	previewExt := ".jpg"
	if isAnimatedGif {
		thumbExt = ".gif"
		previewExt = ".gif"
	}

	thumbFileName := baseName + "_thumb" + thumbExt
	previewFileName := baseName + "_preview" + previewExt

	// 确保输出目录存在
	thumbSubDir := filepath.Join(thumbsDir, yearMonth)
	previewSubDir := filepath.Join(previewDir, yearMonth)

	if err := os.MkdirAll(thumbSubDir, 0755); err != nil {
		return fmt.Errorf("创建缩略图目录失败: %w", err)
	}
	if err := os.MkdirAll(previewSubDir, 0755); err != nil {
		return fmt.Errorf("创建预览图目录失败: %w", err)
	}

	thumbFullPath := filepath.Join(thumbSubDir, thumbFileName)
	previewFullPath := filepath.Join(previewSubDir, previewFileName)

	// 分别判断缩略图和预览图是否需要重新生成
	needThumb := asset.ThumbPath == nil || *asset.ThumbPath == "" ||
		!fileExists(filepath.Join(thumbsDir, *asset.ThumbPath))
	needPreview := asset.PreviewPath == nil || *asset.PreviewPath == "" ||
		!fileExists(filepath.Join(previewDir, *asset.PreviewPath))

	// 按文件类型执行生成
	if isVideo {
		if err := processVideo(mediaFullPath, thumbFullPath, previewFullPath,
			needThumb, needPreview, asset.ID.String()); err != nil {
			return fmt.Errorf("处理视频失败: %w", err)
		}
	} else if isAnimatedGif {
		if err := processAnimatedGif(mediaFullPath, thumbFullPath, previewFullPath,
			needThumb, needPreview); err != nil {
			return fmt.Errorf("处理动态 GIF 失败: %w", err)
		}
	} else {
		if err := processImage(mediaFullPath, thumbFullPath, previewFullPath,
			needThumb, needPreview); err != nil {
			return fmt.Errorf("处理图片失败: %w", err)
		}
	}

	// 确定写入数据库的最终路径
	// 如果该部分未重新生成，则沿用数据库中原有路径
	finalThumbPath := filepath.Join(yearMonth, thumbFileName)
	if !needThumb && asset.ThumbPath != nil {
		finalThumbPath = *asset.ThumbPath
	}

	finalPreviewPath := filepath.Join(yearMonth, previewFileName)
	if !needPreview && asset.PreviewPath != nil {
		finalPreviewPath = *asset.PreviewPath
	}

	// 更新数据库（显式赋值所有字段）
	if err := updateAssetRecord(asset, finalThumbPath, finalPreviewPath); err != nil {
		return fmt.Errorf("更新数据库失败: %w", err)
	}

	return nil
}

// fileExists 检查文件是否存在
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// ──────────────────────────── 图片/视频处理 ────────────────────────────

// openImageWithFallback 打开图片，原生解码失败时用 ffmpeg 转为标准 JPEG 再解码
func openImageWithFallback(srcPath string) (image.Image, error) {
	src, err := imaging.Open(srcPath, imaging.AutoOrientation(true))
	if err == nil {
		return src, nil
	}

	// 原生解码失败，使用 ffmpeg 转换
	log.Printf("原生解码失败 (%v)，使用 ffmpeg 后备: %s", err, filepath.Base(srcPath))

	tempJPEG := filepath.Join(os.TempDir(), fmt.Sprintf("gallery_conv_%d_%s.jpg",
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

// processImage 处理静态图片，生成缩略图和/或预览图
func processImage(srcPath, thumbPath, previewPath string, needThumb, needPreview bool) error {
	if !needThumb && !needPreview {
		return nil
	}

	src, err := openImageWithFallback(srcPath)
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	if needThumb {
		// 256×256 中心裁剪
		thumb := imaging.Fill(src, ThumbSize, ThumbSize, imaging.Center, imaging.Lanczos)
		if err := imaging.Save(thumb, thumbPath, imaging.JPEGQuality(JpegQuality)); err != nil {
			return fmt.Errorf("保存缩略图失败: %w", err)
		}
	}

	if needPreview {
		// 最大边 256px，保持比例
		preview := imaging.Fit(src, PreviewSize, PreviewSize, imaging.Lanczos)
		if err := imaging.Save(preview, previewPath, imaging.JPEGQuality(JpegQuality)); err != nil {
			return fmt.Errorf("保存预览图失败: %w", err)
		}
	}

	return nil
}

// processVideo 处理视频文件：提取帧后按图片方式生成缩略图/预览图
func processVideo(srcPath, thumbPath, previewPath string, needThumb, needPreview bool, uniqueID string) error {
	if !needThumb && !needPreview {
		return nil
	}

	// 获取视频时长
	duration, err := getVideoDuration(srcPath)
	if err != nil {
		duration = 10.0 // 默认 10 秒
	}

	// 取 10% 位置作为关键帧
	seekTime := duration * 0.1
	if seekTime < 0.1 {
		seekTime = 0.1
	}

	// 提取帧到临时文件（使用唯一 ID 避免并发冲突）
	tempFrame := filepath.Join(os.TempDir(), fmt.Sprintf("gallery_fix_%s.jpg", uniqueID))
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

	// 将提取的帧作为普通图片处理
	return processImage(tempFrame, thumbPath, previewPath, needThumb, needPreview)
}

// processAnimatedGif 处理动态 GIF，保持动画完整
func processAnimatedGif(srcPath, thumbPath, previewPath string, needThumb, needPreview bool) error {
	if !needThumb && !needPreview {
		return nil
	}

	file, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("打开 GIF 失败: %w", err)
	}
	defer file.Close()

	if needThumb {
		gifImg, err := gif.DecodeAll(file)
		if err != nil {
			return fmt.Errorf("解码 GIF 失败: %w", err)
		}

		thumbGif, err := resizeGif(gifImg, ThumbSize, ThumbSize, true)
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
		thumbFile.Close()

		// 重置读取位置用于预览图
		if _, err := file.Seek(0, 0); err != nil {
			return fmt.Errorf("重置文件读取位置失败: %w", err)
		}
	}

	if needPreview {
		gifImg2, err := gif.DecodeAll(file)
		if err != nil {
			return fmt.Errorf("解码 GIF（预览）失败: %w", err)
		}

		previewGif, err := resizeGif(gifImg2, PreviewSize, PreviewSize, false)
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
		previewFile.Close()
	}

	return nil
}

// resizeGif 调整 GIF 尺寸（crop=true 为中心裁剪，false 为保持比例）
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

// getVideoDuration 通过 ffprobe 获取视频时长（秒）
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
