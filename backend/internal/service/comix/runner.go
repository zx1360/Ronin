// 异步任务引擎：Go 端管理 comix 爬虫子进程的生命周期。
//
// 长耗时命令（search/add/download/update-check/delete/clean）由通用任务引擎
// （internal/service/proctask）启动 `python -m comix.cli` 子进程并跟踪状态/日志/结果。
// 任务状态只在内存中，Monarch 重启即清空——comix CLI 无状态 + 孤儿自愈
// （download 自动回收、clean 全局回收），中断残留可安全恢复。
package comix

import (
	"fmt"
	"strings"

	"monarch/internal/config"
	"monarch/internal/service/proctask"
)

// 任务状态、日志与任务类型直接复用通用任务引擎的类型。
type (
	TaskStatus = proctask.Status
	LogEntry   = proctask.LogEntry
	Task       = proctask.Task
)

const (
	TaskRunning  = proctask.Running
	TaskFinished = proctask.Finished
	TaskFailed   = proctask.Failed
	TaskKilled   = proctask.Killed
)

// taskManager 在通用引擎之上补上 comix 专有的启动细节（解释器、工作目录、环境）。
type taskManager struct{ *proctask.Manager }

// Manager 全局任务管理器。
var Manager = &taskManager{proctask.NewManager("t", 500, 30)}

// Start 启动一个 comix 命令任务并立即返回（异步执行）。
func (m *taskManager) Start(name, cmd string, rest ...string) (*Task, error) {
	if ok, msg := Available(); !ok {
		return nil, fmt.Errorf("%s", msg)
	}
	full := BuildArgs(cmd, rest...)
	return m.Manager.Start(proctask.Spec{
		Path:           PythonExecutable(),
		Args:           full,
		Dir:            config.ResolveComixRoot(),
		Env:            ChildEnv(),
		Name:           name,
		Command:        strings.Join(full, " "),
		StdoutIsResult: true,
		Parse:          parseTaskOutput,
	})
}

// parseTaskOutput 解释 CLI 输出：退出码 2 的业务错误（多候选等）同样算"正常结束"，
// 结果由调用方处理；只有传输/启动/解析级故障才算任务失败。
func parseTaskOutput(stdout, stderrTail string, exitCode int, waitErr error) (any, *int, error) {
	result, err := parseOutput(stdout, stderrTail, exitCode, waitErr)
	if err != nil {
		return nil, nil, err
	}
	var code *int
	if result.ExitCode != 0 {
		value := result.ExitCode
		code = &value
	}
	return result, code, nil
}
