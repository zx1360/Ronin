// Package processor 负责图片/视频处理，包括缩略图和预览图生成
package processor

import (
	"bytes"
	"fmt"
	"image"
	"image/gif"
	"image/jpeg"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/disintegration/imaging"
	_ "golang.org/x/image/webp" // WebP 解码支持

	"gizmos/internal/gallery/model"
)

const (
	ThumbSize   = 256 // 缩略图尺寸 256x256
	PreviewSize = 512 // 预览图最大边
	JpegQuality = 85  // JPEG 压缩质量
)

// Processor 媒体处理器
type Processor struct {
	thumbsDir  string // 缩略图目录
	previewDir string // 预览图目录
	ffmpegPath string // ffmpeg 路径
}

// NewProcessor 创建新的处理器
func NewProcessor(thumbsDir, previewDir string) *Processor {
	return &Processor{
		thumbsDir:  thumbsDir,
		previewDir: previewDir,
		ffmpegPath: "ffmpeg", // 假设已在 PATH 中
	}
}

// ProcessResult 处理结果
type ProcessResult struct {
	ThumbPath   string // 缩略图相对路径
	PreviewPath string // 预览图相对路径
}

// Process 处理媒体文件，生成缩略图和预览图
func (p *Processor) Process(fileInfo *model.FileInfo, mediaPath string, yearMonth string) (*ProcessResult, error) {
	// 构建输出路径
	baseName := strings.TrimSuffix(filepath.Base(fileInfo.FileName), fileInfo.Extension)

	// 缩略图和预览图统一使用 jpg 格式（除了 GIF 保持动态）
	thumbExt := ".jpg"
	previewExt := ".jpg"
	if fileInfo.IsAnimated && fileInfo.Extension == ".gif" {
		thumbExt = ".gif"
		previewExt = ".gif"
	}

	thumbFileName := baseName + "_thumb" + thumbExt
	previewFileName := baseName + "_preview" + previewExt

	// 确保目录存在
	thumbSubDir := filepath.Join(p.thumbsDir, yearMonth)
	previewSubDir := filepath.Join(p.previewDir, yearMonth)

	if err := os.MkdirAll(thumbSubDir, 0755); err != nil {
		return nil, fmt.Errorf("创建缩略图目录失败: %w", err)
	}
	if err := os.MkdirAll(previewSubDir, 0755); err != nil {
		return nil, fmt.Errorf("创建预览图目录失败: %w", err)
	}

	thumbFullPath := filepath.Join(thumbSubDir, thumbFileName)
	previewFullPath := filepath.Join(previewSubDir, previewFileName)

	var err error
	if fileInfo.IsVideo {
		err = p.processVideo(mediaPath, thumbFullPath, previewFullPath)
	} else if fileInfo.IsAnimated && fileInfo.Extension == ".gif" {
		err = p.processAnimatedGif(mediaPath, thumbFullPath, previewFullPath)
	} else {
		err = p.processImage(mediaPath, thumbFullPath, previewFullPath)
	}

	if err != nil {
		return nil, err
	}

	// 返回相对路径
	return &ProcessResult{
		ThumbPath:   filepath.Join(yearMonth, thumbFileName),
		PreviewPath: filepath.Join(yearMonth, previewFileName),
	}, nil
}

// processImage 处理静态图片
func (p *Processor) processImage(srcPath, thumbPath, previewPath string) error {
	// 打开源图片
	src, err := imaging.Open(srcPath, imaging.AutoOrientation(true))
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	// 生成缩略图 (256x256，中心裁剪)
	thumb := imaging.Fill(src, ThumbSize, ThumbSize, imaging.Center, imaging.Lanczos)
	if err := imaging.Save(thumb, thumbPath, imaging.JPEGQuality(JpegQuality)); err != nil {
		return fmt.Errorf("保存缩略图失败: %w", err)
	}

	// 生成预览图 (最大边 512px，保持比例)
	preview := imaging.Fit(src, PreviewSize, PreviewSize, imaging.Lanczos)
	if err := imaging.Save(preview, previewPath, imaging.JPEGQuality(JpegQuality)); err != nil {
		return fmt.Errorf("保存预览图失败: %w", err)
	}

	return nil
}

// processVideo 处理视频文件
func (p *Processor) processVideo(srcPath, thumbPath, previewPath string) error {
	// 获取视频时长
	duration, err := p.getVideoDuration(srcPath)
	if err != nil {
		// 如果获取时长失败，默认取第 1 秒
		duration = 10.0
	}

	// 计算 10% 位置的时间点
	seekTime := duration * 0.1
	if seekTime < 0.1 {
		seekTime = 0.1
	}

	// 提取帧到临时文件 - 使用唯一文件名避免并发冲突
	tempFrame := filepath.Join(os.TempDir(), fmt.Sprintf("gallery_frame_%d_%s.jpg",
		os.Getpid(), filepath.Base(srcPath)))
	defer os.Remove(tempFrame)

	// 使用 ffmpeg 提取帧
	cmd := exec.Command(p.ffmpegPath,
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

	// 检查临时文件是否成功生成
	if _, err := os.Stat(tempFrame); os.IsNotExist(err) {
		return fmt.Errorf("ffmpeg 未能生成帧图片")
	}

	// 使用图片处理方法处理提取的帧
	return p.processImage(tempFrame, thumbPath, previewPath)
}

// processAnimatedGif 处理动态 GIF
func (p *Processor) processAnimatedGif(srcPath, thumbPath, previewPath string) error {
	// 打开 GIF 文件
	file, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("打开 GIF 失败: %w", err)
	}
	defer file.Close()

	// 解码 GIF
	gifImg, err := gif.DecodeAll(file)
	if err != nil {
		return fmt.Errorf("解码 GIF 失败: %w", err)
	}

	// 处理每一帧生成缩略图
	thumbGif, err := p.resizeGif(gifImg, ThumbSize, ThumbSize, true)
	if err != nil {
		return fmt.Errorf("生成 GIF 缩略图失败: %w", err)
	}

	// 保存缩略图
	thumbFile, err := os.Create(thumbPath)
	if err != nil {
		return fmt.Errorf("创建缩略图文件失败: %w", err)
	}
	defer thumbFile.Close()

	if err := gif.EncodeAll(thumbFile, thumbGif); err != nil {
		return fmt.Errorf("编码 GIF 缩略图失败: %w", err)
	}

	// 重新读取原文件用于预览图
	file.Seek(0, 0)
	gifImg2, err := gif.DecodeAll(file)
	if err != nil {
		return fmt.Errorf("重新解码 GIF 失败: %w", err)
	}

	// 处理预览图
	previewGif, err := p.resizeGif(gifImg2, PreviewSize, PreviewSize, false)
	if err != nil {
		return fmt.Errorf("生成 GIF 预览图失败: %w", err)
	}

	// 保存预览图
	previewFile, err := os.Create(previewPath)
	if err != nil {
		return fmt.Errorf("创建预览图文件失败: %w", err)
	}
	defer previewFile.Close()

	if err := gif.EncodeAll(previewFile, previewGif); err != nil {
		return fmt.Errorf("编码 GIF 预览图失败: %w", err)
	}

	return nil
}

// resizeGif 调整 GIF 大小
func (p *Processor) resizeGif(g *gif.GIF, width, height int, crop bool) (*gif.GIF, error) {
	if len(g.Image) == 0 {
		return nil, fmt.Errorf("GIF 没有帧")
	}

	// 获取原始尺寸
	firstFrame := g.Image[0]
	bounds := firstFrame.Bounds()

	// 计算新尺寸
	var newWidth, newHeight int
	if crop {
		newWidth, newHeight = width, height
	} else {
		// 保持比例缩放
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
		// 转换为 NRGBA 以便处理
		img := imaging.Clone(frame)

		var resized image.Image
		if crop {
			resized = imaging.Fill(img, newWidth, newHeight, imaging.Center, imaging.Lanczos)
		} else {
			resized = imaging.Fit(img, newWidth, newHeight, imaging.Lanczos)
		}

		// 转换回 Paletted
		palettedImg := image.NewPaletted(resized.Bounds(), frame.Palette)
		for y := resized.Bounds().Min.Y; y < resized.Bounds().Max.Y; y++ {
			for x := resized.Bounds().Min.X; x < resized.Bounds().Max.X; x++ {
				palettedImg.Set(x, y, resized.At(x, y))
			}
		}
		newGif.Image[i] = palettedImg
	}

	// 更新配置尺寸
	newGif.Config.Width = newWidth
	newGif.Config.Height = newHeight
	newGif.Config.ColorModel = g.Config.ColorModel

	return newGif, nil
}

// getVideoDuration 获取视频时长（秒）
func (p *Processor) getVideoDuration(videoPath string) (float64, error) {
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

// DecodeImage 解码图片（支持多种格式）
func DecodeImage(filePath string) (image.Image, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		return nil, err
	}
	return img, nil
}

// EncodeJPEG 编码为 JPEG
func EncodeJPEG(img image.Image, filePath string, quality int) error {
	file, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	return jpeg.Encode(file, img, &jpeg.Options{Quality: quality})
}

// EncodePNG 编码为 PNG
func EncodePNG(img image.Image, filePath string) error {
	file, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	return png.Encode(file, img)
}
