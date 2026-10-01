// comix 异步任务的对外入口：把 comix CLI 的调用约定（解释器、工作目录、
// stdout 单行 JSON 协议）适配到通用子进程任务引擎 taskengine 上。
//
// 任务状态保存在内存中，Monarch 重启即清空——comix CLI 无状态 + 孤儿自愈
// （download 自动回收、clean 全局回收），中断残留可安全恢复。
package comix

import (
	"errors"

	"monarch/internal/config"
	"monarch/internal/service/taskengine"
)

// taskManager comix 专用的任务管理器（单例）。
type taskManager struct {
	engine *taskengine.Manager
}

// Manager 全局任务管理器。
var Manager = &taskManager{engine: taskengine.NewManager(500, 30)}

// Start 启动一个 comix 命令任务并立即返回（异步执行）。
func (m *taskManager) Start(name, cmd string, rest ...string) (*taskengine.Task, error) {
	if ok, msg := Available(); !ok {
		return nil, errors.New(msg)
	}
	return m.engine.Start(taskengine.Spec{
		Name:         name,
		Exe:          PythonExecutable(),
		Args:         BuildArgs(cmd, rest...),
		Dir:          config.ComixConf.Root,
		StreamStdout: false, // stdout 是单行 JSON 结果，写进日志只会刷屏
		Parse:        parseTaskResult,
	})
}

// Get 获取任务详情。
func (m *taskManager) Get(taskID string) (*taskengine.Task, error) { return m.engine.Get(taskID) }

// List 返回任务列表（新建在前）。
func (m *taskManager) List() []*taskengine.Task { return m.engine.List() }

// Stop 中断运行中的任务。
func (m *taskManager) Stop(taskID string) error { return m.engine.Stop(taskID) }

// KillAll 中断全部运行中任务（供服务退出前调用）。
func (m *taskManager) KillAll() { m.engine.KillAll() }

// parseTaskResult 适配 taskengine 的解析钩子。
func parseTaskResult(stdout, stderr string, exitCode int, runErr error) (any, error) {
	result, err := parseOutput(stdout, stderr, exitCode, runErr)
	if err != nil {
		return nil, err
	}
	return result, nil
}
