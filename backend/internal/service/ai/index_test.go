package ai

import (
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"testing"

	"github.com/google/uuid"
)

func TestHammingDistance(t *testing.T) {
	cases := []struct {
		a, b int64
		want int
	}{
		{0, 0, 0},
		{0, -1, 64}, // int64(-1) 全 1
		{1, 0, 1},
		{0b1011, 0b1001, 1},
	}
	for _, tc := range cases {
		if got := HammingDistance(tc.a, tc.b); got != tc.want {
			t.Errorf("HammingDistance(%b,%b)=%d, want %d", tc.a, tc.b, got, tc.want)
		}
	}
}

// 连通分量可能链式膨胀：A~B、B~C 但 A 与 C 相差很远。
// splitByRepresentative 把分量切成星形簇——契约是"每个成员与簇代表的距离在阈值内"，
// 因此簇直径上界为 2×阈值（而不是无界的链式传递）。
func TestSplitByRepresentativeBreaksChains(t *testing.T) {
	a, b, c := uuid.New(), uuid.New(), uuid.New()

	// a~b 差 1 位、b~c 差 1 位、a~c 差 2 位；阈值取 1 时三者仍连通。
	hashes := map[uuid.UUID]int64{a: 0, b: 1, c: 3}

	clusters := splitByRepresentative([]uuid.UUID{a, b, c}, hashes, 1)
	total := 0
	for _, cluster := range clusters {
		total += len(cluster)
		representative := cluster[0]
		for _, member := range cluster[1:] {
			if d := HammingDistance(hashes[representative], hashes[member]); d > 1 {
				t.Fatalf("成员 %v 距代表 %d 位，超过阈值", member, d)
			}
		}
	}
	if total != 3 {
		t.Fatalf("拆分后成员总数 %d，应等于 3（不能丢数据）", total)
	}
}

// 链式场景下拆出的簇直径必须有界——这正是修复前"12 张截图挤成一组、
// 组内最大差异 14 位"的根因。
func TestSplitByRepresentativeBoundsDiameter(t *testing.T) {
	const maxDistance = 2
	ids := []uuid.UUID{uuid.New(), uuid.New(), uuid.New(), uuid.New(), uuid.New()}
	// 依次相差 2 位：0, 3, 6, 12, 24 —— 相邻连边成立，首尾相距很远
	hashes := map[uuid.UUID]int64{}
	for i, id := range ids {
		hashes[id] = int64(3 * ((1 << i) - 1))
	}

	for _, cluster := range splitByRepresentative(ids, hashes, maxDistance) {
		for i := 0; i < len(cluster); i++ {
			for j := i + 1; j < len(cluster); j++ {
				if d := HammingDistance(hashes[cluster[i]], hashes[cluster[j]]); d > 2*maxDistance {
					t.Fatalf("簇直径 %d 超过 2×阈值 %d", d, 2*maxDistance)
				}
			}
		}
	}
}

func TestSplitByRepresentativeKeepsTightGroup(t *testing.T) {
	ids := []uuid.UUID{uuid.New(), uuid.New(), uuid.New()}
	hashes := map[uuid.UUID]int64{ids[0]: 0, ids[1]: 1, ids[2]: 2}

	clusters := splitByRepresentative(ids, hashes, 4)
	if len(clusters) != 1 || len(clusters[0]) != 3 {
		t.Fatalf("紧密的一组应保持为一个簇，得到 %v", clusters)
	}
}

// 量化 → 反量化后应保持向量方向（余弦接近 1）。
func TestQuantizeInt8PreservesDirection(t *testing.T) {
	original := []float32{0.1, -0.4, 0.9, 0.2, -0.05, 0.33}
	raw, scale, _ := QuantizeInt8(original)

	restored := make([]float32, len(raw))
	for i, b := range raw {
		restored[i] = float32(int8(b)) * scale
	}
	if score := cosine(restoreNormalize(original), restoreNormalize(restored)); score < 0.99 {
		t.Fatalf("量化后余弦相似度 %.4f，过低", score)
	}
}

// pHash 对同一张图的缩放/重编码应给出很小的距离，对不同图应给出很大的距离。
//
// 测试图用平滑内容（近似照片）：phash 只保留 8×8 低频，硬边或单像素宽的线条在
// 2× 降采样下会走样，属于感知哈希的固有限制，不能拿来做基准。
func TestComputePHashStableAcrossResize(t *testing.T) {
	dir := t.TempDir()
	pattern := filepath.Join(dir, "pattern.png")
	reencoded := filepath.Join(dir, "pattern.jpg")
	scaled := filepath.Join(dir, "pattern_small.png")
	other := filepath.Join(dir, "other.png")

	blobs := func(x, y, n int) color.Color {
		fx := float64(x) / float64(n)
		fy := float64(y) / float64(n)
		d1 := math.Exp(-((fx-0.3)*(fx-0.3) + (fy-0.35)*(fy-0.35)) / 0.05)
		d2 := math.Exp(-((fx-0.7)*(fx-0.7) + (fy-0.65)*(fy-0.65)) / 0.08)
		base := 60 + 120*d1 + 80*d2 + 12*math.Sin(fx*18)*math.Cos(fy*14)
		v := uint8(math.Max(0, math.Min(255, base)))
		return color.RGBA{R: v, G: uint8(float64(v) * 0.9), B: uint8(float64(v) * 0.8), A: 255}
	}

	writeTestImage(t, pattern, 64, 64, func(x, y int) color.Color { return blobs(x, y, 64) })
	writeTestImage(t, scaled, 32, 32, func(x, y int) color.Color { return blobs(x, y, 32) })
	writeTestJPEG(t, reencoded, 64, 64, func(x, y int) color.Color { return blobs(x, y, 64) }, 70)
	writeTestImage(t, other, 64, 64, func(x, y int) color.Color {
		if (x/8+y/8)%2 == 0 {
			return color.RGBA{R: 255, A: 255}
		}
		return color.RGBA{B: 255, A: 255}
	})

	hashA := ComputePHash(pattern)
	if hashA == PHashUnavailable {
		t.Fatal("正常图片不应返回 PHashUnavailable")
	}

	if d := HammingDistance(hashA, ComputePHash(scaled)); d > 6 {
		t.Fatalf("同一张图缩放后距离 %d，过大", d)
	}
	if d := HammingDistance(hashA, ComputePHash(reencoded)); d > 6 {
		t.Fatalf("同一张图重编码后距离 %d，过大", d)
	}
	if d := HammingDistance(hashA, ComputePHash(other)); d < 12 {
		t.Fatalf("明显不同的图距离仅 %d，区分度不足", d)
	}
}

func TestComputePHashHandlesUndecodableFile(t *testing.T) {
	dir := t.TempDir()
	broken := filepath.Join(dir, "broken.jpg")
	if err := os.WriteFile(broken, []byte("not an image"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := ComputePHash(broken); got != PHashUnavailable {
		t.Fatalf("无法解码的文件应返回 PHashUnavailable，得到 %d", got)
	}
}

func writeTestImage(t *testing.T, path string, width, height int, at func(x, y int) color.Color) {
	t.Helper()
	writeTestEncoded(t, path, width, height, at, nil)
}

func writeTestJPEG(t *testing.T, path string, width, height int, at func(x, y int) color.Color, quality int) {
	t.Helper()
	writeTestEncoded(t, path, width, height, at, &jpeg.Options{Quality: quality})
}

func writeTestEncoded(t *testing.T, path string, width, height int, at func(x, y int) color.Color, jpegOptions *jpeg.Options) {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.Set(x, y, at(x, y))
		}
	}
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()

	if jpegOptions != nil {
		if err := jpeg.Encode(file, img, jpegOptions); err != nil {
			t.Fatal(err)
		}
		return
	}
	if err := png.Encode(file, img); err != nil {
		t.Fatal(err)
	}
}

func restoreNormalize(vec []float32) []float32 {
	return normalize(vec)
}
