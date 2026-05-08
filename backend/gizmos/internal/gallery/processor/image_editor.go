package processor

import (
	"encoding/json"
	"fmt"
	"image"
	"image/png"
	"log"
	"path/filepath"
	"strings"

	"github.com/disintegration/imaging"
	_ "golang.org/x/image/webp"
)

// ImageEditParams 图片编辑参数
type ImageEditParams struct {
	Type       string `json:"type"`
	Rotation   int    `json:"rotation"`
	CropLeft   int    `json:"crop_left"`
	CropTop    int    `json:"crop_top"`
	CropRight  int    `json:"crop_right"`
	CropBottom int    `json:"crop_bottom"`
}

// ApplyImageEdit 对图片应用旋转和裁切，结果写入 dstPath
// crop 坐标是应用 rotation 后的显示坐标；处理流程：先旋转再裁切
func ApplyImageEdit(srcPath, dstPath string, editParamsJSON string) error {
	var params ImageEditParams
	if err := json.Unmarshal([]byte(editParamsJSON), &params); err != nil {
		return fmt.Errorf("解析编辑参数失败: %w", err)
	}

	if params.Type != "image" {
		return fmt.Errorf("非图片编辑参数: %s", params.Type)
	}

	// 打开源图片（原生解码失败时自动 ffmpeg 后备）
	proc := &Processor{ffmpegPath: "ffmpeg"}
	src, err := proc.openImageWithFallback(srcPath)
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	// 1. 旋转
	rotation := params.Rotation % 360
	if rotation < 0 {
		rotation += 360
	}
	switch rotation {
	case 90:
		src = imaging.Rotate90(src)
	case 180:
		src = imaging.Rotate180(src)
	case 270:
		src = imaging.Rotate270(src)
	}

	// 2. 裁切（坐标是旋转后的显示坐标）
	bounds := src.Bounds()
	imgW := bounds.Dx()
	imgH := bounds.Dy()

	cl := params.CropLeft
	ct := params.CropTop
	cr := params.CropRight
	cb := params.CropBottom

	// 如果裁切参数有效（不全为 0 且不超出范围）
	if cl > 0 || ct > 0 || (cr > 0 && cr < imgW) || (cb > 0 && cb < imgH) {
		// 边界保护
		if cl < 0 {
			cl = 0
		}
		if ct < 0 {
			ct = 0
		}
		if cr <= 0 || cr > imgW {
			cr = imgW
		}
		if cb <= 0 || cb > imgH {
			cb = imgH
		}
		if cl < cr && ct < cb && (cl != 0 || ct != 0 || cr != imgW || cb != imgH) {
			cropRect := image.Rect(cl, ct, cr, cb)
			src = imaging.Crop(src, cropRect)
		}
	}

	// 3. 编码保存，保持原格式
	ext := strings.ToLower(filepath.Ext(dstPath))
	switch ext {
	case ".png":
		err = imaging.Save(src, dstPath, imaging.PNGCompressionLevel(png.DefaultCompression))
	case ".gif", ".webp", ".bmp", ".tiff", ".tif":
		// 转为 JPEG 保存（这些格式可能不支持 imaging.Save 的特定选项）
		err = imaging.Save(src, dstPath, imaging.JPEGQuality(JpegQuality))
		log.Printf("非主流格式 %s 已转为 JPEG 保存: %s", ext, filepath.Base(dstPath))
	default:
		// 默认 JPEG
		err = imaging.Save(src, dstPath, imaging.JPEGQuality(JpegQuality))
	}

	if err != nil {
		return fmt.Errorf("保存编辑后的图片失败: %w", err)
	}

	return nil
}
