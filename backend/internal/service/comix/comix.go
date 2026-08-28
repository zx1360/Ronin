// Package comix 提供对 comix 漫画下载管理系统的集成调用。
//
// 对接协议见 comix 项目 docs/协议文档.md：
// Go 服务以子进程方式调用 `python -m comix.cli --json <command>`，
// 每次调用独立进程/独立数据库连接（无状态）；stdout 单行 JSON，
// 进度日志走 stderr；退出码 0 成功 / 2 业务错误 / 1 意外异常。
package comix

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"monarch/internal/config"
)

// Result 为 comix CLI 的统一 JSON 响应（协议文档 §2）。
// 业务错误（ok=false）也可能携带 candidates 候选列表供上层展示选择。
type Result struct {
	OK         bool           `json:"ok"`
	Data       map[string]any `json:"data,omitempty"`
	Error      string         `json:"error,omitempty"`
	Candidates []any          `json:"candidates,omitempty"`
	ExitCode   int            `json:"exit_code"`
	Stderr     string         `json:"stderr,omitempty"`
}

var (
	pythonOnce sync.Once
	pythonPath string
)

// PythonExecutable 返回 python 解释器路径（首次解析后缓存）。
// 优先使用 PATH 解析到的绝对路径，避免依赖启动方的工作目录。
func PythonExecutable() string {
	pythonOnce.Do(func() {
		configured := strings.TrimSpace(config.ComixConf.Python)
		if configured == "" {
			configured = "python"
		}
		if abs, err := exec.LookPath(configured); err == nil {
			pythonPath = abs
		} else {
			pythonPath = configured
		}
	})
	return pythonPath
}

// Available 报告 comix 集成是否可用；不可用时返回原因。
func Available() (bool, string) {
	root := strings.TrimSpace(config.ComixConf.Root)
	if root == "" {
		return false, "COMIX_ROOT 未配置（请在 backend/.env 中设置 comix 项目根目录）"
	}
	if fi, err := os.Stat(root); err != nil || !fi.IsDir() {
		return false, fmt.Sprintf("COMIX_ROOT 目录不可用: %s", root)
	}
	py := PythonExecutable()
	if fi, err := os.Stat(py); err != nil || fi.IsDir() {
		return false, fmt.Sprintf("python 解释器不可用: %s", py)
	}
	return true, ""
}

// BuildArgs 构建完整 CLI 参数：`-m comix.cli --json <cmd> ...rest`。
// --json 必须位于子命令之前（主解析器全局参数）。
func BuildArgs(cmd string, rest ...string) []string {
	return append([]string{"-m", "comix.cli", "--json", cmd}, rest...)
}

// RunSync 同步执行一次 comix 命令并解析 JSON 结果。
// 业务错误（退出码 2）返回 result（ok=false）而非 error；
// 仅传输/启动/解析级故障返回 error。
func RunSync(ctx context.Context, cmd string, rest ...string) (*Result, error) {
	if ok, msg := Available(); !ok {
		return nil, errors.New(msg)
	}

	full := BuildArgs(cmd, rest...)
	process := exec.CommandContext(ctx, PythonExecutable(), full...)
	process.Dir = config.ComixConf.Root

	var stdout, stderr strings.Builder
	process.Stdout = &stdout
	process.Stderr = &stderr

	runErr := process.Run()
	exitCode := 0
	if process.ProcessState != nil {
		exitCode = process.ProcessState.ExitCode()
	}
	return parseOutput(stdout.String(), stderr.String(), exitCode, runErr)
}

// parseOutput 解析 CLI 输出。
// 无论退出码如何，只要 stdout 可解析为 JSON 即返回该结果（业务错误同样携带）；
// 否则按退出码与 stderr 构造错误。
func parseOutput(stdout, stderr string, exitCode int, runErr error) (*Result, error) {
	result := &Result{ExitCode: exitCode, Stderr: strings.TrimSpace(stderr)}
	parseErr := json.Unmarshal([]byte(stdout), result)
	if parseErr == nil {
		return result, nil
	}
	if runErr != nil {
		return nil, fmt.Errorf("comix 命令执行失败(exit %d): %s", exitCode, strings.TrimSpace(stderr))
	}
	return nil, fmt.Errorf("comix 输出解析失败: %v (stdout=%q stderr=%q)", parseErr, stdout, stderr)
}

// ---------------------------------------------------------------------------
// 存储路径（与 comix 端 util/common 的语义保持一致）
// ---------------------------------------------------------------------------

var (
	storageOnce sync.Once
	storageRoot string
	storageErr  error
)

// StorageRoot 返回 comix 的漫画存储根目录（COMIC_STORAGE_ROOT）。
//
// 该值定义在 comix 项目根目录的 .env 中（backend/.env 不重复维护，避免双真相源）；
// 相对路径按 comix 约定相对其项目根解析。首次调用后缓存。
func StorageRoot() (string, error) {
	storageOnce.Do(func() {
		root := strings.TrimSpace(config.ComixConf.Root)
		if root == "" {
			storageErr = errors.New("COMIX_ROOT 未配置（请在 backend/.env 中设置 comix 项目根目录）")
			return
		}
		storageRoot, storageErr = readStorageRoot(root)
	})
	return storageRoot, storageErr
}

func readStorageRoot(comixRoot string) (string, error) {
	envFile := filepath.Join(comixRoot, ".env")
	data, err := os.ReadFile(envFile)
	if err != nil {
		return "", fmt.Errorf("读取 comix .env 失败: %v", err)
	}
	value := ""
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, found := strings.Cut(line, "=")
		if !found {
			continue
		}
		if strings.TrimSpace(key) == "COMIC_STORAGE_ROOT" {
			value = strings.TrimSpace(val)
			break
		}
	}
	if value == "" {
		value = "./comics" // comix 默认值
	}
	if !filepath.IsAbs(value) {
		value = filepath.Join(comixRoot, value)
	}
	// 清理可能的引号
	return strings.Trim(value, `"'`), nil
}

// StoragePath 将 DB 中的 rel_dir（形如 `comics/{comic_id}/{chapter_id}`）
// 解析为存储根下的绝对路径（`comics/` 前缀对应存储根下的目录）。
func StoragePath(relDir string) (string, error) {
	root, err := StorageRoot()
	if err != nil {
		return "", err
	}
	relative := relDir
	if strings.HasPrefix(relative, "comics/") {
		relative = relative[len("comics/"):]
	}
	return filepath.Join(root, filepath.FromSlash(relative)), nil
}

// RemoveDirSafely 删除目录（Windows 下重试 + 处理只读文件）。
func RemoveDirSafely(path string) error {
	if path == "" {
		return nil
	}
	if _, err := os.Stat(path); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		if err := os.RemoveAll(path); err == nil {
			return nil
		} else {
			lastErr = err
		}
		clearReadOnly(path)
		time.Sleep(time.Duration(attempt+1) * 300 * time.Millisecond)
	}
	return lastErr
}

// clearReadOnly 清除目录树内所有文件的只读属性（RemoveAll 失败时的兜底）。
func clearReadOnly(root string) {
	_ = filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if info, statErr := d.Info(); statErr == nil && info.Mode()&0200 == 0 {
			_ = os.Chmod(p, 0644)
		}
		return nil
	})
}
