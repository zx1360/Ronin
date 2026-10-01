// Package gallery 提供 gallery CLI（本仓库 gizmos 模块构建的 gallery.exe）的集成调用。
//
// CLI 以子进程方式执行（`gallery.exe -mode <mode> -gallery-root <dir> ...`），
// 由服务端任务引擎托管生命周期：状态/日志/中断，与 comix 爬虫同一范式。
// CLI 自带 backend 根目录探测（按 references/db/sqlite.sql 标志），无需注入配置。
package gallery

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"monarch/internal/config"
	"monarch/internal/service/taskengine"
)

// 运行模式。
const (
	ModeIngest  = "ingest"
	ModeExecute = "execute"
	ModeRefresh = "refresh"
)

// Options gallery CLI 的可调参数；GalleryRoot 固定取服务端配置，不允许覆盖
// （必须与 Monarch 使用同一个媒体库目录）。
type Options struct {
	Mode          string `json:"mode"`
	Concurrency   int    `json:"concurrency"`
	Batch         int    `json:"batch"`
	Resize        int    `json:"resize"`
	ResizePreview int    `json:"resizePreview"`
	ResizeThumb   int    `json:"resizeThumb"`
}

// DefaultOptions 返回默认参数（与 CLI 自身的默认值一致）。
func DefaultOptions() Options {
	return Options{Mode: ModeIngest, Concurrency: 10, Batch: 160}
}

// Manager gallery 任务管理器（日志上限高于 comix：CLI 会逐条打印处理进度）。
var Manager = taskengine.NewManager(2000, 20)

// ExecutablePath 返回 gallery CLI 的绝对路径（GALLERY_CLI 可覆盖，默认 gizmos/gallery.exe）。
func ExecutablePath() string {
	configured := strings.TrimSpace(config.GalleryConf.Exe)
	if configured == "" {
		configured = filepath.Join("gizmos", "gallery.exe")
	}
	if abs, err := filepath.Abs(configured); err == nil {
		return abs
	}
	return configured
}

// Available 报告 gallery CLI 是否可用；不可用时返回原因。
func Available() (bool, string) {
	exe := ExecutablePath()
	info, err := os.Stat(exe)
	if err != nil {
		return false, fmt.Sprintf("gallery CLI 不可用（%s）：请在 backend/gizmos 下执行 go build ./cmd/gallery", exe)
	}
	if info.IsDir() {
		return false, fmt.Sprintf("gallery CLI 路径是目录: %s", exe)
	}
	if strings.TrimSpace(config.AppConf.GalleryDir) == "" {
		return false, "GALLERY_DIR 未配置（请在 backend/.env 中设置媒体库根目录）"
	}
	if info, err := os.Stat(config.AppConf.GalleryDir); err != nil || !info.IsDir() {
		return false, fmt.Sprintf("GALLERY_DIR 目录不可用: %s", config.AppConf.GalleryDir)
	}
	return true, ""
}

// TaskName 返回任务展示名。
func TaskName(mode string) string {
	switch mode {
	case ModeIngest:
		return "Gallery 摄入"
	case ModeExecute:
		return "Gallery 执行删除"
	case ModeRefresh:
		return "Gallery 刷新修复"
	default:
		return "Gallery " + mode
	}
}

// Validate 校验参数取值范围；非法值拒绝而不是静默夹取。
func Validate(opt Options) error {
	switch opt.Mode {
	case ModeIngest, ModeExecute, ModeRefresh:
	default:
		return fmt.Errorf("mode 只支持 ingest / execute / refresh")
	}
	if opt.Concurrency < 1 || opt.Concurrency > 64 {
		return errors.New("concurrency 超出范围 1-64")
	}
	if opt.Batch < 1 || opt.Batch > 5000 {
		return errors.New("batch 超出范围 1-5000")
	}
	for _, item := range []struct {
		name  string
		value int
	}{
		{"resize", opt.Resize},
		{"resizePreview", opt.ResizePreview},
		{"resizeThumb", opt.ResizeThumb},
	} {
		if item.value < 0 || item.value > 16384 {
			return fmt.Errorf("%s 超出范围 0-16384", item.name)
		}
	}
	if opt.Mode != ModeRefresh && (opt.Resize != 0 || opt.ResizePreview != 0 || opt.ResizeThumb != 0) {
		return errors.New("resize 系列参数仅在 refresh 模式生效")
	}
	return nil
}

// BuildArgs 构建 CLI 参数。
func BuildArgs(opt Options) []string {
	args := []string{
		"-mode", opt.Mode,
		"-gallery-root", config.AppConf.GalleryDir,
		"-concurrency", fmt.Sprint(opt.Concurrency),
		"-batch", fmt.Sprint(opt.Batch),
	}
	if opt.Mode == ModeRefresh {
		args = append(args,
			"-resize", fmt.Sprint(opt.Resize),
			"-resizePreview", fmt.Sprint(opt.ResizePreview),
			"-resizeThumb", fmt.Sprint(opt.ResizeThumb),
		)
	}
	return args
}

// Start 启动一次 gallery CLI 任务并立即返回。
//
// 同一时刻只允许一个 gallery 任务：ingest/execute/refresh 会同时改写媒体库文件
// 与数据库记录，并发执行没有意义且容易互相干扰。
func Start(opt Options) (*taskengine.Task, error) {
	if ok, msg := Available(); !ok {
		return nil, errors.New(msg)
	}
	if err := Validate(opt); err != nil {
		return nil, err
	}
	if Manager.RunningCount() > 0 {
		return nil, errors.New("已有 Gallery 任务在运行，请先等待或中断")
	}

	exe := ExecutablePath()
	return Manager.Start(taskengine.Spec{
		Name:         TaskName(opt.Mode),
		Exe:          exe,
		Args:         BuildArgs(opt),
		Dir:          filepath.Dir(exe),
		StreamStdout: true, // CLI 的统计与进度都打在 stdout
	})
}
