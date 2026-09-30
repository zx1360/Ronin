package ai

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/jpeg"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/disintegration/imaging"
	"github.com/google/uuid"

	// 标准库解码器必须显式注册，imaging 才会认这些格式
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/service/media_probe"
)

// AI 专用派生档（长边 1024）的生成与缓存。
//
// 该档复用 gallery 既有的 GALLERY_DIR/AI 目录与 `*_ai.jpg` 命名（与 Preview/Thumbs
// 同构：按 `年-月/基础名_ai.jpg` 存放），不新增档位、不写数据库、不改 media_assets。
// 媒体入库时不会生成它，因此这里按需生成并落盘缓存；命中判断只是一次 stat。

const (
	// aiImageSize AI 专用档的长边像素。
	aiImageSize = 1024
	// aiImageQuality 派生图 JPEG 质量（与 gallery 派生图一致）。
	aiImageQuality = 85
)

// errAIUnavailable 无任何可用的图源。
var errAIUnavailable = errors.New("无可用图源")

// mediaPaths 一个媒体的派生图与原始文件路径（不存在时为空串）。
type mediaPaths struct {
	Preview string
	Thumb   string
	Media   string
}

// sourceImage 一个已就绪、可直接推理的图源。
type sourceImage struct {
	Path string
	Tier string // 实际档位（可能在 AI 档生成失败后退回 256 档）
}

// resolveSource 解析某媒体在指定档位下的推理图源。
//
// phash/embed 用 preview256；face/ocr/vlm 用 ai1024（缺失时按需生成并缓存，
// 生成失败退回 256 档——质量次一档但可用，绝不因此让整条任务失败）。
//
// 原始文件只在"连 256 档都没有"时作为生成 ai1024 的源，绝不直接喂给推理：
// 否则 pHash 会来自不同分辨率的图源，同一张图在不同时期入库会算出不同的哈希。
func resolveSource(paths mediaPaths, tier string, mediaID uuid.UUID) (sourceImage, error) {
	if tier == model.TierAI {
		if aiPath, generated := ensureAIImage(paths, mediaID); aiPath != "" {
			return sourceImage{Path: aiPath, Tier: tierOrFallback(generated, tier)}, nil
		}
	}
	if paths.Preview != "" && fileExists(paths.Preview) {
		return sourceImage{Path: paths.Preview, Tier: model.TierPreview}, nil
	}
	if paths.Thumb != "" && fileExists(paths.Thumb) {
		return sourceImage{Path: paths.Thumb, Tier: model.TierPreview}, nil
	}
	if paths.Media != "" && fileExists(paths.Media) {
		return sourceImage{Path: paths.Media, Tier: model.TierPreview}, nil
	}
	return sourceImage{}, errAIUnavailable
}

// tierOrFallback 生成成功时返回目标档位，退回时返回 256 档。
func tierOrFallback(generated bool, tier string) string {
	if generated {
		return tier
	}
	return model.TierPreview
}

// ensureAIImage 返回 ai1024 档的可用路径；缺失时生成。第二个返回值为"是否确为 AI 档"。
func ensureAIImage(paths mediaPaths, mediaID uuid.UUID) (string, bool) {
	dst := aiDerivedPath(paths)
	if dst == "" {
		return "", false
	}
	if fileExists(dst) {
		return dst, true
	}
	if err := generateAIImage(paths, dst, mediaID); err != nil {
		log.Printf("[AI] 生成 1024 派生图失败（本张退回 256 档）: %v", err)
		return "", false
	}
	return dst, true
}

// aiDerivedPath 由既有派生图路径推导 AI 档路径；无法推导时返回空串。
//
// 目录沿用 Preview/Thumbs 的相对目录（`年-月`），文件名用去 `_preview`/`_thumb`
// 后缀的基础名 + `_ai.jpg`，与库内既有 6.9 万张派生图完全一致。
func aiDerivedPath(paths mediaPaths) string {
	// 预览根目录：传入的可能是相对路径（媒体表里的形式），也可能是绝对路径
	// （测试或调用方自行拼接），统一按预览根目录折算，避免把盘符当成目录名。
	previewRoot := filepath.Join(config.AppConf.GalleryDir, "Preview")
	base := ""
	for _, candidate := range []string{paths.Preview, paths.Thumb} {
		if candidate == "" {
			continue
		}
		rel, err := filepath.Rel(previewRoot, candidate)
		if err != nil || strings.HasPrefix(rel, "..") {
			// 不是预览根目录下的路径：按相对路径处理（媒体表里存的就是相对路径）
			rel = candidate
		}
		base = rel
		break
	}
	if base == "" {
		return ""
	}

	dir := filepath.Dir(base)
	name := filepath.Base(base)
	stem := strings.TrimSuffix(name, filepath.Ext(name))
	for _, suffix := range []string{"_preview", "_thumb"} {
		if strings.HasSuffix(stem, suffix) {
			stem = strings.TrimSuffix(stem, suffix)
			break
		}
	}
	return filepath.Join(config.AppConf.GalleryDir, "AI", dir, stem+"_ai.jpg")
}

// generateAIImage 生成 AI 专用档（长边 aiImageSize，保持比例，JPEG）。
//
// 源图优先取**原图**：库内既有的 6.9 万张 `*_ai.jpg` 都是 1024 长边的，若用 256 预览档
// 生成只能得到 256 长边（Fit 不放大），人脸与文字识别的质量会明显低于既有产物。
// 原图无法解码（HEIC 等非常规格式、损坏文件）时才依次回退到预览档与缩略图，
// 视频则用 ffmpeg 取一帧。动图按首帧处理——GIF 无法交给识别模型。
func generateAIImage(paths mediaPaths, dst string, mediaID uuid.UUID) error {
	var candidates []string
	for _, src := range []string{paths.Media, paths.Preview, paths.Thumb} {
		if src != "" && fileExists(src) {
			candidates = append(candidates, src)
		}
	}
	if len(candidates) == 0 {
		return errAIUnavailable
	}

	var lastErr error
	for _, src := range candidates {
		if err := writeAIImage(src, dst); err != nil {
			lastErr = err
			continue
		}
		return nil
	}
	// 视频：预览档本已由入库流程取过帧，走到这里说明它也无法解码，只好再取一次原片
	frame, err := extractVideoFrame(mediaID, paths.Media)
	if err != nil {
		return fmt.Errorf("源图均无法解码: %w", lastErr)
	}
	if err := writeAIImageBytes(frame, dst); err != nil {
		return fmt.Errorf("写入视频帧失败: %w", err)
	}
	return nil
}

// writeAIImage 解码 src 并写出 AI 专用档。
func writeAIImage(src, dst string) error {
	img, err := imaging.Open(src, imaging.AutoOrientation(true))
	if err != nil {
		return err
	}
	return saveAIImage(imaging.Fit(img, aiImageSize, aiImageSize, imaging.Lanczos), dst)
}

// writeAIImageBytes 把已编码的图片字节（ffmpeg 取出的帧）转成 AI 专用档。
func writeAIImageBytes(raw []byte, dst string) error {
	img, err := imaging.Decode(bytes.NewReader(raw), imaging.AutoOrientation(true))
	if err != nil {
		return err
	}
	return saveAIImage(imaging.Fit(img, aiImageSize, aiImageSize, imaging.Lanczos), dst)
}

// saveAIImage 原子落盘：先写临时文件再改名，避免中断留下半张图被当作有效缓存。
//
// 显式按 JPEG 编码而不让 imaging 从扩展名猜格式：临时文件名是 .tmp，
// 靠扩展名推断会直接报"unsupported image format"。
func saveAIImage(img image.Image, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return fmt.Errorf("创建 AI 派生图目录失败: %w", err)
	}
	tmp := dst + ".tmp"
	file, err := os.Create(tmp)
	if err != nil {
		return fmt.Errorf("创建 AI 派生图失败: %w", err)
	}
	if err := jpeg.Encode(file, img, &jpeg.Options{Quality: aiImageQuality}); err != nil {
		file.Close()
		_ = os.Remove(tmp)
		return fmt.Errorf("编码 AI 派生图失败: %w", err)
	}
	if err := file.Close(); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("写入 AI 派生图失败: %w", err)
	}
	if err := os.Rename(tmp, dst); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("保存 AI 派生图失败: %w", err)
	}
	return nil
}

// extractVideoFrame 用 ffmpeg 取视频 10% 位置的一帧（与 gallery 派生图的取帧位置一致）。
func extractVideoFrame(mediaID uuid.UUID, src string) ([]byte, error) {
	if src == "" || !fileExists(src) {
		return nil, errAIUnavailable
	}
	info, err := media_probe.ProbeVideo(mediaID, src)
	if err != nil {
		return nil, err
	}
	sec := float64(info.DurationMs) / 1000 * 0.1
	if sec < 0.1 {
		sec = 0.1
	}
	return media_probe.ExtractFrame(mediaID, src, sec)
}

// fileExists 报告路径存在且是普通文件。
func fileExists(path string) bool {
	fi, err := os.Stat(path)
	return err == nil && !fi.IsDir()
}
