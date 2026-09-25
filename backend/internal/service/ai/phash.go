package ai

import (
	"fmt"
	"image"
	"math"
	"os"
	"sort"

	// 侧车统一输出 JPEG；GIF 取首帧。二者均只需标准库解码器。
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
)

// PHashUnavailable 表示图像无法解码：同样落库，避免每次 reconcile 重复尝试。
const PHashUnavailable int64 = -1

const phashSide = 32 // DCT 输入边长
const phashLow = 8   // 取低频 8×8 块

// ComputePHash 计算图片的感知哈希（DCT pHash，64 位）。
//
// 解码失败返回 PHashUnavailable 而非错误：这类文件（损坏、异常格式）
// 应被标记为"已处理"，否则会永远滞留在队列里反复重试。
func ComputePHash(path string) int64 {
	img, err := decodeImage(path)
	if err != nil {
		return PHashUnavailable
	}

	gray := toGrayGrid(img)
	dct := dct2D(gray)

	vals := make([]float64, 0, phashLow*phashLow-1)
	for u := 0; u < phashLow; u++ {
		for v := 0; v < phashLow; v++ {
			if u == 0 && v == 0 {
				continue // 直流分量只反映整体亮度，不参与比较
			}
			vals = append(vals, dct[u][v])
		}
	}

	median := medianOf(vals)
	var hash uint64
	for i, v := range vals {
		if v > median {
			hash |= 1 << uint(63-i)
		}
	}
	return int64(hash)
}

// HammingDistance 返回两个感知哈希的汉明距离（越小越相似）。
func HammingDistance(a, b int64) int {
	return popcount(uint64(a) ^ uint64(b))
}

// decodeImage 打开并解码图片文件。
func decodeImage(path string) (image.Image, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("打开图片失败: %w", err)
	}
	defer f.Close()

	img, _, err := image.Decode(f)
	if err != nil {
		return nil, fmt.Errorf("解码图片失败: %w", err)
	}
	return img, nil
}

// toGrayGrid 把图片按面积平均缩放为 phashSide × phashSide 的灰度矩阵（0..1）。
func toGrayGrid(img image.Image) *[phashSide][phashSide]float64 {
	bounds := img.Bounds()
	width, height := bounds.Dx(), bounds.Dy()

	var grid [phashSide][phashSide]float64
	if width <= 0 || height <= 0 {
		return &grid
	}

	for ty := 0; ty < phashSide; ty++ {
		y0 := bounds.Min.Y + ty*height/phashSide
		y1 := bounds.Min.Y + (ty+1)*height/phashSide
		if y1 <= y0 {
			y1 = y0 + 1
		}
		for tx := 0; tx < phashSide; tx++ {
			x0 := bounds.Min.X + tx*width/phashSide
			x1 := bounds.Min.X + (tx+1)*width/phashSide
			if x1 <= x0 {
				x1 = x0 + 1
			}

			var sum float64
			var count int
			for y := y0; y < y1 && y < bounds.Max.Y; y++ {
				for x := x0; x < x1 && x < bounds.Max.X; x++ {
					r, g, b, _ := img.At(x, y).RGBA()
					// ITU-R BT.601 亮度权重；RGBA() 返回 0..65535
					sum += (0.299*float64(r) + 0.587*float64(g) + 0.114*float64(b)) / 65535.0
					count++
				}
			}
			if count > 0 {
				grid[ty][tx] = sum / float64(count)
			}
		}
	}
	return &grid
}

// dctCos 预计算余弦表，避免每次计算重复展开。
var dctCos = func() [phashSide][phashSide]float64 {
	var table [phashSide][phashSide]float64
	for u := 0; u < phashSide; u++ {
		for x := 0; x < phashSide; x++ {
			table[u][x] = math.Cos(float64(2*x+1) * float64(u) * math.Pi / (2 * phashSide))
		}
	}
	return table
}()

// dct2D 对矩阵做二维 DCT-II（行列分离）。
func dct2D(grid *[phashSide][phashSide]float64) *[phashSide][phashSide]float64 {
	var rows [phashSide][phashSide]float64
	for y := 0; y < phashSide; y++ {
		for u := 0; u < phashSide; u++ {
			var sum float64
			for x := 0; x < phashSide; x++ {
				sum += grid[y][x] * dctCos[u][x]
			}
			rows[y][u] = sum
		}
	}

	var out [phashSide][phashSide]float64
	for u := 0; u < phashSide; u++ {
		for v := 0; v < phashSide; v++ {
			var sum float64
			for y := 0; y < phashSide; y++ {
				sum += rows[y][u] * dctCos[v][y]
			}
			out[v][u] = sum
		}
	}
	return &out
}

func medianOf(values []float64) float64 {
	if len(values) == 0 {
		return 0
	}
	sorted := make([]float64, len(values))
	copy(sorted, values)
	sort.Float64s(sorted)
	mid := len(sorted) / 2
	if len(sorted)%2 == 1 {
		return sorted[mid]
	}
	return (sorted[mid-1] + sorted[mid]) / 2
}

func popcount(v uint64) int {
	count := 0
	for v != 0 {
		v &= v - 1
		count++
	}
	return count
}
