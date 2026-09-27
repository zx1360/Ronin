// Package proctask 统一管理"外部命令任务"的生命周期。
//
// comix 爬虫与 gallery CLI 是同一种形态：启动子进程 → 流式收集输出 → 支持中断
// （终止进程树）→ 内存中保留最近若干任务。两者唯一的结构差异是 stdout 的用途
// （comix 是单行 JSON 结果，gallery 是给人看的日志），由 Spec 参数化。
//
// 任务状态只在内存中：进程重启即清空，中断残留由各自的子命令自愈。
package proctask

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
)

// Status 任务状态。
type Status string

const (
	Running  Status = "running"  // 子进程运行中
	Finished Status = "finished" // 正常结束（含业务错误）
	Failed   Status = "failed"   // 启动失败 / 意外异常 / 输出解析失败
	Killed   Status = "killed"   // 被用户中断
)

// LogEntry 单条任务日志。
type LogEntry struct {
	Time   time.Time `json:"time"`
	Stream string    `json:"stream"` // stdout / stderr / system
	Text   string    `json:"text"`
}

// Task 一次外部命令执行。
type Task struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`    // 任务种类/展示名（comix 是命令名，gallery 是运行模式）
	Command    string     `json:"command"` // 展示用命令行
	Status     Status     `json:"status"`
	PID        int        `json:"pid"`
	StartedAt  time.Time  `json:"started_at"`
	FinishedAt *time.Time `json:"finished_at"`
	ExitCode   *int       `json:"exit_code"`
	Result     any        `json:"result,omitempty"`
	Error      string     `json:"error,omitempty"`
	Logs       []LogEntry `json:"logs"`

	killed     atomic.Bool
	proc       *exec.Cmd
	stderrTail strings.Builder
}

// maxStderrTail 失败上报保留的 stderr 尾部长度上限。
const maxStderrTail = 4 * 1024

// Spec 描述一次任务如何启动与解释结果。
type Spec struct {
	// Path/Args/Dir/Env 原样交给 exec.Command。
	Path string
	Args []string
	Dir  string
	Env  []string

	// Name 是任务种类/展示名。
	Name string
	// Command 是展示用命令行。
	Command string

	// StdoutIsResult 为真时 stdout 收进缓冲交给 Parse；否则 stdout 也逐行进日志。
	StdoutIsResult bool
	// Parse 把输出解释成结果；返回的 exitCode 仅用于展示（nil 表示不展示）。
	Parse func(stdout, stderrTail string, exitCode int, waitErr error) (any, *int, error)
}

// Manager 维护任务注册表。
type Manager struct {
	mu      sync.Mutex
	prefix  string
	seq     int
	tasks   map[string]*Task
	maxLogs int
	maxDone int
}

// NewManager 创建管理器；prefix 用于任务 ID（如 "t"、"g"）。
func NewManager(prefix string, maxLogs, maxDone int) *Manager {
	if maxLogs <= 0 {
		maxLogs = 500
	}
	if maxDone <= 0 {
		maxDone = 20
	}
	return &Manager{
		prefix:  prefix,
		tasks:   make(map[string]*Task),
		maxLogs: maxLogs,
		maxDone: maxDone,
	}
}

// Start 启动一个任务并立即返回（异步执行）。
func (m *Manager) Start(spec Spec) (*Task, error) {
	if strings.TrimSpace(spec.Path) == "" {
		return nil, fmt.Errorf("未指定可执行文件")
	}

	m.mu.Lock()
	m.seq++
	task := &Task{
		ID:        m.prefix + fmt.Sprint(m.seq),
		Name:      spec.Name,
		Command:   spec.Command,
		Status:    Running,
		StartedAt: time.Now(),
	}
	m.tasks[task.ID] = task
	m.mu.Unlock()

	go m.run(task, spec)
	return task, nil
}

// run 在子协程中执行命令并更新任务状态。
func (m *Manager) run(task *Task, spec Spec) {
	// 任务协程里的任何异常都只应让该任务失败，不能把整个 HTTP 服务带走。
	defer func() {
		if r := recover(); r != nil {
			m.finish(task, Failed, nil, nil, fmt.Errorf("任务协程异常: %v", r))
		}
	}()

	process := exec.Command(spec.Path, spec.Args...)
	process.Dir = spec.Dir
	process.Env = spec.Env

	stdoutPipe, err := process.StdoutPipe()
	if err != nil {
		m.finish(task, Failed, nil, nil, fmt.Errorf("创建 stdout 管道失败: %w", err))
		return
	}
	stderrPipe, err := process.StderrPipe()
	if err != nil {
		m.finish(task, Failed, nil, nil, fmt.Errorf("创建 stderr 管道失败: %w", err))
		return
	}
	if err := process.Start(); err != nil {
		m.finish(task, Failed, nil, nil, fmt.Errorf("启动进程失败: %w", err))
		return
	}
	m.setProc(task, process)
	if !spec.StdoutIsResult {
		m.appendLog(task, "system", fmt.Sprintf("已启动 %s (PID=%d)", task.Name, process.Process.Pid))
	}

	// stdout 为 JSON 时完整读取后解析；否则与 stderr 一样逐行流式追加。
	var stdoutBuf strings.Builder
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		if spec.StdoutIsResult {
			if _, err := io.Copy(&stdoutBuf, stdoutPipe); err != nil {
				m.appendLog(task, "system", fmt.Sprintf("读取 stdout 失败: %v", err))
			}
			return
		}
		m.streamLines(task, "stdout", stdoutPipe)
	}()
	go func() {
		defer wg.Done()
		m.streamLines(task, "stderr", stderrPipe)
	}()

	waitErr := process.Wait()
	// 等两个读取协程收尾：既保证日志完整，也保证失败时能拿到 stderr 原因。
	wg.Wait()

	if task.killed.Load() {
		m.finish(task, Killed, nil, nil, fmt.Errorf("任务已被中断"))
		return
	}

	exitCode := 0
	if process.ProcessState != nil {
		exitCode = process.ProcessState.ExitCode()
	}

	if spec.Parse == nil {
		if waitErr != nil || exitCode != 0 {
			m.finish(task, Failed, nil, &exitCode, fmt.Errorf("%s 退出码 %d", task.Name, exitCode))
			return
		}
		m.finish(task, Finished, nil, &exitCode, nil)
		return
	}

	result, code, parseErr := spec.Parse(stdoutBuf.String(), m.stderrTailOf(task), exitCode, waitErr)
	if parseErr != nil {
		m.finish(task, Failed, nil, nil, parseErr)
		return
	}
	m.finish(task, Finished, result, code, nil)
}

// Stop 中断任务：先终止主进程（Windows 下可靠），再尽力清理整个进程树。
func (m *Manager) Stop(taskID string) error {
	m.mu.Lock()
	task := m.tasks[taskID]
	m.mu.Unlock()
	if task == nil {
		return fmt.Errorf("任务 %s 不存在", taskID)
	}
	if task.Status != Running {
		return fmt.Errorf("任务 %s 当前状态为 %s，无法中断", taskID, task.Status)
	}

	task.killed.Store(true)
	m.appendLog(task, "system", "正在中断任务（kill 进程树）...")

	process := m.getProc(task)
	if process != nil && process.Process != nil {
		// 主进程 TerminateProcess（幂等；进程已退出时返回错误可忽略）
		_ = process.Process.Kill()
		// 尽力清理进程树（权限允许时）
		_ = exec.Command("taskkill", "/PID", fmt.Sprint(process.Process.Pid), "/T", "/F").Run()
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
	sort.Slice(all, func(i, j int) bool { return all[i].StartedAt.After(all[j].StartedAt) })

	// 裁剪：仅保留最近 maxDone 个已完成任务，运行中任务始终保留。
	done := 0
	keep := make([]*Task, 0, len(all))
	for _, t := range all {
		if t.Status == Running {
			keep = append(keep, t)
			continue
		}
		if done < m.maxDone {
			keep = append(keep, t)
			done++
		} else {
			delete(m.tasks, t.ID)
		}
	}
	return keep
}

// KillAll 中断全部运行中任务（供服务退出前调用）。
func (m *Manager) KillAll() {
	m.mu.Lock()
	var running []string
	for id, t := range m.tasks {
		if t.Status == Running {
			running = append(running, id)
		}
	}
	m.mu.Unlock()
	for _, id := range running {
		_ = m.Stop(id)
	}
}

// ---------- 内部辅助 ----------

func (m *Manager) streamLines(task *Task, stream string, reader io.Reader) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		m.appendLog(task, stream, line)
		if stream == "stderr" {
			m.appendStderrTail(task, line)
		}
	}
}

// appendStderrTail 保留 stderr 末尾内容（滚动裁剪），供失败时给出可读原因。
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

func (m *Manager) stderrTailOf(task *Task) string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return task.stderrTail.String()
}

func (m *Manager) setProc(task *Task, process *exec.Cmd) {
	m.mu.Lock()
	task.proc = process
	task.PID = process.Process.Pid
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

// finish 落定任务终态：成功记一行"任务已完成"，失败把原因写进 Error 与日志。
func (m *Manager) finish(task *Task, status Status, result any, exitCode *int, err error) {
	now := time.Now()
	m.mu.Lock()
	defer m.mu.Unlock()
	task.Status = status
	task.FinishedAt = &now
	task.Result = result
	task.ExitCode = exitCode
	text := "任务已完成"
	if err != nil {
		task.Error = err.Error()
		text = err.Error()
	}
	task.Logs = append(task.Logs, LogEntry{Time: now, Stream: "system", Text: text})
}
