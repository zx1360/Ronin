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
	"monarch/internal/service/db"
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
	root := config.ResolveComixRoot()
	if root == "" {
		return false, "内置 comix 目录不可用（应位于 backend/gizmos/comix）"
	}
	if fi, err := os.Stat(root); err != nil || !fi.IsDir() {
		return false, fmt.Sprintf("内置 comix 目录不可用: %s", root)
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

// ChildEnv 返回 comix 子进程的环境变量。
//
// 在 db.ChildEnv（绝对 DB_PATH）之上，把存储根与下载并发也固定下来：
// 这两项是 app_settings 里的运行时配置（ops 页面可改），而 comix 自己还会读取
// 它的 .env；不显式下发就会出现"Go 按新目录删文件、Python 按旧目录落盘"的分叉。
// comix 的 load_dotenv 不覆盖已存在的环境变量，因此这里的值优先。
func ChildEnv() []string {
	env := db.ChildEnv()
	env = setEnv(env, "COMIC_STORAGE_ROOT", strings.TrimSpace(config.ComixConf.StorageRoot))
	if config.ComixConf.MaxWorkers > 0 {
		env = setEnv(env, "COMIX_MAX_WORKERS", fmt.Sprint(config.ComixConf.MaxWorkers))
	}
	return env
}

// setEnv 覆盖（或追加）一个环境变量；value 为空时不改动。
func setEnv(env []string, key, value string) []string {
	if value == "" {
		return env
	}
	prefix := key + "="
	out := make([]string, 0, len(env)+1)
	for _, kv := range env {
		if !strings.HasPrefix(kv, prefix) {
			out = append(out, kv)
		}
	}
	return append(out, prefix+value)
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
	process.Dir = config.ResolveComixRoot()
	process.Env = ChildEnv()

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

// StorageRoot 返回 comix 的漫画存储根目录。
//
// 值取自运行时配置 comix.storage_root（默认 <STATIC_DIR>/comics，已解析为绝对路径），
// 并经 ChildEnv 下发给 comix 子进程——避免两处真相源。
func StorageRoot() (string, error) {
	root := strings.TrimSpace(config.ComixConf.StorageRoot)
	if root == "" {
		return "", errors.New("漫画存储根目录未配置（comix.storage_root）")
	}
	return root, nil
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
