package ai

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"strings"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/service/media_probe"
)

// AI 专用派生档：长边 1024 的 JPEG，供 face / ocr / vlm 使用。
//
// 为什么不直接喂原图：原图可能是几十 MB 的 HEIC/PNG，侧车解码慢、显存占用高。
// 为什么不在 256 预览图上放大：放大只是插值噪声，对检测与识别没有增益。
// 所以派生档从**原图**生成（视频先取一帧），按需创建并缓存在 <GALLERY_DIR>/AI/ 下。
//
// 路径由 file_path 确定性推导、不入库：派生档只是可重建的缓存，删掉目录即可全部重来。
const aiTierLongEdge = 1024

// aiTierDirName 是派生档在媒体库根目录下的子目录名。
const aiTierDirName = "AI"

// AITierRelPath 由媒体相对路径推导派生档相对路径。
//
// 沿用与 Preview 一致的“年-月/文件名”约定，便于按月份目录批量清理。
func AITierRelPath(filePath string) string {
	dir, name := filepath.Split(filepath.FromSlash(filePath))
	base := strings.TrimSuffix(name, filepath.Ext(name))
	return filepath.ToSlash(filepath.Join(dir, base+"_ai.jpg"))
}

// AITierAbsPath 返回派生档的绝对路径。
func AITierAbsPath(filePath string) string {
	return filepath.Join(config.AppConf.GalleryDir, aiTierDirName, filepath.FromSlash(AITierRelPath(filePath)))
}

// ensureAITier 为一条媒体准备 AI 档，返回可喂给侧车的绝对路径与**实际使用的档位**。
//
// 已生成则复用；否则从原图（视频先取帧）生成。生成失败时返回错误而不是"退回低档
// 但照样算成功"：ai_results 会如实登记低档，而期望规格仍是 ai1024，reconcile 会
// 判定失配并再次入队——那会变成每分钟重跑一次的永久循环。让任务失败（受
// ai.max_attempts 约束）才能既如实又能收敛。
func (e *Engine) ensureAITier(asset model.MediaAsset) (string, string, error) {
	cached := AITierAbsPath(asset.FilePath)
	if fi, err := os.Stat(cached); err == nil && !fi.IsDir() {
		return cached, model.TierAI1024, nil
	}
	if err := generateAITier(asset, cached); err != nil {
		return "", "", err
	}
	return cached, model.TierAI1024, nil
}

// generateAITier 生成一条媒体的 AI 派生档。
func generateAITier(asset model.MediaAsset, dst string) error {
	src := MediaAbsPath(asset.FilePath)

	img, err := decodeAITierSource(asset, src)
	if err != nil {
		return err
	}
	scaled := scaleLongEdge(img, aiTierLongEdge)

	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return fmt.Errorf("创建派生档目录失败: %w", err)
	}
	// 先写临时文件再改名：避免生成中断留下半张图被当成有效缓存。
	tmp := dst + ".tmp"
	if err := writeJPEG(tmp, scaled); err != nil {
		return err
	}
	return os.Rename(tmp, dst)
}

// decodeAITierSource 取得待缩放的源图：视频取第 1 秒的帧，图片直接解码原图。
func decodeAITierSource(asset model.MediaAsset, src string) (image.Image, error) {
	mime := ""
	if asset.MimeType != nil {
		mime = *asset.MimeType
	}
	if strings.HasPrefix(mime, "video/") {
		raw, err := media_probe.ExtractFrame(asset.ID, src, 1)
		if err != nil {
			return nil, fmt.Errorf("视频取帧失败: %w", err)
		}
		frame, _, err := image.Decode(bytes.NewReader(raw))
		if err != nil {
			return nil, fmt.Errorf("解码视频帧失败: %w", err)
		}
		return frame, nil
	}
	return decodeImage(src)
}

// scaleLongEdge 按长边缩放到 longEdge；本来就不超过长边时原样返回（不放大）。
func scaleLongEdge(src image.Image, longEdge int) image.Image {
	bounds := src.Bounds()
	width, height := bounds.Dx(), bounds.Dy()
	if width <= 0 || height <= 0 {
		return src
	}
	if width <= longEdge && height <= longEdge {
		return src
	}

	targetW, targetH := longEdge, height*longEdge/width
	if height > width {
		targetH, targetW = longEdge, width*longEdge/height
	}
	if targetW < 1 {
		targetW = 1
	}
	if targetH < 1 {
		targetH = 1
	}
	return areaScale(src, targetW, targetH)
}

// areaScale 用面积平均做缩放。
//
// 派生档只做缩小，面积平均（box filter）在这种大比例缩小下既简单又不会产生
// 双三次的过冲与振铃——那类伪影对 OCR 的边缘更不友好。
func areaScale(src image.Image, targetW, targetH int) image.Image {
	bounds := src.Bounds()
	srcW, srcH := bounds.Dx(), bounds.Dy()
	dst := image.NewRGBA(image.Rect(0, 0, targetW, targetH))

	for dy := 0; dy < targetH; dy++ {
		y0 := bounds.Min.Y + dy*srcH/targetH
		y1 := bounds.Min.Y + (dy+1)*srcH/targetH
		if y1 <= y0 {
			y1 = y0 + 1
		}
		for dx := 0; dx < targetW; dx++ {
			x0 := bounds.Min.X + dx*srcW/targetW
			x1 := bounds.Min.X + (dx+1)*srcW/targetW
			if x1 <= x0 {
				x1 = x0 + 1
			}

			var rSum, gSum, bSum, aSum, count uint64
			for y := y0; y < y1; y++ {
				for x := x0; x < x1; x++ {
					r, g, b, a := src.At(x, y).RGBA()
					rSum += uint64(r)
					gSum += uint64(g)
					bSum += uint64(b)
					aSum += uint64(a)
					count++
				}
			}
			if count == 0 {
				continue
			}
			dst.SetRGBA(dx, dy, colorFromAverages(rSum, gSum, bSum, aSum, count))
		}
	}
	return dst
}

func writeJPEG(path string, img image.Image) error {
	f, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("创建派生档失败: %w", err)
	}
	if err := jpeg.Encode(f, img, &jpeg.Options{Quality: 90}); err != nil {
		_ = f.Close()
		return fmt.Errorf("写入派生档失败: %w", err)
	}
	if err := f.Close(); err != nil {
		return fmt.Errorf("关闭派生档失败: %w", err)
	}
	return nil
}

// colorFromAverages 把 RGBA 各通道的 16 位累加值取平均并降回 8 位。
func colorFromAverages(rSum, gSum, bSum, aSum, count uint64) color.RGBA {
	return color.RGBA{
		R: uint8(rSum / count >> 8),
		G: uint8(gSum / count >> 8),
		B: uint8(bSum / count >> 8),
		A: uint8(aSum / count >> 8),
	}
}
