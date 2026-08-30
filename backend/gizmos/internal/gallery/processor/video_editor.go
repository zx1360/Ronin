package processor

import (
	"encoding/json"
	"fmt"
	"log"
	"os/exec"
	"path/filepath"
)

// VideoEditParams 视频编辑参数
//
// 时间单位统一为**秒**（trim_start_sec / trim_end_sec），由客户端按真实时长计算。
// trim_start_frame / trim_end_frame / fps 为旧版（帧数）协议的遗留字段，
// 仅当秒数为空时才作为后备解析，新客户端不应再写入。
type VideoEditParams struct {
	Type string `json:"type"`

	// 剪辑起止秒数；trim_end_sec <= 0 表示"到视频结尾"
	TrimStartSec float64 `json:"trim_start_sec"`
	TrimEndSec   float64 `json:"trim_end_sec"`

	// 视频总时长（秒），用于参数合理性校验，可选
	Duration float64 `json:"duration"`

	// ===== 旧版帧数协议（遗留） =====
	TrimStartFrame int     `json:"trim_start_frame"`
	TrimEndFrame   int     `json:"trim_end_frame"`
	FPS            float64 `json:"fps"`
}

// ApplyVideoEdit 对视频应用剪辑（裁剪起止点），结果写入 dstPath
//
// 剪辑语义：
//   - 仅 start > 0          → 从 start 秒剪到结尾
//   - 仅 end > 0            → 从 0 剪到 end 秒
//   - start 与 end 均 > 0   → 剪取 [start, end) 区间
//   - 两者均 <= 0           → 无操作，返回 ErrNoOp
//
// 实现采用 "输入侧 -ss 快进 + 重新编码" 方式：
//   - `-ss` 放在 `-i` 之前（输入侧 seek），现代 ffmpeg 在重新编码时会丢弃
//     目标点之前的帧，起止点**帧级准确**，且解码开销远小于输出侧 seek；
//   - 重新编码（H.264 + AAC）保证任意容器/编码都能得到时间轴正确的输出，
//     避免 `-c copy` 在非关键帧处剪切导致的画面黑帧、音画不同步等问题。
func ApplyVideoEdit(srcPath, dstPath string, editParamsJSON string) error {
	var params VideoEditParams
	if err := json.Unmarshal([]byte(editParamsJSON), &params); err != nil {
		return fmt.Errorf("解析编辑参数失败: %w", err)
	}

	if params.Type != "video" {
		return fmt.Errorf("非视频编辑参数: %s", params.Type)
	}

	// 解析起止秒数（优先秒数，其次旧版帧数/帧率换算）
	startSec := params.TrimStartSec
	endSec := params.TrimEndSec
	if startSec <= 0 && params.TrimStartFrame > 0 && params.FPS > 0 {
		startSec = float64(params.TrimStartFrame) / params.FPS
	}
	if endSec <= 0 && params.TrimEndFrame > 0 && params.FPS > 0 {
		endSec = float64(params.TrimEndFrame) / params.FPS
	}

	// 参数合理性校验
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
		"-c:v", "libx264",
		"-preset", "veryfast",
		"-crf", "18",
		"-c:a", "aac",
		"-b:a", "128k",
		"-movflags", "+faststart",
		"-avoid_negative_ts", "make_zero",
		dstPath,
	)

	cmd := exec.Command(ffmpegPath, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ffmpeg 剪辑失败: %w, 输出: %s", err, string(output))
	}

	log.Printf("视频剪辑完成: %s (%.3fs - %.3fs)", filepath.Base(srcPath), startSec, endSec)
	return nil
}
