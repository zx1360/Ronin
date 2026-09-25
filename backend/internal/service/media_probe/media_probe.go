// Package media_probe 封装基于 ffmpeg/ffprobe 的视频探测与取帧能力。
//
// ffmpeg/ffprobe 的解析结果与取帧图像都在进程内做有界缓存：客户端拖动进度条
// 预览时会高频请求同一时间点附近的帧，缓存可避免重复拉起子进程。
package media_probe

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"sync"
	"time"

	"github.com/google/uuid"
)

const (
	probeTimeout = 10 * time.Second
	frameTimeout = 10 * time.Second

	// frameCacheMax 取帧缓存条目上限（单帧 JPEG，数十 KB 级别）
	frameCacheMax = 64
	// frameSecStep 缓存键按 50ms 量化，吸收拖动抖动
	frameSecStep = 50
)

// VideoInfo 视频时长与分辨率。
type VideoInfo struct {
	DurationMs int64 `json:"duration_ms"`
	Width      int   `json:"width"`
	Height     int   `json:"height"`
}

// ErrToolUnavailable 表示 ffmpeg/ffprobe 不在 PATH 中。
type ErrToolUnavailable struct {
	Tool string
	Err  error
}

func (e *ErrToolUnavailable) Error() string {
	return fmt.Sprintf("%s 不可用: %v", e.Tool, e.Err)
}

func (e *ErrToolUnavailable) Unwrap() error { return e.Err }

// boundedCache 固定容量的 FIFO 缓存（满了淘汰最早写入的条目）。
type boundedCache[K comparable, V any] struct {
	mu      sync.Mutex
	max     int
	entries map[K]V
	order   []K
	next    int
}

func newBoundedCache[K comparable, V any](max int) *boundedCache[K, V] {
	return &boundedCache[K, V]{max: max, entries: make(map[K]V, max)}
}

func (c *boundedCache[K, V]) get(key K) (V, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	value, ok := c.entries[key]
	return value, ok
}

func (c *boundedCache[K, V]) put(key K, value V) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, exists := c.entries[key]; exists {
		c.entries[key] = value
		return
	}
	if len(c.order) < c.max {
		c.order = append(c.order, key)
	} else {
		delete(c.entries, c.order[c.next])
		c.order[c.next] = key
		c.next = (c.next + 1) % c.max
	}
	c.entries[key] = value
}

type frameCacheKey struct {
	assetID uuid.UUID
	step    int64
}

var (
	toolOnce    sync.Once
	ffmpegPath  string
	ffprobePath string
	toolLookErr error
	videoInfos  = newBoundedCache[uuid.UUID, VideoInfo](256)
	frameCache  = newBoundedCache[frameCacheKey, []byte](frameCacheMax)
)

// resolveTools 首次调用时解析 ffmpeg/ffprobe 的绝对路径并缓存。
func resolveTools() (ffmpeg, ffprobe string, err error) {
	toolOnce.Do(func() {
		ffmpegPath, err = exec.LookPath("ffmpeg")
		if err != nil {
			toolLookErr = &ErrToolUnavailable{Tool: "ffmpeg", Err: err}
			return
		}
		ffprobePath, err = exec.LookPath("ffprobe")
		if err != nil {
			toolLookErr = &ErrToolUnavailable{Tool: "ffprobe", Err: err}
			return
		}
	})
	if toolLookErr != nil {
		return "", "", toolLookErr
	}
	return ffmpegPath, ffprobePath, nil
}

// ProbeVideo 用 ffprobe 探测视频时长与分辨率（结果按 assetID 缓存）。
func ProbeVideo(assetID uuid.UUID, srcPath string) (VideoInfo, error) {
	if info, ok := videoInfos.get(assetID); ok {
		return info, nil
	}

	_, ffprobe, err := resolveTools()
	if err != nil {
		return VideoInfo{}, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), probeTimeout)
	defer cancel()

	out, err := exec.CommandContext(ctx, ffprobe,
		"-v", "error",
		"-show_entries", "format=duration:stream=width,height,codec_type",
		"-of", "json",
		srcPath,
	).Output()
	if err != nil {
		return VideoInfo{}, fmt.Errorf("ffprobe 探测失败: %w", err)
	}

	var parsed struct {
		Format struct {
			Duration string `json:"duration"`
		} `json:"format"`
		Streams []struct {
			Width  int    `json:"width"`
			Height int    `json:"height"`
			Codec  string `json:"codec_type"`
		} `json:"streams"`
	}
	if err := json.Unmarshal(out, &parsed); err != nil {
		return VideoInfo{}, fmt.Errorf("解析 ffprobe 输出失败: %w", err)
	}

	durationSec, _ := strconv.ParseFloat(parsed.Format.Duration, 64)
	info := VideoInfo{DurationMs: int64(durationSec * 1000)}
	for _, stream := range parsed.Streams {
		if stream.Codec == "video" {
			info.Width, info.Height = stream.Width, stream.Height
			break
		}
	}

	videoInfos.put(assetID, info)
	return info, nil
}

// ExtractFrame 用 ffmpeg 提取指定秒数的单帧 JPEG（结果按 assetID + 量化时间点缓存）。
//
// `-ss` 置于 `-i` 之前做输入侧快进，再解码到目标位置输出单帧：又快又准。
func ExtractFrame(assetID uuid.UUID, srcPath string, sec float64) ([]byte, error) {
	if sec < 0 {
		sec = 0
	}
	cacheKey := frameCacheKey{assetID: assetID, step: int64(sec * 1000 / frameSecStep)}
	if data, ok := frameCache.get(cacheKey); ok {
		return data, nil
	}

	ffmpeg, _, err := resolveTools()
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), frameTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, ffmpeg,
		"-ss", strconv.FormatFloat(sec, 'f', 2, 64),
		"-i", srcPath,
		"-frames:v", "1",
		"-q:v", "3",
		"-f", "image2pipe",
		"-vcodec", "mjpeg",
		"-",
	)
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("ffmpeg 提取帧失败: %w", err)
	}
	if out.Len() == 0 {
		return nil, fmt.Errorf("ffmpeg 未生成帧数据")
	}

	data := out.Bytes()
	frameCache.put(cacheKey, data)
	return data, nil
}
