package processor

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os/exec"
	"path/filepath"
	"strings"
)

type VideoEditParams struct {
	Type string `json:"type"`

	// 剪辑起止秒数；trim_end_sec <= 0 表示"到视频结尾"
	TrimStartSec float64 `json:"trim_start_sec"`
	TrimEndSec   float64 `json:"trim_end_sec"`

	// 视频总时长（秒），用于参数合理性校验，可选
	Duration float64 `json:"duration"`

	// 秒数缺失时按帧数与帧率换算。
	TrimStartFrame int     `json:"trim_start_frame"`
	TrimEndFrame   int     `json:"trim_end_frame"`
	FPS            float64 `json:"fps"`
}

// ApplyVideoEdit 剪取 [start, end)。非正结束秒数表示剪到结尾。
// 输入侧 seek 加重新编码实现帧级剪切，两轨时间戳从零开始。
func ApplyVideoEdit(ctx context.Context, srcPath, dstPath string, editParamsJSON string) error {
	var params VideoEditParams
	if err := json.Unmarshal([]byte(editParamsJSON), &params); err != nil {
		return fmt.Errorf("解析编辑参数失败: %w", err)
	}

	if params.Type != "video" {
		return fmt.Errorf("非视频编辑参数: %s", params.Type)
	}

	startSec := params.TrimStartSec
	endSec := params.TrimEndSec
	if startSec <= 0 && params.TrimStartFrame > 0 && params.FPS > 0 {
		startSec = float64(params.TrimStartFrame) / params.FPS
	}
	if endSec <= 0 && params.TrimEndFrame > 0 && params.FPS > 0 {
		endSec = float64(params.TrimEndFrame) / params.FPS
	}

	if startSec < 0 {
		startSec = 0
	}
	if endSec > 0 && params.Duration > 0 && endSec > params.Duration {
		endSec = params.Duration
	}
	if endSec > 0 && endSec <= startSec {
		return fmt.Errorf("剪辑参数无效: 结束时间 (%.3fs) 必须大于开始时间 (%.3fs)", endSec, startSec)
	}

	// 无剪辑需求：不生成任何文件，交由调用方清理 edit_params
	if startSec <= 0 && endSec <= 0 {
		return ErrNoOp
	}

	// 检查 ffmpeg 可用性
	ffmpegPath := "ffmpeg"
	if _, err := exec.LookPath(ffmpegPath); err != nil {
		return fmt.Errorf("ffmpeg 不可用: %w", err)
	}

	args := []string{"-y"}
	if startSec > 0 {
		args = append(args, "-ss", fmt.Sprintf("%.3f", startSec))
	}
	args = append(args, "-i", srcPath)
	if endSec > 0 {
		// -t 为输出时长（输入侧 seek 后从 seek 点起算），避免 -to 的时序歧义
		args = append(args, "-t", fmt.Sprintf("%.3f", endSec-startSec))
	}
	args = append(args,
		"-map", "0:v:0", // 视频流
		"-map", "0:a?", // 音频流（可选，无音轨的视频也能处理）
		// 时间戳归零：两轨强制从 0 开始，避免开头黑屏有声音
		"-vf", "setpts=PTS-STARTPTS",
		"-af", "aresample=async=1:first_pts=0",
	)
	ext := strings.ToLower(filepath.Ext(dstPath))
	if ext == ".webm" {
		args = append(args, "-c:v", "libvpx-vp9", "-crf", "18", "-b:v", "0", "-cpu-used", "4", "-c:a", "libopus")
	} else {
		args = append(args, "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-c:a", "aac")
	}
	args = append(args, "-b:a", "128k", "-avoid_negative_ts", "make_zero")
	if ext == ".mp4" || ext == ".mov" || ext == ".m4v" {
		args = append(args, "-movflags", "+faststart")
	}
	args = append(args, dstPath)

	ctx, cancel := context.WithTimeout(ctx, ffmpegTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, ffmpegPath, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ffmpeg 剪辑失败: %w, 输出: %s", err, string(output))
	}

	log.Printf("视频剪辑完成: %s (%.3fs - %.3fs)", filepath.Base(srcPath), startSec, endSec)
	return nil
}
