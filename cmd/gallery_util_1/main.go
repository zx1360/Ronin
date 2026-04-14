// !!! 一次性工具, 已无用.
// 预览图重新生成工具

package main

import (
	"bytes"
	"flag"
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

	"github.com/disintegration/imaging"
	_ "golang.org/x/image/webp"

	"gizmos/internal/gallery/model"
)

const (
	galleryDir  = "D:\\Assests\\Gallery"
	PreviewSize = 256 // 预览图最大边改为 256
	JpegQuality = 85
)

var (
	mediaDir   = filepath.Join(galleryDir, "Media")
	previewDir = filepath.Join(galleryDir, "Preview")
)

// Stats 统计信息
type Stats struct {
	TotalFiles     int64
	ProcessedFiles int64
	FailedFiles    int64
	SkippedFiles   int64
}

func main() {
	concurrency := flag.Int("concurrency", 8, "并发处理数")
	flag.Parse()

	fmt.Println("========== 预览图重新生成工具 ==========")
	fmt.Printf("媒体目录: %s\n", mediaDir)
	fmt.Printf("预览图目录: %s\n", previewDir)
	fmt.Printf("预览图尺寸: %d px (最大边)\n", PreviewSize)
	fmt.Printf("并发数: %d\n", *concurrency)
	fmt.Println("=========================================")

	stats := &Stats{}

	// 扫描媒体文件
	log.Println("扫描媒体文件...")
	files, err := scanMediaFiles(mediaDir)
	if err != nil {
		log.Fatalf("扫描失败: %v", err)
	}

	stats.TotalFiles = int64(len(files))
	log.Printf("找到 %d 个媒体文件", len(files))

	// 工作队列
	fileChan := make(chan string, *concurrency*2)

	// 启动工作协程
	var wg sync.WaitGroup
	for i := 0; i < *concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for filePath := range fileChan {
				err := processFile(filePath, stats)
				if err != nil {
					atomic.AddInt64(&stats.FailedFiles, 1)
					log.Printf("[Worker %d] 失败: %s - %v", workerID, filepath.Base(filePath), err)
				} else {
					atomic.AddInt64(&stats.ProcessedFiles, 1)
					log.Printf("[Worker %d] 完成: %s", workerID, filepath.Base(filePath))
				}
			}
		}(i)
	}

	// 分发任务
	for _, file := range files {
		fileChan <- file
	}
	close(fileChan)

	// 等待完成
	wg.Wait()

	// 打印统计
	fmt.Println()
	fmt.Println("========== 处理统计 ==========")
	fmt.Printf("总文件数: %d\n", stats.TotalFiles)
	fmt.Printf("处理成功: %d\n", stats.ProcessedFiles)
	fmt.Printf("处理失败: %d\n", stats.FailedFiles)
	fmt.Printf("跳过文件: %d\n", stats.SkippedFiles)
	fmt.Println("==============================")
}

// scanMediaFiles 扫描媒体目录
func scanMediaFiles(root string) ([]string, error) {
	var files []string

	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			return nil
		}

		ext := strings.ToLower(filepath.Ext(path))
		if model.IsSupportedFile(ext) {
			files = append(files, path)
		}
		return nil
	})

	return files, err
}

// processFile 处理单个文件
func processFile(mediaPath string, stats *Stats) error {
	// 计算相对路径
	relPath, err := filepath.Rel(mediaDir, mediaPath)
	if err != nil {
		return fmt.Errorf("计算相对路径失败: %w", err)
	}

	ext := strings.ToLower(filepath.Ext(mediaPath))
	baseName := strings.TrimSuffix(filepath.Base(mediaPath), ext)
	dirPart := filepath.Dir(relPath)

	// 确定预览图扩展名和路径
	previewExt := ".jpg"
	if ext == ".gif" {
		previewExt = ".gif"
	}
	previewFileName := baseName + "_preview" + previewExt
	previewFullPath := filepath.Join(previewDir, dirPart, previewFileName)

	// 确保目录存在
	if err := os.MkdirAll(filepath.Dir(previewFullPath), 0755); err != nil {
		return fmt.Errorf("创建目录失败: %w", err)
	}

	// 根据文件类型处理
	isVideo := model.IsVideo(ext)
	isGif := ext == ".gif"

	if isVideo {
		return processVideo(mediaPath, previewFullPath)
	} else if isGif {
		return processAnimatedGif(mediaPath, previewFullPath)
	} else {
		return processImage(mediaPath, previewFullPath)
	}
}

// processImage 处理静态图片
func processImage(srcPath, previewPath string) error {
	src, err := imaging.Open(srcPath, imaging.AutoOrientation(true))
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	// 生成预览图 (最大边 256px，保持比例)
	preview := imaging.Fit(src, PreviewSize, PreviewSize, imaging.Lanczos)
	if err := imaging.Save(preview, previewPath, imaging.JPEGQuality(JpegQuality)); err != nil {
		return fmt.Errorf("保存预览图失败: %w", err)
	}

	return nil
}

// processVideo 处理视频
func processVideo(srcPath, previewPath string) error {
	// 获取视频时长
	duration, err := getVideoDuration(srcPath)
	if err != nil {
		duration = 10.0
	}

	// 计算 10% 位置
	seekTime := duration * 0.1
	if seekTime < 0.1 {
		seekTime = 0.1
	}

	// 提取帧到临时文件
	tempFrame := filepath.Join(os.TempDir(), fmt.Sprintf("preview_regen_%d_%s.jpg",
		os.Getpid(), filepath.Base(srcPath)))
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

	return processImage(tempFrame, previewPath)
}

// processAnimatedGif 处理动态 GIF
func processAnimatedGif(srcPath, previewPath string) error {
	file, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("打开 GIF 失败: %w", err)
	}
	defer file.Close()

	gifImg, err := gif.DecodeAll(file)
	if err != nil {
		return fmt.Errorf("解码 GIF 失败: %w", err)
	}

	// 调整 GIF 大小
	previewGif, err := resizeGif(gifImg, PreviewSize, PreviewSize)
	if err != nil {
		return fmt.Errorf("调整 GIF 大小失败: %w", err)
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

// resizeGif 调整 GIF 大小（保持比例）
func resizeGif(g *gif.GIF, maxWidth, maxHeight int) (*gif.GIF, error) {
	if len(g.Image) == 0 {
		return nil, fmt.Errorf("GIF 没有帧")
	}

	// 获取原始尺寸
	bounds := g.Image[0].Bounds()
	origWidth := bounds.Dx()
	origHeight := bounds.Dy()

	// 计算新尺寸（保持比例，最大边为 maxWidth/maxHeight）
	ratio := float64(origWidth) / float64(origHeight)
	var newWidth, newHeight int
	if ratio > 1 {
		newWidth = maxWidth
		newHeight = int(float64(maxWidth) / ratio)
	} else {
		newHeight = maxHeight
		newWidth = int(float64(maxHeight) * ratio)
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
		resized := imaging.Fit(img, newWidth, newHeight, imaging.Lanczos)

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

// getVideoDuration 获取视频时长
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
