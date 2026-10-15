package processor

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/gif"
	"image/png"
	"os"
	"path/filepath"
	"strings"

	"github.com/disintegration/imaging"
)

// ImageEditParams 的裁切坐标属于未旋转、已校正 EXIF 方向的原图；rotation 为逆时针角度。
type ImageEditParams struct {
	Type       string `json:"type"`
	Rotation   int    `json:"rotation"`
	CropLeft   int    `json:"crop_left"`
	CropTop    int    `json:"crop_top"`
	CropRight  int    `json:"crop_right"`
	CropBottom int    `json:"crop_bottom"`
}

// ApplyImageEdit 保持原格式，写入新文件；无操作时返回 ErrNoOp。
func ApplyImageEdit(srcPath, dstPath, editParamsJSON string) error {
	var params ImageEditParams
	if err := json.Unmarshal([]byte(editParamsJSON), &params); err != nil {
		return fmt.Errorf("解析编辑参数失败: %w", err)
	}
	if params.Type != "image" {
		return fmt.Errorf("非图片编辑参数: %s", params.Type)
	}
	if params.Rotation%90 != 0 {
		return fmt.Errorf("旋转角度必须为 90 度的整数倍")
	}
	if strings.EqualFold(filepath.Ext(srcPath), ".gif") {
		return editGIF(srcPath, dstPath, params)
	}
	if strings.EqualFold(filepath.Ext(srcPath), ".webp") {
		file, err := os.Open(srcPath)
		if err != nil {
			return err
		}
		var header [21]byte
		n, _ := file.ReadAt(header[:], 0)
		file.Close()
		if n == len(header) && string(header[:4]) == "RIFF" && string(header[8:12]) == "WEBP" && string(header[12:16]) == "VP8X" && header[20]&2 != 0 {
			return fmt.Errorf("暂不支持动态 WebP 编辑，原文件保持不变")
		}
	}
	src, err := openImageWithFallback(srcPath)
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}
	crop, rotation, err := imageEditRegion(params, src.Bounds())
	if err != nil {
		return err
	}
	src = imaging.Crop(src, crop)
	src = rotateImage(src, rotation)
	if strings.EqualFold(filepath.Ext(dstPath), ".webp") {
		temp, err := tempFilePath("gallery_webp_", ".png")
		if err != nil {
			return err
		}
		defer os.Remove(temp)
		if err := imaging.Save(src, temp); err != nil {
			return err
		}
		if output, err := runFFmpeg("-y", "-i", temp, "-frames:v", "1", "-c:v", "libwebp", "-lossless", "1", dstPath); err != nil {
			return fmt.Errorf("保存 WebP 失败: %w, %s", err, output)
		}
		return nil
	}
	if err := imaging.Save(src, dstPath, imaging.JPEGQuality(JpegQuality), imaging.PNGCompressionLevel(png.DefaultCompression)); err != nil {
		return fmt.Errorf("保存编辑后的图片失败: %w", err)
	}
	return nil
}

func imageEditRegion(params ImageEditParams, bounds image.Rectangle) (image.Rectangle, int, error) {
	rotation := (params.Rotation%360 + 360) % 360
	right, bottom := params.CropRight, params.CropBottom
	if right <= 0 {
		right = bounds.Max.X
	}
	if bottom <= 0 {
		bottom = bounds.Max.Y
	}
	left, top := max(bounds.Min.X, params.CropLeft), max(bounds.Min.Y, params.CropTop)
	right, bottom = min(bounds.Max.X, right), min(bounds.Max.Y, bottom)
	if left >= right || top >= bottom {
		return image.Rectangle{}, 0, fmt.Errorf("裁切区域超出原图或为空")
	}
	crop := image.Rect(left, top, right, bottom)
	if crop == bounds && rotation == 0 {
		return crop, rotation, ErrNoOp
	}
	return crop, rotation, nil
}

func rotateImage(src image.Image, rotation int) image.Image {
	switch rotation {
	case 90:
		return imaging.Rotate90(src)
	case 180:
		return imaging.Rotate180(src)
	case 270:
		return imaging.Rotate270(src)
	default:
		return src
	}
}

// GIF 的增量帧保留各自的调色板、偏移和清除方式，逐像素变换不会丢失动画。
func editGIF(srcPath, dstPath string, params ImageEditParams) error {
	file, err := os.Open(srcPath)
	if err != nil {
		return err
	}
	animation, err := gif.DecodeAll(file)
	file.Close()
	if err != nil {
		return fmt.Errorf("解码 GIF 失败: %w", err)
	}
	crop, rotation, err := imageEditRegion(params, image.Rect(0, 0, animation.Config.Width, animation.Config.Height))
	if err != nil {
		return err
	}
	width, height := crop.Dx(), crop.Dy()
	point := func(x, y int) (int, int) {
		x -= crop.Min.X
		y -= crop.Min.Y
		switch rotation {
		case 90:
			return y, width - 1 - x
		case 180:
			return width - 1 - x, height - 1 - y
		case 270:
			return height - 1 - y, x
		default:
			return x, y
		}
	}
	if len(animation.Disposal) == 0 {
		animation.Disposal = make([]byte, len(animation.Image))
	}
	for i, frame := range animation.Image {
		region := frame.Bounds().Intersect(crop)
		if region.Empty() {
			animation.Image[i] = image.NewPaletted(image.Rect(0, 0, 1, 1), color.Palette{color.Transparent})
			animation.Disposal[i] = gif.DisposalNone
			continue
		}
		x0, y0 := point(region.Min.X, region.Min.Y)
		x1, y1 := point(region.Max.X-1, region.Max.Y-1)
		result := image.NewPaletted(image.Rect(min(x0, x1), min(y0, y1), max(x0, x1)+1, max(y0, y1)+1), frame.Palette)
		for y := region.Min.Y; y < region.Max.Y; y++ {
			for x := region.Min.X; x < region.Max.X; x++ {
				nx, ny := point(x, y)
				result.SetColorIndex(nx, ny, frame.ColorIndexAt(x, y))
			}
		}
		animation.Image[i] = result
	}
	if rotation%180 != 0 {
		width, height = height, width
	}
	animation.Config.Width = width
	animation.Config.Height = height
	return writeGif(dstPath, animation)
}
