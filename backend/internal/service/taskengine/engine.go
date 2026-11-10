// Package taskengine 提供服务端托管的子进程任务引擎。
//
// 面向"长耗时 CLI 以子进程方式执行"的场景（comix 爬虫、gallery CLI）：启动进程、
// 逐行收集日志、跟踪状态与退出码、支持中断（kill 进程树）。任务状态保存在内存中，
// Monarch 重启即清空——被托管的 CLI 均无状态或自带孤儿自愈，中断残留可安全恢复。
package taskengine

import (
	"bytes"
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
	StatusQueued   Status = "queued"   // 等待共用资源
	StatusRunning  Status = "running"  // 子进程运行中
	StatusFinished Status = "finished" // 正常结束
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
	StartedAt  time.Time  `json:"started_at"` // 提交时间，包含排队等待。
	FinishedAt *time.Time `json:"finished_at"`
	ExitCode   *int       `json:"exit_code"`
	Result     any        `json:"result,omitempty"`
	Error      string     `json:"error"`
	Logs       []LogEntry `json:"logs,omitempty"`

	killed atomic.Bool
	stop   chan struct{}
	proc   *exec.Cmd // 由 run 设置，Stop 读取（经 manager 锁保护）
	// stderrTail 保留 stderr 末尾若干字节，用于失败时给出可读原因
	// （CLI 的 traceback/错误信息都走 stderr）。不加 json tag 且非导出，不参与序列化。
	stderrTail strings.Builder
	logBytes   int
}

// Spec 描述一次任务如何执行。
type Spec struct {
	Name         string
	Exe          string
	Args         []string
	Dir          string   // 工作目录，留空则沿用服务进程的当前目录
	Env          []string // 追加到当前进程环境之上的变量（KEY=VALUE）
	Guard        *Gate    // 共用资源按提交顺序分配；等待期间不启动进程。
	StreamStdout bool     // 将 stdout 逐行写入任务日志
	AfterExit    func()   // 已启动的进程退出后调用
	// Parse 把子进程输出解析为结构化结果；返回的错误视为任务失败。
	// 为 nil 时按退出码判定成败，Result 保持为空。
	Parse func(stdout, stderr string, exitCode int, runErr error) (any, error)
}

// maxStderrTail 错误上报保留的 stderr 尾部长度上限。
const (
	maxStderrTail = 4 * 1024
	maxLogBytes   = 512 * 1024
	maxResultSize = 16 * 1024 * 1024
)

// Manager 维护全部任务的内存注册表。
type Manager struct {
	mu      sync.Mutex
	wg      sync.WaitGroup
	closed  bool
	seq     int
	tasks   map[string]*Task
	maxLogs int // 单任务日志行数上限
	maxDone int // 保留的已完成任务数量上限
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
	if m.closed {
		m.mu.Unlock()
		return nil, errors.New("任务管理器已关闭")
	}
	m.seq++
	taskID := fmt.Sprintf("t%d", m.seq)
	task := &Task{
		ID:        taskID,
		Name:      spec.Name,
		Command:   commandLine(spec),
		Status:    StatusQueued,
		StartedAt: time.Now(),
		stop:      make(chan struct{}),
	}
	var reservation *ticket
	if spec.Guard != nil {
		reservation = spec.Guard.reserve()
	}
	m.tasks[taskID] = task
	m.wg.Add(1)
	snapshot := snapshotTask(task)
	m.mu.Unlock()

	go m.run(task, spec, reservation)
	return snapshot, nil
}

// commandLine 生成展示用命令行（可执行文件名 + 参数）。
func commandLine(spec Spec) string {
	parts := append([]string{filepath.Base(spec.Exe)}, spec.Args...)
	return strings.Join(parts, " ")
}

// run 在子协程中执行命令并更新任务状态。
func (m *Manager) run(task *Task, spec Spec, reservation *ticket) {
	defer m.wg.Done()
	if spec.Guard != nil {
		defer spec.Guard.release(reservation)
		select {
		case <-reservation.ready:
		case <-task.stop:
			m.finish(task, StatusKilled, nil, 0, errors.New("已取消排队任务"))
			return
		}
	}
	process := exec.Command(spec.Exe, spec.Args...)
	if spec.Dir != "" {
		process.Dir = spec.Dir
	}
	if len(spec.Env) > 0 {
		process.Env = append(os.Environ(), spec.Env...)
	}

	var stdoutBuf resultWriter
	stdout := &logWriter{emit: func(line string) { m.appendLog(task, "stdout", line) }}
	stderr := &logWriter{emit: func(line string) {
		m.appendLog(task, "stderr", line)
		m.appendStderrTail(task, line)
	}}
	process.Stderr = stderr
	switch {
	case spec.StreamStdout && spec.Parse != nil:
		process.Stdout = io.MultiWriter(stdout, &stdoutBuf)
	case spec.StreamStdout:
		process.Stdout = stdout
	case spec.Parse != nil:
		process.Stdout = &stdoutBuf
	}
	process.WaitDelay = 3 * time.Second

	m.mu.Lock()
	if task.killed.Load() {
		m.mu.Unlock()
		m.finish(task, StatusKilled, nil, 0, errors.New("任务已被中断"))
		return
	}
	err := process.Start()
	if err == nil {
		task.Status = StatusRunning
		task.PID = process.Process.Pid
		task.proc = process
	}
	m.mu.Unlock()
	if err != nil {
		m.finish(task, StatusFailed, nil, 0, fmt.Errorf("启动进程失败: %v", err))
		return
	}
	if spec.AfterExit != nil {
		defer spec.AfterExit()
	}

	waitErr := process.Wait()
	m.mu.Lock()
	task.proc = nil
	m.mu.Unlock()
	stdout.flush()
	stderr.flush()

	if task.killed.Load() {
		m.finish(task, StatusKilled, nil, 0, errors.New("任务已被中断"))
		return
	}

	exitCode := 0
	if process.ProcessState != nil {
		exitCode = process.ProcessState.ExitCode()
	}
	if errors.Is(waitErr, exec.ErrWaitDelay) {
		m.finish(task, StatusFailed, nil, exitCode, errors.New("子进程退出后输出管道未关闭"))
		return
	}

	if spec.Parse != nil {
		if stdoutBuf.overflow {
			m.finish(task, StatusFailed, nil, exitCode, errors.New("任务结果超过 16 MiB 上限，请缩小批次后重试"))
			return
		}
		result, parseErr := spec.Parse(stdoutBuf.String(), m.stderrTailOf(task), exitCode, waitErr)
		if parseErr != nil {
			m.finish(task, StatusFailed, result, exitCode, parseErr)
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

type resultWriter struct {
	strings.Builder
	overflow bool
}

func (w *resultWriter) Write(p []byte) (int, error) {
	n := min(len(p), maxResultSize-w.Len())
	_, _ = w.Builder.Write(p[:n])
	w.overflow = w.overflow || n < len(p)
	return len(p), nil
}

type logWriter struct {
	emit      func(string)
	line      []byte
	truncated bool
}

func (w *logWriter) Write(p []byte) (int, error) {
	const maxLine = 16 * 1024
	size := len(p)
	for len(p) > 0 {
		part, rest, end := bytes.Cut(p, []byte{'\n'})
		n := min(len(part), maxLine-len(w.line))
		w.line = append(w.line, part[:n]...)
		w.truncated = w.truncated || n < len(part)
		if end {
			w.flush()
		}
		p = rest
	}
	return size, nil
}

func (w *logWriter) flush() {
	if len(w.line) > 0 {
		line := strings.TrimSuffix(string(w.line), "\r")
		if w.truncated {
			line += " …（已截断）"
		}
		w.emit(line)
	}
	w.line = w.line[:0]
	w.truncated = false
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
	if task == nil {
		m.mu.Unlock()
		return fmt.Errorf("任务 %s 不存在", taskID)
	}
	if !active(task.Status) {
		status := task.Status
		m.mu.Unlock()
		return fmt.Errorf("任务 %s 当前状态为 %s，无法中断", taskID, status)
	}

	if task.killed.CompareAndSwap(false, true) {
		close(task.stop)
	}
	process := task.proc
	queued := task.Status == StatusQueued
	m.mu.Unlock()
	if queued {
		m.appendLog(task, "system", "正在取消排队任务...")
	} else {
		m.appendLog(task, "system", "正在中断任务...")
	}

	// 尽力清理进程树（权限允许时）
	if process != nil && process.Process != nil {
		if os.PathSeparator == '\\' {
			_ = exec.Command("taskkill", "/PID", fmt.Sprint(process.Process.Pid), "/T", "/F").Run()
		}
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
	copy := snapshotTask(task)
	copy.Logs = append([]LogEntry(nil), task.Logs...)
	return copy, nil
}

// 调用方在锁内取元数据副本；日志仅在 Get 中复制。
func snapshotTask(task *Task) *Task {
	copy := &Task{
		ID: task.ID, Name: task.Name, Command: task.Command, Status: task.Status,
		PID: task.PID, StartedAt: task.StartedAt, Result: task.Result, Error: task.Error,
	}
	if task.FinishedAt != nil {
		value := *task.FinishedAt
		copy.FinishedAt = &value
	}
	if task.ExitCode != nil {
		value := *task.ExitCode
		copy.ExitCode = &value
	}
	return copy
}

func active(status Status) bool { return status == StatusQueued || status == StatusRunning }

// List 返回不含日志的任务列表（新建在前）。
func (m *Manager) List() []*Task {
	m.mu.Lock()
	defer m.mu.Unlock()

	all := make([]*Task, 0, len(m.tasks))
	for _, t := range m.tasks {
		all = append(all, snapshotTask(t))
	}
	sort.Slice(all, func(i, j int) bool {
		return all[i].StartedAt.After(all[j].StartedAt)
	})

	return all
}

// ActiveCount 返回排队及运行任务数，供调用方做互斥判断。
func (m *Manager) ActiveCount() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	count := 0
	for _, t := range m.tasks {
		if active(t.Status) {
			count++
		}
	}
	return count
}

// Close 拒绝新任务，中断进程树并等待任务退出。
func (m *Manager) Close() {
	m.mu.Lock()
	m.closed = true
	var running []*Task
	for _, t := range m.tasks {
		if active(t.Status) {
			running = append(running, t)
		}
	}
	m.mu.Unlock()
	for _, t := range running {
		_ = m.Stop(t.ID)
	}
	m.wg.Wait()
}

// --- 内部辅助 ---

func (m *Manager) appendLog(task *Task, stream, text string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.logLocked(task, LogEntry{Time: time.Now(), Stream: stream, Text: text})
}

func (m *Manager) logLocked(task *Task, entry LogEntry) {
	task.Logs = append(task.Logs, entry)
	task.logBytes += len(entry.Text)
	for len(task.Logs) > m.maxLogs || task.logBytes > maxLogBytes {
		task.logBytes -= len(task.Logs[0].Text)
		task.Logs[0] = LogEntry{}
		task.Logs = task.Logs[1:]
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
		if len(task.Error) > maxStderrTail {
			task.Error = task.Error[:maxStderrTail/2] + " …（已截断）… " + task.Error[len(task.Error)-maxStderrTail/2:]
		}
		m.logLocked(task, LogEntry{Time: now, Stream: "system", Text: task.Error})
	}
	// 终态及时裁剪；无人打开运维页时也保持固定内存上限。
	done := make([]*Task, 0, m.maxDone+1)
	for _, item := range m.tasks {
		if !active(item.Status) {
			done = append(done, item)
		}
	}
	sort.Slice(done, func(i, j int) bool { return done[i].FinishedAt.After(*done[j].FinishedAt) })
	for _, item := range done[min(m.maxDone, len(done)):] {
		delete(m.tasks, item.ID)
	}
}
