package ai

import (
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"testing"

	"github.com/disintegration/imaging"
	"github.com/google/uuid"

	"monarch/internal/config"
	"monarch/internal/model"
)

// writePlainJPEG 生成一张指定尺寸的测试图。
func writePlainJPEG(t *testing.T, path string, width, height int) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatalf("创建测试目录失败: %v", err)
	}
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.Set(x, y, color.RGBA{R: uint8(x % 256), G: uint8(y % 256), B: 128, A: 255})
		}
	}
	file, err := os.Create(path)
	if err != nil {
		t.Fatalf("创建测试图失败: %v", err)
	}
	defer file.Close()
	if err := jpeg.Encode(file, img, nil); err != nil {
		t.Fatalf("编码测试图失败: %v", err)
	}
}

// TestResolveSourceGeneratesAITier 1024 档缺失时按需生成并缓存：
// 首次生成、再次命中缓存，且长边压到 1024（不放大）。
func TestResolveSourceGeneratesAITier(t *testing.T) {
	gallery := t.TempDir()
	config.AppConf.GalleryDir = gallery

	preview := filepath.Join(gallery, "Preview", "2022-06", "sample_preview.jpg")
	writePlainJPEG(t, preview, 2400, 1800)
	paths := mediaPaths{Preview: preview}

	source, err := resolveSource(paths, model.TierAI, uuid.Nil)
	if err != nil {
		t.Fatalf("解析 AI 档失败: %v", err)
	}
	if source.Tier != model.TierAI {
		t.Fatalf("应使用 AI 档，实际 %q", source.Tier)
	}

	derived := filepath.Join(gallery, "AI", "2022-06", "sample_ai.jpg")
	if source.Path != derived {
		t.Fatalf("派生路径不符: got %q, want %q", source.Path, derived)
	}
	if !fileExists(derived) {
		t.Fatal("应按需生成 1024 派生图")
	}
	info, err := os.Stat(derived)
	if err != nil || info.Size() == 0 {
		t.Fatalf("派生图不可用: %v size=%d", err, info.Size())
	}

	img, err := imaging.Open(derived)
	if err != nil {
		t.Fatalf("派生图无法解码: %v", err)
	}
	bounds := img.Bounds()
	if bounds.Dx() != aiImageSize || bounds.Dy() != aiImageSize*3/4 {
		t.Fatalf("派生图尺寸不符（应为长边 1024）：%dx%d", bounds.Dx(), bounds.Dy())
	}

	// 第二次应直接命中缓存（不再生成）
	cached, err := resolveSource(paths, model.TierAI, uuid.Nil)
	if err != nil || cached.Path != derived || cached.Tier != model.TierAI {
		t.Fatalf("缓存命中失败: %+v err=%v", cached, err)
	}
}

// TestResolveSourcePreviewTier 256 档直接取预览图，且不做任何生成。
func TestResolveSourcePreviewTier(t *testing.T) {
	gallery := t.TempDir()
	config.AppConf.GalleryDir = gallery

	preview := filepath.Join(gallery, "Preview", "2022-06", "sample_preview.jpg")
	writePlainJPEG(t, preview, 256, 192)
	paths := mediaPaths{Preview: preview}

	source, err := resolveSource(paths, model.TierPreview, uuid.Nil)
	if err != nil {
		t.Fatalf("解析 256 档失败: %v", err)
	}
	if source.Tier != model.TierPreview {
		t.Fatalf("档位不符: %q", source.Tier)
	}
	if _, err := os.Stat(filepath.Join(gallery, "AI")); !os.IsNotExist(err) {
		t.Fatal("256 档不应生成 AI 派生图")
	}
}

// TestResolveSourcePrefersOriginal 生成源优先原图：
// 用 256 预览档生成只能得到 256 长边，必须从原图得到真正的 1024 档。
func TestResolveSourcePrefersOriginal(t *testing.T) {
	gallery := t.TempDir()
	config.AppConf.GalleryDir = gallery

	// 预览档很小、原图很大，用长宽比区分生成源
	preview := filepath.Join(gallery, "Preview", "2022-06", "pic_preview.jpg")
	writePlainJPEG(t, preview, 256, 256)
	original := filepath.Join(gallery, "Media", "2022-06", "pic.png")
	writePlainJPEG(t, original, 2400, 1200)

	paths := mediaPaths{
		Preview: preview,
		Media:   original,
	}
	source, err := resolveSource(paths, model.TierAI, uuid.Nil)
	if err != nil {
		t.Fatalf("解析 AI 档失败: %v", err)
	}
	if source.Tier != model.TierAI {
		t.Fatalf("应使用 AI 档，实际 %q", source.Tier)
	}

	img, err := imaging.Open(source.Path)
	if err != nil {
		t.Fatalf("派生图无法解码: %v", err)
	}
	bounds := img.Bounds()
	if bounds.Dx() != aiImageSize || bounds.Dy() != aiImageSize/2 {
		t.Fatalf("应从原图生成 1024 档（2:1），实际 %dx%d", bounds.Dx(), bounds.Dy())
	}
}

// TestResolveSourceFallsBackWhenNoImage 图源全部缺失时报告不可用，
// 而不是把原图当作推理输入。
func TestResolveSourceFallsBackWhenNoImage(t *testing.T) {
	config.AppConf.GalleryDir = t.TempDir()
	if _, err := resolveSource(mediaPaths{}, model.TierAI, uuid.Nil); err == nil {
		t.Fatal("无图源时应报错")
	}
}
