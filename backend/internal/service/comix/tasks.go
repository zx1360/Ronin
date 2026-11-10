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
	*taskengine.Manager
}

// Manager 全局任务管理器。
var Manager = &taskManager{Manager: taskengine.NewManager(500, 30)}

// Start 启动一个 comix 命令任务并立即返回（异步执行）。
func (m *taskManager) Start(name, cmd string, rest ...string) (*taskengine.Task, error) {
	if ok, msg := Available(); !ok {
		return nil, errors.New(msg)
	}
	return m.Manager.Start(taskengine.Spec{
		Guard:        &MutationMu,
		Name:         name,
		Exe:          PythonExecutable(),
		Args:         BuildArgs(cmd, rest...),
		Dir:          config.ComixConf.Root,
		Env:          []string{"MONARCH_DB_FILE=" + dbAbsPath(), "COMIC_STORAGE_ROOT=" + config.ComixConf.StorageRoot},
		StreamStdout: false, // stdout 是单行 JSON 结果，写进日志只会刷屏
		Parse:        parseTaskResult,
	})
}

// parseTaskResult 适配 taskengine 的解析钩子。
func parseTaskResult(stdout, stderr string, exitCode int, runErr error) (any, error) {
	result, err := parseOutput(stdout, stderr, exitCode, runErr)
	if err != nil {
		return nil, err
	}
	if !result.OK {
		message := result.Error
		if message == "" {
			message = "漫画任务未成功完成"
		}
		return result, errors.New(message)
	}
	return result, nil
}
