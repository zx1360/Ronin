// 异步任务引擎：Go 端管理 comix 爬虫子进程的生命周期。
//
// 长耗时命令（search/add/download/update-check/delete/clean）由本引擎
// 启动 `python -m comix.cli` 子进程并跟踪状态/日志/结果，支持中断
// （taskkill 进程树）。任务状态保存在内存中，Monarch 重启即清空——
// comix CLI 无状态 + 孤儿自愈（download 自动回收、clean 全局回收），
// 中断残留可安全恢复。
package comix

import (
	"bufio"
	"fmt"
	"io"
	"os/exec"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"monarch/internal/config"
)

// TaskStatus 任务状态。
type TaskStatus string

const (
	TaskRunning  TaskStatus = "running"  // 子进程运行中
	TaskFinished TaskStatus = "finished" // 正常结束（含业务错误 ok=false）
	TaskFailed   TaskStatus = "failed"   // 启动失败 / 意外异常 / 输出解析失败
	TaskKilled   TaskStatus = "killed"   // 被用户中断
)

// LogEntry 单条任务日志（主要来自 CLI 的 stderr 进度输出）。
type LogEntry struct {
	Time   time.Time `json:"time"`
	Stream string    `json:"stream"` // stdout / stderr / system
	Text   string    `json:"text"`
}

// Task 一次 comix 命令执行任务。
type Task struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`
	Command    string     `json:"command"` // 展示用完整命令行
	Status     TaskStatus `json:"status"`
	PID        int        `json:"pid"`
	StartedAt  time.Time  `json:"started_at"`
	FinishedAt *time.Time `json:"finished_at"`
	ExitCode   *int       `json:"exit_code"`
	Result     *Result    `json:"result,omitempty"`
	Error      string     `json:"error,omitempty"`
	Logs       []LogEntry `json:"logs"`

	killed atomic.Bool
	proc   *exec.Cmd // 由 runTask 设置，Stop 读取（经 manager 锁保护）
}

// TaskManager 维护全部任务的内存注册表。
type TaskManager struct {
	mu      sync.Mutex
	seq     int
	tasks   map[string]*Task
	maxLogs int // 单任务日志行数上限
	maxDone int // 保留的已完成任务数量上限
}

// Manager 全局任务管理器。
var Manager = &TaskManager{
	tasks:   make(map[string]*Task),
	maxLogs: 500,
	maxDone: 30,
}

// Start 启动一个 comix 命令任务并立即返回（异步执行）。
func (m *TaskManager) Start(name, cmd string, rest ...string) (*Task, error) {
	if ok, msg := Available(); !ok {
		return nil, fmt.Errorf("%s", msg)
	}

	m.mu.Lock()
	m.seq++
	taskID := fmt.Sprintf("t%d", m.seq)
	task := &Task{
		ID:        taskID,
		Name:      name,
		Command:   strings.Join(BuildArgs(cmd, rest...), " "),
		Status:    TaskRunning,
		StartedAt: time.Now(),
	}
	m.tasks[taskID] = task
	m.mu.Unlock()

	go m.run(task, cmd, rest...)
	return task, nil
}

// run 在子协程中执行命令并更新任务状态。
func (m *TaskManager) run(task *Task, cmd string, rest ...string) {
	full := BuildArgs(cmd, rest...)
	process := exec.Command(PythonExecutable(), full...)
	process.Dir = config.ComixConf.Root

	stdoutPipe, err := process.StdoutPipe()
	if err != nil {
		m.finish(task, TaskFailed, nil, fmt.Errorf("创建 stdout 管道失败: %v", err))
		return
	}
	stderrPipe, err := process.StderrPipe()
	if err != nil {
		m.finish(task, TaskFailed, nil, fmt.Errorf("创建 stderr 管道失败: %v", err))
		return
	}

	if err := process.Start(); err != nil {
		m.finish(task, TaskFailed, nil, fmt.Errorf("启动 comix 失败: %v", err))
		return
	}
	m.setPID(task, process.Process.Pid)
	m.setProc(task, process)

	// stdout 为最终 JSON（单行），完整读取后解析；stderr 为进度日志，逐行流式追加。
	var stdoutBuf strings.Builder
	stdoutDone := make(chan struct{})
	go func() {
		defer close(stdoutDone)
		if _, err := io.Copy(&stdoutBuf, stdoutPipe); err != nil {
			m.appendLog(task, "system", fmt.Sprintf("读取 stdout 失败: %v", err))
		}
	}()
	go m.streamLines(task, stderrPipe)

	waitErr := process.Wait()
	<-stdoutDone

	if task.killed.Load() {
		m.finish(task, TaskKilled, nil, fmt.Errorf("任务已被中断"))
		return
	}

	exitCode := 0
	if process.ProcessState != nil {
		exitCode = process.ProcessState.ExitCode()
	}
	result, parseErr := parseOutput(stdoutBuf.String(), "", exitCode, waitErr)
	if parseErr != nil {
		m.finish(task, TaskFailed, nil, parseErr)
		return
	}
	// 退出码 2 的业务错误（多候选等）同样视为"正常结束"，结果由调用方处理。
	m.finish(task, TaskFinished, result, nil)
}

// streamLines 逐行读取子进程 stderr 并追加到任务日志。
func (m *TaskManager) streamLines(task *Task, reader io.Reader) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		m.appendLog(task, "stderr", scanner.Text())
	}
}

// Stop 中断任务：先 TerminateProcess 直接终止主进程（Windows 下可靠，
// 与 Stop-Process 同源），再尽力 taskkill 清理整个进程树（含 Playwright 子进程）。
func (m *TaskManager) Stop(taskID string) error {
	m.mu.Lock()
	task := m.tasks[taskID]
	m.mu.Unlock()
	if task == nil {
		return fmt.Errorf("任务 %s 不存在", taskID)
	}
	if task.Status != TaskRunning {
		return fmt.Errorf("任务 %s 当前状态为 %s，无法中断", taskID, task.Status)
	}

	task.killed.Store(true)
	m.appendLog(task, "system", "正在中断任务（kill 进程树）...")

	process := m.getProc(task)
	if process != nil && process.Process != nil {
		// 主进程 TerminateProcess（幂等；进程已退出时返回错误可忽略）
		_ = process.Process.Kill()
		// 尽力清理进程树（权限允许时）
		_ = exec.Command("taskkill", "/PID", fmt.Sprint(task.PID), "/T", "/F").Run()
	}
	return nil
}

// Get 获取任务详情。
func (m *TaskManager) Get(taskID string) (*Task, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	task := m.tasks[taskID]
	if task == nil {
		return nil, fmt.Errorf("任务 %s 不存在", taskID)
	}
	return task, nil
}

// List 返回任务列表（新建在前），并裁剪超出上限的已完成任务。
func (m *TaskManager) List() []*Task {
	m.mu.Lock()
	defer m.mu.Unlock()

	all := make([]*Task, 0, len(m.tasks))
	for _, t := range m.tasks {
		all = append(all, t)
	}
	sort.Slice(all, func(i, j int) bool {
		return all[i].StartedAt.After(all[j].StartedAt)
	})

	// 裁剪：仅保留最近 maxDone 个已完成任务，运行中任务始终保留。
	doneCount := 0
	keep := make([]*Task, 0, len(all))
	for _, t := range all {
		if t.Status == TaskRunning {
			keep = append(keep, t)
			continue
		}
		if doneCount < m.maxDone {
			keep = append(keep, t)
			doneCount++
		} else {
			delete(m.tasks, t.ID)
		}
	}
	return keep
}

// KillAll 中断全部运行中任务（供服务退出前调用）。
func (m *TaskManager) KillAll() {
	m.mu.Lock()
	var running []*Task
	for _, t := range m.tasks {
		if t.Status == TaskRunning {
			running = append(running, t)
		}
	}
	m.mu.Unlock()
	for _, t := range running {
		_ = m.Stop(t.ID)
	}
}

// --- 内部辅助 ---

func (m *TaskManager) setPID(task *Task, pid int) {
	m.mu.Lock()
	task.PID = pid
	m.mu.Unlock()
}

func (m *TaskManager) setProc(task *Task, process *exec.Cmd) {
	m.mu.Lock()
	task.proc = process
	m.mu.Unlock()
}

func (m *TaskManager) getProc(task *Task) *exec.Cmd {
	m.mu.Lock()
	defer m.mu.Unlock()
	return task.proc
}

func (m *TaskManager) appendLog(task *Task, stream, text string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	task.Logs = append(task.Logs, LogEntry{Time: time.Now(), Stream: stream, Text: text})
	if len(task.Logs) > m.maxLogs {
		task.Logs = task.Logs[len(task.Logs)-m.maxLogs:]
	}
}

func (m *TaskManager) finish(task *Task, status TaskStatus, result *Result, err error) {
	now := time.Now()
	m.mu.Lock()
	defer m.mu.Unlock()
	task.Status = status
	task.FinishedAt = &now
	if result != nil {
		task.Result = result
		if result.ExitCode != 0 {
			code := result.ExitCode
			task.ExitCode = &code
		}
	}
	if err != nil {
		task.Error = err.Error()
		task.Logs = append(task.Logs, LogEntry{Time: now, Stream: "system", Text: err.Error()})
	}
}
