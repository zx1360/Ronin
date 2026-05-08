package processor

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

// VideoEditParams 视频编辑参数
type VideoEditParams struct {
	Type          string  `json:"type"`
	TrimStartFrame int    `json:"trim_start_frame"`
	TrimEndFrame  int     `json:"trim_end_frame"`
	FPS           float64 `json:"fps"`
	TrimStartSec  float64 `json:"trim_start_sec"`
	TrimEndSec    float64 `json:"trim_end_sec"`
}

// ApplyVideoEdit 对视频应用剪辑（裁剪起止点），结果写入 dstPath
func ApplyVideoEdit(srcPath, dstPath string, editParamsJSON string) error {
	var params VideoEditParams
	if err := json.Unmarshal([]byte(editParamsJSON), &params); err != nil {
		return fmt.Errorf("解析编辑参数失败: %w", err)
	}

	if params.Type != "video" {
		return fmt.Errorf("非视频编辑参数: %s", params.Type)
	}

	// 检查 ffmpeg 可用性
	ffmpegPath := "ffmpeg"
	if _, err := exec.LookPath(ffmpegPath); err != nil {
		return fmt.Errorf("ffmpeg 不可用: %w", err)
	}

	// 计算起止秒数
	startSec := params.TrimStartSec
	endSec := params.TrimEndSec

	// 如果 trim_start_sec/trim_end_sec 未提供，从帧数计算
	if startSec <= 0 && params.TrimStartFrame > 0 && params.FPS > 0 {
		startSec = float64(params.TrimStartFrame) / params.FPS
	}
	if endSec <= 0 && params.TrimEndFrame > 0 && params.FPS > 0 {
		endSec = float64(params.TrimEndFrame) / params.FPS
	}

	// 无需剪辑的情况
	if startSec <= 0 && (endSec <= 0 || params.TrimEndFrame <= 0) {
		log.Printf("视频无需剪辑，直接复制: %s", srcPath)
		srcData, err := os.ReadFile(srcPath)
		if err != nil {
			return fmt.Errorf("读取源视频失败: %w", err)
		}
		return os.WriteFile(dstPath, srcData, 0644)
	}

	// 构建 ffmpeg 命令
	args := []string{"-i", srcPath}

	if startSec > 0 {
		args = append(args, "-ss", fmt.Sprintf("%.3f", startSec))
	}
	if endSec > 0 && endSec > startSec {
		args = append(args, "-to", fmt.Sprintf("%.3f", endSec))
	}

	// -c copy 快速剪辑（不重新编码）
	args = append(args, "-c", "copy", "-y", dstPath)

	cmd := exec.Command(ffmpegPath, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ffmpeg 剪辑失败: %w, 输出: %s", err, string(output))
	}

	log.Printf("视频剪辑完成: %s (%.1fs - %.1fs)", filepath.Base(srcPath), startSec, endSec)
	return nil
}
