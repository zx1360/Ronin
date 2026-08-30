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
//
// 契约（与 Android 端 ImageEditorPage 对齐）：
//   - 裁切坐标始终是**原始图片（未旋转）的像素坐标**；
//   - 处理流程：先旋转，再裁切 —— 本函数会把原始坐标换算到旋转后的
//     坐标系再执行裁剪（`imaging.Rotate90` 为逆时针旋转，与 Android 端一致）；
//   - 旋转与裁切均为无操作时返回 ErrNoOp（调用方仅清除 edit_params，不动文件）。
func ApplyImageEdit(srcPath, dstPath string, editParamsJSON string) error {
	var params ImageEditParams
	if err := json.Unmarshal([]byte(editParamsJSON), &params); err != nil {
		return fmt.Errorf("解析编辑参数失败: %w", err)
	}

	if params.Type != "image" {
		return fmt.Errorf("非图片编辑参数: %s", params.Type)
	}

	// 打开源图片（原生解码失败时自动 ffmpeg 后备；AutoOrientation 与
	// Android 端解码行为一致，保证两端处于同一"已校正 EXIF 方向"的像素空间）
	proc := &Processor{ffmpegPath: "ffmpeg"}
	src, err := proc.openImageWithFallback(srcPath)
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	// 原始尺寸（旋转前），裁切坐标的参照系
	origW := src.Bounds().Dx()
	origH := src.Bounds().Dy()

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

	// 旋转后的尺寸
	rotW := src.Bounds().Dx()
	rotH := src.Bounds().Dy()

	// 2. 归一化原始空间的裁切参数（默认全幅）
	cl := params.CropLeft
	ct := params.CropTop
	cr := params.CropRight
	cb := params.CropBottom
	if cl < 0 {
		cl = 0
	}
	if ct < 0 {
		ct = 0
	}
	if cr <= 0 || cr > origW {
		cr = origW
	}
	if cb <= 0 || cb > origH {
		cb = origH
	}

	// 是否真的需要裁切（相比原图全幅是否发生了变化）
	hasCrop := cl > 0 || ct > 0 || cr < origW || cb < origH

	// 无旋转且无裁切 → 无操作
	if rotation == 0 && !hasCrop {
		return ErrNoOp
	}

	// 3. 把原始坐标换算到旋转后坐标系（半开区间 [left, right) x [top, bottom)）
	//    - 90° 逆时针:  (x, y) -> (y, origW - x)
	//    - 180°:        (x, y) -> (origW - x, origH - y)
	//    - 270° 逆时针:  (x, y) -> (origH - y, x)
	if hasCrop && cl < cr && ct < cb {
		var nl, nt, nr, nb int
		switch rotation {
		case 90:
			nl, nt, nr, nb = ct, origW-cr, cb, origW-cl
		case 180:
			nl, nt, nr, nb = origW-cr, origH-cb, origW-cl, origH-ct
		case 270:
			nl, nt, nr, nb = origH-cb, cl, origH-ct, cr
		default:
			nl, nt, nr, nb = cl, ct, cr, cb
		}

		// 边界保护 + 排除"恰好等于旋转后全幅"的情况
		if nl < 0 {
			nl = 0
		}
		if nt < 0 {
			nt = 0
		}
		if nr > rotW {
			nr = rotW
		}
		if nb > rotH {
			nb = rotH
		}
		if nl < nr && nt < nb && (nl != 0 || nt != 0 || nr != rotW || nb != rotH) {
			src = imaging.Crop(src, image.Rect(nl, nt, nr, nb))
		}
	}

	// 4. 编码保存，保持原格式
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
