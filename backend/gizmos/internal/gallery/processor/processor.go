// Package processor 负责图片/视频的缩略图与预览图生成。
//
// 所有派生图都写到调用方给定的绝对路径；源文件只读。视频取帧依赖 PATH 中的
// ffmpeg/ffprobe，原生解码失败时也会退回 ffmpeg 转换。
package processor

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/gif"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/disintegration/imaging"
	_ "golang.org/x/image/webp" // WebP 解码支持

	"gizmos/internal/gallery/model"
)

const (
	ThumbSize   = 256 // 缩略图边长（中心裁剪为正方形）
	PreviewSize = 256 // 预览图最大边（保持比例）
	JpegQuality = 85  // JPEG 压缩质量

	ffmpegTimeout = 5 * time.Minute
)

// ErrNoOp 表示编辑参数实际为无操作（无需处理），
// 调用方应跳过文件搬移并仅清除数据库中的 edit_params。
var ErrNoOp = fmt.Errorf("编辑参数为无操作")

// GenerateRequest 描述一次派生图生成请求。
type GenerateRequest struct {
	NeedThumb   bool
	NeedPreview bool
	ThumbSize   int
	PreviewSize int
}

// Processor 媒体处理器
type Processor struct {
	thumbsDir  string
	previewDir string
}

// NewProcessor 创建新的处理器
func NewProcessor(thumbsDir, previewDir string) *Processor {
	return &Processor{thumbsDir: thumbsDir, previewDir: previewDir}
}

// ProcessResult 处理结果（相对路径）
type ProcessResult struct {
	ThumbPath   string
	PreviewPath string
}

// Process 为媒体文件生成缩略图与预览图，返回相对 thumbsDir/previewDir 的路径。
func (p *Processor) Process(fileInfo *model.FileInfo, mediaPath, yearMonth string) (*ProcessResult, error) {
	baseName := strings.TrimSuffix(filepath.Base(fileInfo.FileName), fileInfo.Extension)

	// 统一输出 jpg；动态 GIF 保持 gif 以保留动画
	ext := ".jpg"
	if fileInfo.IsAnimated && fileInfo.Extension == ".gif" {
		ext = ".gif"
	}
	thumbFileName := baseName + "_thumb" + ext
	previewFileName := baseName + "_preview" + ext

	thumbFullPath := filepath.Join(p.thumbsDir, yearMonth, thumbFileName)
	previewFullPath := filepath.Join(p.previewDir, yearMonth, previewFileName)
	for _, dir := range []string{filepath.Dir(thumbFullPath), filepath.Dir(previewFullPath)} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return nil, fmt.Errorf("创建派生图目录失败: %w", err)
		}
	}

	err := Generate(mediaPath, thumbFullPath, previewFullPath, GenerateRequest{
		NeedThumb:   true,
		NeedPreview: true,
		ThumbSize:   ThumbSize,
		PreviewSize: PreviewSize,
	}, fileInfo.IsVideo, fileInfo.IsAnimated && fileInfo.Extension == ".gif")
	if err != nil {
		return nil, err
	}

	return &ProcessResult{
		ThumbPath:   filepath.Join(yearMonth, thumbFileName),
		PreviewPath: filepath.Join(yearMonth, previewFileName),
	}, nil
}

// Generate 从 srcPath 生成缩略图/预览图到给定绝对路径。
//
// 目录必须由调用方预先创建；isVideo/isGIF 决定走哪条处理管线，
// 二者都为 false 时按静态图片处理（原生解码失败会自动用 ffmpeg 兜底）。
func Generate(srcPath, thumbPath, previewPath string, req GenerateRequest, isVideo, isGIF bool) error {
	if !req.NeedThumb && !req.NeedPreview {
		return nil
	}
	if req.ThumbSize <= 0 {
		req.ThumbSize = ThumbSize
	}
	if req.PreviewSize <= 0 {
		req.PreviewSize = PreviewSize
	}

	if isVideo {
		return processVideo(srcPath, thumbPath, previewPath, req)
	}
	if isGIF {
		return processAnimatedGif(srcPath, thumbPath, previewPath, req)
	}
	return processImage(srcPath, thumbPath, previewPath, req)
}

// processImage 处理静态图片
func processImage(srcPath, thumbPath, previewPath string, req GenerateRequest) error {
	src, err := openImageWithFallback(srcPath)
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	if req.NeedThumb {
		thumb := imaging.Fill(src, req.ThumbSize, req.ThumbSize, imaging.Center, imaging.Lanczos)
		if err := imaging.Save(thumb, thumbPath, imaging.JPEGQuality(JpegQuality)); err != nil {
			return fmt.Errorf("保存缩略图失败: %w", err)
		}
	}
	if req.NeedPreview {
		preview := imaging.Fit(src, req.PreviewSize, req.PreviewSize, imaging.Lanczos)
		if err := imaging.Save(preview, previewPath, imaging.JPEGQuality(JpegQuality)); err != nil {
			return fmt.Errorf("保存预览图失败: %w", err)
		}
	}
	return nil
}

// processVideo 取视频 10% 位置的一帧作为源图，再走图片处理管线
func processVideo(srcPath, thumbPath, previewPath string, req GenerateRequest) error {
	duration, err := getVideoDuration(srcPath)
	if err != nil {
		duration = 10.0 // 探测失败时退化为固定 1s 位置
	}
	seekTime := duration * 0.1
	if seekTime < 0.1 {
		seekTime = 0.1
	}

	tempFrame, err := tempFilePath("gallery_frame_", ".jpg")
	if err != nil {
		return err
	}
	defer os.Remove(tempFrame)

	if output, err := runFFmpeg(
		"-ss", strconv.FormatFloat(seekTime, 'f', 2, 64),
		"-i", srcPath,
		"-vframes", "1",
		"-q:v", "2",
		"-y", tempFrame,
	); err != nil {
		return fmt.Errorf("ffmpeg 提取帧失败: %w, 输出: %s", err, output)
	}
	if _, err := os.Stat(tempFrame); err != nil {
		return fmt.Errorf("ffmpeg 未能生成帧图片")
	}

	return processImage(tempFrame, thumbPath, previewPath, req)
}

// processAnimatedGif 处理动态 GIF（缩略图与预览图都保留动画）
func processAnimatedGif(srcPath, thumbPath, previewPath string, req GenerateRequest) error {
	// 每次重新打开文件解码，避免依赖句柄的 Seek 复位
	decode := func() (*gif.GIF, error) {
		file, err := os.Open(srcPath)
		if err != nil {
			return nil, fmt.Errorf("打开 GIF 失败: %w", err)
		}
		defer file.Close()

		gifImg, err := gif.DecodeAll(file)
		if err != nil {
			return nil, fmt.Errorf("解码 GIF 失败: %w", err)
		}
		return gifImg, nil
	}

	if req.NeedThumb {
		gifImg, err := decode()
		if err != nil {
			return err
		}
		thumbGif, err := resizeGif(gifImg, req.ThumbSize, req.ThumbSize, true)
		if err != nil {
			return fmt.Errorf("生成 GIF 缩略图失败: %w", err)
		}
		if err := writeGif(thumbPath, thumbGif); err != nil {
			return fmt.Errorf("保存 GIF 缩略图失败: %w", err)
		}
	}

	if req.NeedPreview {
		gifImg, err := decode()
		if err != nil {
			return err
		}
		previewGif, err := resizeGif(gifImg, req.PreviewSize, req.PreviewSize, false)
		if err != nil {
			return fmt.Errorf("生成 GIF 预览图失败: %w", err)
		}
		if err := writeGif(previewPath, previewGif); err != nil {
			return fmt.Errorf("保存 GIF 预览图失败: %w", err)
		}
	}
	return nil
}

func writeGif(path string, g *gif.GIF) error {
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	if err := gif.EncodeAll(file, g); err != nil {
		file.Close()
		return err
	}
	return file.Close()
}

// resizeGif 缩放 GIF 所有帧；crop=true 时中心裁剪为正方形。
func resizeGif(g *gif.GIF, width, height int, crop bool) (*gif.GIF, error) {
	if len(g.Image) == 0 {
		return nil, fmt.Errorf("GIF 没有帧")
	}

	bounds := g.Image[0].Bounds()
	newWidth, newHeight := width, height
	if !crop {
		ratio := float64(bounds.Dx()) / float64(bounds.Dy())
		if ratio > 1 {
			newHeight = int(float64(width) / ratio)
		} else {
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

// openImageWithFallback 打开图片，原生解码失败时用 ffmpeg 转为标准 JPEG 再解码
func openImageWithFallback(srcPath string) (image.Image, error) {
	src, err := imaging.Open(srcPath, imaging.AutoOrientation(true))
	if err == nil {
		return src, nil
	}
	log.Printf("原生解码失败 (%v)，使用 ffmpeg 后备: %s", err, filepath.Base(srcPath))

	tempJPEG, err := tempFilePath("gallery_conv_", ".jpg")
	if err != nil {
		return nil, err
	}
	defer os.Remove(tempJPEG)

	if output, err := runFFmpeg(
		"-i", srcPath,
		"-qmin", "1",
		"-q:v", "2",
		"-y", tempJPEG,
	); err != nil {
		return nil, fmt.Errorf("ffmpeg 转换图片失败: %w, 输出: %s", err, output)
	}

	src, err = imaging.Open(tempJPEG, imaging.AutoOrientation(true))
	if err != nil {
		return nil, fmt.Errorf("打开 ffmpeg 转换后的图片失败: %w", err)
	}
	return src, nil
}

// getVideoDuration 获取视频时长（秒）
func getVideoDuration(videoPath string) (float64, error) {
	ctx, cancel := context.WithTimeout(context.Background(), ffmpegTimeout)
	defer cancel()

	var out bytes.Buffer
	cmd := exec.CommandContext(ctx, "ffprobe",
		"-v", "error",
		"-show_entries", "format=duration",
		"-of", "default=noprint_wrappers=1:nokey=1",
		videoPath,
	)
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return 0, err
	}
	return strconv.ParseFloat(strings.TrimSpace(out.String()), 64)
}

// runFFmpeg 执行一次 ffmpeg 调用（带超时），返回合并输出用于错误上报。
func runFFmpeg(args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), ffmpegTimeout)
	defer cancel()

	output, err := exec.CommandContext(ctx, "ffmpeg", args...).CombinedOutput()
	return string(output), err
}

// tempFilePath 在系统临时目录创建一个空文件并返回其路径（供 ffmpeg 覆写）。
func tempFilePath(prefix, ext string) (string, error) {
	file, err := os.CreateTemp("", prefix+"*"+ext)
	if err != nil {
		return "", fmt.Errorf("创建临时文件失败: %w", err)
	}
	name := file.Name()
	if err := file.Close(); err != nil {
		return "", fmt.Errorf("关闭临时文件失败: %w", err)
	}
	return name, nil
}
