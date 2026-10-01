// Package taskengine 提供服务端托管的子进程任务引擎。
//
// 面向"长耗时 CLI 以子进程方式执行"的场景（comix 爬虫、gallery CLI）：启动进程、
// 逐行收集日志、跟踪状态与退出码、支持中断（kill 进程树）。任务状态保存在内存中，
// Monarch 重启即清空——被托管的 CLI 均无状态或自带孤儿自愈，中断残留可安全恢复。
package taskengine

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// Status 任务状态。
type Status string

const (
	StatusRunning  Status = "running"  // 子进程运行中
	StatusFinished Status = "finished" // 正常结束（含业务错误）
	StatusFailed   Status = "failed"   // 启动失败 / 意外异常 / 输出解析失败
	StatusKilled   Status = "killed"   // 被用户中断
)

// LogEntry 单条任务日志（子进程输出或引擎自身提示）。
type LogEntry struct {
	Time   time.Time `json:"time"`
	Stream string    `json:"stream"` // stdout / stderr / system
	Text   string    `json:"text"`
}

// Task 一次子进程执行任务。
type Task struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`
	Command    string     `json:"command"` // 展示用完整命令行
	Status     Status     `json:"status"`
	PID        int        `json:"pid"`
	StartedAt  time.Time  `json:"started_at"`
	FinishedAt *time.Time `json:"finished_at"`
	ExitCode   *int       `json:"exit_code"`
	Result     any        `json:"result,omitempty"`
	Error      string     `json:"error,omitempty"`
	Logs       []LogEntry `json:"logs"`

	killed atomic.Bool
	proc   *exec.Cmd // 由 run 设置，Stop 读取（经 manager 锁保护）
	// stderrTail 保留 stderr 末尾若干字节，用于失败时给出可读原因
	// （CLI 的 traceback/错误信息都走 stderr）。不加 json tag 且非导出，不参与序列化。
	stderrTail strings.Builder
}

// Spec 描述一次任务如何执行。
type Spec struct {
	Name string
	Exe  string
	Args []string
	Dir  string   // 工作目录，留空则沿用服务进程的当前目录
	Env  []string // 追加到当前进程环境之上的变量（KEY=VALUE）
	// StreamStdout 为 true 时把 stdout 逐行写入任务日志；无论真假，stdout 都被
	// 完整捕获供 Parse 使用（comix 的 stdout 是单行大 JSON，写进日志只会刷屏）。
	StreamStdout bool
	// Parse 把子进程输出解析为结构化结果；返回的错误视为任务失败。
	// 为 nil 时按退出码判定成败，Result 保持为空。
	Parse func(stdout, stderr string, exitCode int, runErr error) (any, error)
}

// maxStderrTail 错误上报保留的 stderr 尾部长度上限。
const maxStderrTail = 4 * 1024

// Manager 维护全部任务的内存注册表。
type Manager struct {
	mu       sync.Mutex
	seq      int
	tasks    map[string]*Task
	maxLogs  int // 单任务日志行数上限
	maxDone  int // 保留的已完成任务数量上限
}

// NewManager 创建任务管理器；上限非法时回退到默认值。
func NewManager(maxLogs, maxDone int) *Manager {
	if maxLogs <= 0 {
		maxLogs = 500
	}
	if maxDone <= 0 {
		maxDone = 30
	}
	return &Manager{tasks: make(map[string]*Task), maxLogs: maxLogs, maxDone: maxDone}
}

// Start 启动一个任务并立即返回（异步执行）。
func (m *Manager) Start(spec Spec) (*Task, error) {
	if strings.TrimSpace(spec.Exe) == "" {
		return nil, errors.New("未指定可执行文件")
	}

	m.mu.Lock()
	m.seq++
	taskID := fmt.Sprintf("t%d", m.seq)
	task := &Task{
		ID:        taskID,
		Name:      spec.Name,
		Command:   commandLine(spec),
		Status:    StatusRunning,
		StartedAt: time.Now(),
	}
	m.tasks[taskID] = task
	m.mu.Unlock()

	go m.run(task, spec)
	return task, nil
}

// commandLine 生成展示用命令行（可执行文件名 + 参数）。
func commandLine(spec Spec) string {
	parts := append([]string{filepath.Base(spec.Exe)}, spec.Args...)
	return strings.Join(parts, " ")
}

// run 在子协程中执行命令并更新任务状态。
func (m *Manager) run(task *Task, spec Spec) {
	process := exec.Command(spec.Exe, spec.Args...)
	if spec.Dir != "" {
		process.Dir = spec.Dir
	}
	if len(spec.Env) > 0 {
		process.Env = append(os.Environ(), spec.Env...)
	}

	stdoutPipe, err := process.StdoutPipe()
	if err != nil {
		m.finish(task, StatusFailed, nil, 0, fmt.Errorf("创建 stdout 管道失败: %v", err))
		return
	}
	stderrPipe, err := process.StderrPipe()
	if err != nil {
		m.finish(task, StatusFailed, nil, 0, fmt.Errorf("创建 stderr 管道失败: %v", err))
		return
	}

	if err := process.Start(); err != nil {
		m.finish(task, StatusFailed, nil, 0, fmt.Errorf("启动进程失败: %v", err))
		return
	}
	m.setPID(task, process.Process.Pid)
	m.setProc(task, process)

	// stdout 完整读取后交给 Parse；stderr 逐行追加为进度日志（同时保留尾部用于错误上报）。
	var stdoutBuf strings.Builder
	stdoutDone := make(chan struct{})
	go func() {
		defer close(stdoutDone)
		if spec.StreamStdout {
			m.streamLines(task, stdoutPipe, "stdout", &stdoutBuf)
			return
		}
		if _, err := io.Copy(&stdoutBuf, stdoutPipe); err != nil {
			m.appendLog(task, "system", fmt.Sprintf("读取 stdout 失败: %v", err))
		}
	}()
	stderrDone := make(chan struct{})
	go func() {
		defer close(stderrDone)
		m.streamLines(task, stderrPipe, "stderr", nil)
	}()

	waitErr := process.Wait()
	<-stdoutDone
	// 等 stderr 读完：既保证日志完整，也保证失败时能拿到错误原因
	<-stderrDone

	if task.killed.Load() {
		m.finish(task, StatusKilled, nil, 0, errors.New("任务已被中断"))
		return
	}

	exitCode := 0
	if process.ProcessState != nil {
		exitCode = process.ProcessState.ExitCode()
	}

	if spec.Parse != nil {
		result, parseErr := spec.Parse(stdoutBuf.String(), m.stderrTailOf(task), exitCode, waitErr)
		if parseErr != nil {
			m.finish(task, StatusFailed, nil, exitCode, parseErr)
			return
		}
		m.finish(task, StatusFinished, result, exitCode, nil)
		return
	}

	if waitErr != nil {
		m.finish(task, StatusFailed, nil, exitCode, m.failureReason(task, exitCode))
		return
	}
	m.finish(task, StatusFinished, nil, exitCode, nil)
}

// streamLines 逐行读取子进程输出：追加到任务日志，必要时同步写入汇总缓冲区。
func (m *Manager) streamLines(task *Task, reader io.Reader, stream string, sink *strings.Builder) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		m.appendLog(task, stream, line)
		if stream == "stderr" {
			m.appendStderrTail(task, line)
		}
		if sink != nil {
			sink.WriteString(line)
			sink.WriteByte('\n')
		}
	}
}

// failureReason 依据退出码与 stderr 尾部给出可读的失败原因。
func (m *Manager) failureReason(task *Task, exitCode int) error {
	reason := fmt.Sprintf("命令执行失败(exit %d)", exitCode)
	tail := strings.TrimSpace(m.stderrTailOf(task))
	if tail != "" {
		lines := strings.Split(tail, "\n")
		reason += ": " + strings.TrimSpace(lines[len(lines)-1])
	}
	return errors.New(reason)
}

// appendStderrTail 保留 stderr 末尾内容（滚动裁剪，最长 maxStderrTail）。
func (m *Manager) appendStderrTail(task *Task, line string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if task.stderrTail.Len() > 0 {
		task.stderrTail.WriteByte('\n')
	}
	task.stderrTail.WriteString(line)
	if task.stderrTail.Len() > maxStderrTail {
		tail := task.stderrTail.String()
		tail = tail[len(tail)-maxStderrTail:]
		task.stderrTail.Reset()
		task.stderrTail.WriteString(tail)
	}
}

// stderrTailOf 读取 stderr 尾部快照。
func (m *Manager) stderrTailOf(task *Task) string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return task.stderrTail.String()
}

// Stop 中断任务：先 taskkill 清理整个进程树（父进程还活着时才能按 PID 可靠地
// 找到子进程），再对主进程兜底 TerminateProcess。
//
// 只杀主进程是不够的：残留的子进程仍持有 stdout/stderr 管道，任务会一直停在
// "运行中"，直到子进程自己退出。
func (m *Manager) Stop(taskID string) error {
	m.mu.Lock()
	task := m.tasks[taskID]
	m.mu.Unlock()
	if task == nil {
		return fmt.Errorf("任务 %s 不存在", taskID)
	}
	if task.Status != StatusRunning {
		return fmt.Errorf("任务 %s 当前状态为 %s，无法中断", taskID, task.Status)
	}

	task.killed.Store(true)
	m.appendLog(task, "system", "正在中断任务（kill 进程树）...")

	// 尽力清理进程树（权限允许时）
	_ = exec.Command("taskkill", "/PID", fmt.Sprint(task.PID), "/T", "/F").Run()

	process := m.getProc(task)
	if process != nil && process.Process != nil {
		// 主进程 TerminateProcess（幂等；进程已退出时返回错误可忽略）
		_ = process.Process.Kill()
	}
	return nil
}

// Get 获取任务详情。
func (m *Manager) Get(taskID string) (*Task, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	task := m.tasks[taskID]
	if task == nil {
		return nil, fmt.Errorf("任务 %s 不存在", taskID)
	}
	return task, nil
}

// List 返回任务列表（新建在前），并裁剪超出上限的已完成任务。
func (m *Manager) List() []*Task {
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
		if t.Status == StatusRunning {
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

// RunningCount 返回运行中的任务数（供调用方做互斥判断）。
func (m *Manager) RunningCount() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	count := 0
	for _, t := range m.tasks {
		if t.Status == StatusRunning {
			count++
		}
	}
	return count
}

// KillAll 中断全部运行中任务（供服务退出前调用）。
func (m *Manager) KillAll() {
	m.mu.Lock()
	var running []*Task
	for _, t := range m.tasks {
		if t.Status == StatusRunning {
			running = append(running, t)
		}
	}
	m.mu.Unlock()
	for _, t := range running {
		_ = m.Stop(t.ID)
	}
}

// --- 内部辅助 ---

func (m *Manager) setPID(task *Task, pid int) {
	m.mu.Lock()
	task.PID = pid
	m.mu.Unlock()
}

func (m *Manager) setProc(task *Task, process *exec.Cmd) {
	m.mu.Lock()
	task.proc = process
	m.mu.Unlock()
}

func (m *Manager) getProc(task *Task) *exec.Cmd {
	m.mu.Lock()
	defer m.mu.Unlock()
	return task.proc
}

func (m *Manager) appendLog(task *Task, stream, text string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	task.Logs = append(task.Logs, LogEntry{Time: time.Now(), Stream: stream, Text: text})
	if len(task.Logs) > m.maxLogs {
		task.Logs = task.Logs[len(task.Logs)-m.maxLogs:]
	}
}

func (m *Manager) finish(task *Task, status Status, result any, exitCode int, err error) {
	now := time.Now()
	m.mu.Lock()
	defer m.mu.Unlock()
	task.Status = status
	task.FinishedAt = &now
	if result != nil {
		task.Result = result
	}
	// 只记录非零退出码，避免界面上出现无意义的 exit_code=0
	if exitCode != 0 {
		task.ExitCode = &exitCode
	}
	if err != nil {
		task.Error = err.Error()
		task.Logs = append(task.Logs, LogEntry{Time: now, Stream: "system", Text: err.Error()})
	}
}
