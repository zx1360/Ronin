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
	"strings"
	"sync"

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
