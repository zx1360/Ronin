package ai

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"monarch/internal/config"
)

// 侧车 NDJSON 协议版本。
const sidecarProtocolVersion = 1

// sidecarHeader 请求首行：声明能力、参数与条目数。
//
// count 是必需字段：Go 侧写入后并不关闭 stdin（要保持进程供后续批次复用），
// 因此侧车必须靠计数而非 EOF 判断本批次读到何处。
type sidecarHeader struct {
	V          int            `json:"v"`
	Capability string         `json:"capability"`
	Count      int            `json:"count"`
	Params     map[string]any `json:"params,omitempty"`
}

// SidecarItem 请求条目：待处理的媒体（或待编码的文本）。
type SidecarItem struct {
	ID   string `json:"id"`
	Path string `json:"path,omitempty"`
	Text string `json:"text,omitempty"`
}

// sidecarResponse 响应条目；ready 用于 ping 握手。
type sidecarResponse struct {
	ID     string          `json:"id"`
	OK     bool            `json:"ok"`
	Error  string          `json:"error,omitempty"`
	Result json.RawMessage `json:"result,omitempty"`
	Ready  bool            `json:"ready,omitempty"`
}

// BatchResult 单条处理结果（ID 与请求条目一一对应）。
type BatchResult struct {
	ID     string
	OK     bool
	Error  string
	Result json.RawMessage
}

// ProbeResult python 侧依赖探测结果（缓存，避免每次状态查询都导入 onnxruntime）。
type ProbeResult struct {
	OK       bool              `json:"ok"`
	Python   string            `json:"python"`
	Packages map[string]string `json:"packages,omitempty"`
	Models   map[string]bool   `json:"models,omitempty"`
	Error    string            `json:"error,omitempty"`
	ProbedAt time.Time         `json:"probed_at"`
}

const probeTTL = 5 * time.Minute

// Sidecar 管理一个能力对应的 Python 侧车进程：用时启动，空闲退出。
//
// 两把锁，职责严格分开：
//   - mu：会话锁，保护管道与请求/响应序列化；**整个批次期间持有**，
//     因此绝不能在锁内做状态查询，否则 /status 会被批次拖住数十秒。
//   - stateMu：状态锁，保护进程句柄与时间戳快照，随时可取。
type Sidecar struct {
	capability string
	cfg        config.AiConfig

	mu     sync.Mutex
	proc   *exec.Cmd
	stdin  io.WriteCloser
	stdout *bufio.Reader

	stateMu   sync.RWMutex
	procRef   *exec.Cmd // 供 Stop 在批次进行中直接终止进程
	startedAt time.Time
	lastUsed  time.Time
	closed    bool

	probeMu sync.Mutex
	probe   *ProbeResult
}

// NewSidecar 创建侧车管理器（不启动进程）。
func NewSidecar(capability string, cfg config.AiConfig) *Sidecar {
	return &Sidecar{capability: capability, cfg: cfg}
}

// resolvePython 解析侧车解释器：优先显式配置，其次工作区内的独立 venv。
func (s *Sidecar) resolvePython() string {
	if p := strings.TrimSpace(s.cfg.Python); p != "" {
		return p
	}
	var candidates []string
	if runtime.GOOS == "windows" {
		candidates = []string{filepath.Join(s.cfg.SidecarDir, ".venv", "Scripts", "python.exe")}
	} else {
		candidates = []string{filepath.Join(s.cfg.SidecarDir, ".venv", "bin", "python")}
	}
	for _, c := range candidates {
		if fi, err := os.Stat(c); err == nil && !fi.IsDir() {
			return c
		}
	}
	return "python"
}

// Installed 报告侧车代码与解释器是否就位。
func (s *Sidecar) Installed() (bool, string) {
	dir := strings.TrimSpace(s.cfg.SidecarDir)
	if dir == "" {
		return false, "AI_SIDECAR_DIR 未配置"
	}
	if fi, err := os.Stat(filepath.Join(dir, "ronin_ai")); err != nil || !fi.IsDir() {
		return false, fmt.Sprintf("侧车代码缺失: %s", filepath.Join(dir, "ronin_ai"))
	}
	py := s.resolvePython()
	if strings.ContainsAny(py, `\/`) {
		if fi, err := os.Stat(py); err != nil || fi.IsDir() {
			return false, fmt.Sprintf("python 解释器不可用: %s", py)
		}
		return true, ""
	}
	if _, err := exec.LookPath(py); err != nil {
		return false, fmt.Sprintf("python 解释器不可用: %s", py)
	}
	return true, ""
}

// Probe 探测侧车依赖（结果缓存 probeTTL）。
func (s *Sidecar) Probe(ctx context.Context) *ProbeResult {
	s.probeMu.Lock()
	cached := s.probe
	s.probeMu.Unlock()
	if cached != nil && time.Since(cached.ProbedAt) < probeTTL {
		return cached
	}

	result := s.runProbe(ctx)
	s.probeMu.Lock()
	s.probe = result
	s.probeMu.Unlock()
	return result
}

func (s *Sidecar) runProbe(ctx context.Context) *ProbeResult {
	result := &ProbeResult{Python: s.resolvePython(), ProbedAt: time.Now()}
	if ok, reason := s.Installed(); !ok {
		result.Error = reason
		return result
	}

	probeCtx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()

	cmd := exec.CommandContext(probeCtx, result.Python, "-m", "ronin_ai", "--probe")
	cmd.Dir = s.cfg.SidecarDir
	out, err := cmd.Output()
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			result.Error = fmt.Sprintf("探测失败: %s", strings.TrimSpace(string(exitErr.Stderr)))
		} else {
			result.Error = fmt.Sprintf("探测失败: %v", err)
		}
		return result
	}
	if err := json.Unmarshal(out, result); err != nil {
		result.Error = fmt.Sprintf("解析探测结果失败: %v", err)
		return result
	}
	result.Python = s.resolvePython()
	result.ProbedAt = time.Now()
	return result
}

// ensureRunning 确保侧车进程存活（调用方需持有 s.mu）。
func (s *Sidecar) ensureRunning() error {
	if s.proc != nil && s.proc.Process != nil {
		return nil
	}
	if ok, reason := s.Installed(); !ok {
		return fmt.Errorf("%s 能力不可用: %s", s.capability, reason)
	}

	cmd := exec.Command(s.resolvePython(), "-m", "ronin_ai")
	cmd.Dir = s.cfg.SidecarDir
	cmd.Env = append(os.Environ(), "PYTHONUNBUFFERED=1", "PYTHONIOENCODING=utf-8")

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return fmt.Errorf("创建 stdin 管道失败: %w", err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("创建 stdout 管道失败: %w", err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("创建 stderr 管道失败: %w", err)
	}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("启动 %s 侧车失败: %w", s.capability, err)
	}
	// 侧车是长时间满载的批处理，降到前台之下，避免拖慢桌面端 UI
	if err := yieldToInteractive(cmd.Process.Pid); err != nil {
		log.Printf("[AI:%s] 降低进程优先级失败（不影响处理）: %v", s.capability, err)
	}

	s.proc = cmd
	s.stdin = stdin
	s.stdout = bufio.NewReaderSize(stdout, 1<<20)
	now := time.Now()

	s.stateMu.Lock()
	s.procRef = cmd
	s.startedAt = now
	s.lastUsed = now
	s.stateMu.Unlock()

	go drainStderr(s.capability, stderr)
	return nil
}

// drainStderr 把侧车 stderr 转发到服务日志（模型加载、进度、错误原因）。
func drainStderr(capability string, reader io.Reader) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 64*1024), 1<<20)
	for scanner.Scan() {
		if line := strings.TrimSpace(scanner.Text()); line != "" {
			log.Printf("[AI:%s] %s", capability, line)
		}
	}
}

// RunBatch 执行一个批次：确保进程存活 → 写入请求 → 读满响应。
//
// 返回的 results 可能少于 items（进程中途异常），调用方按 ID 匹配，
// 未匹配到的任务计为失败并进入重试。
func (s *Sidecar) RunBatch(ctx context.Context, params map[string]any, items []SidecarItem) ([]BatchResult, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.closed {
		return nil, fmt.Errorf("%s 侧车已关闭", s.capability)
	}
	if err := s.ensureRunning(); err != nil {
		return nil, err
	}

	expected := len(items)
	if expected == 0 {
		expected = 1 // ping 握手
	}

	if err := s.writeRequest(params, items); err != nil {
		s.killLocked()
		return nil, err
	}

	results := make([]BatchResult, 0, expected)
	var readErr error
	done := make(chan struct{})

	go func() {
		defer close(done)
		for len(results) < expected {
			line, err := s.stdout.ReadBytes('\n')
			if err != nil {
				readErr = err
				return
			}
			trimmed := strings.TrimSpace(string(line))
			if trimmed == "" {
				continue
			}
			var resp sidecarResponse
			if err := json.Unmarshal([]byte(trimmed), &resp); err != nil {
				readErr = fmt.Errorf("解析侧车响应失败: %w (原文: %.200s)", err, trimmed)
				return
			}
			results = append(results, BatchResult{
				ID:     resp.ID,
				OK:     resp.OK || resp.Ready,
				Error:  resp.Error,
				Result: resp.Result,
			})
			if resp.Ready {
				return // ping 只回一条
			}
		}
	}()

	select {
	case <-done:
		s.touch()
		if readErr != nil {
			s.killLocked()
			return results, fmt.Errorf("%s 侧车读取失败: %w", s.capability, readErr)
		}
		return results, nil
	case <-ctx.Done():
		s.killLocked()
		<-done
		return results, fmt.Errorf("%s 批次中断: %w", s.capability, ctx.Err())
	}
}

// touch 刷新最近使用时间（空闲回收依据）。
func (s *Sidecar) touch() {
	s.stateMu.Lock()
	s.lastUsed = time.Now()
	s.stateMu.Unlock()
}

func (s *Sidecar) writeRequest(params map[string]any, items []SidecarItem) error {
	writer := bufio.NewWriter(s.stdin)
	encoder := json.NewEncoder(writer)
	encoder.SetEscapeHTML(false)

	if params == nil {
		params = map[string]any{}
	}
	if err := encoder.Encode(sidecarHeader{
		V:          sidecarProtocolVersion,
		Capability: s.capability,
		Count:      len(items),
		Params:     params,
	}); err != nil {
		return fmt.Errorf("写入侧车请求头失败: %w", err)
	}
	for i, item := range items {
		payload := item
		if payload.ID == "" {
			payload.ID = fmt.Sprintf("%d", i)
		}
		if err := encoder.Encode(payload); err != nil {
			return fmt.Errorf("写入侧车请求条目失败: %w", err)
		}
	}
	if err := writer.Flush(); err != nil {
		return fmt.Errorf("刷新侧车请求失败: %w", err)
	}
	return nil
}

// supervise 周期性回收空闲进程（ticker 粒度 10s）。
func (s *Sidecar) supervise(ctx context.Context, idle time.Duration) {
	if idle <= 0 {
		idle = 120 * time.Second
	}
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.stateMu.RLock()
			running := s.procRef != nil
			idleFor := time.Since(s.lastUsed)
			s.stateMu.RUnlock()
			if running && idleFor >= idle {
				log.Printf("[AI:%s] 空闲 %s，退出侧车释放内存", s.capability, idleFor.Truncate(time.Second))
				s.Stop()
			}
		}
	}
}

// Stop 结束侧车进程（空闲回收 / 桌面端"释放模型"）。
//
// 刻意不取会话锁：批次可能正在运行且长达数分钟，取锁会让调用方一直挂着。
// 直接终止进程即可——正在进行的批次会收到读取错误并正常收尾。
func (s *Sidecar) Stop() {
	s.stateMu.RLock()
	proc := s.procRef
	s.stateMu.RUnlock()
	if proc != nil {
		killProcessTree(proc)
	}
}

// Shutdown 永久关闭该侧车（服务退出时调用）。
func (s *Sidecar) Shutdown() {
	s.stateMu.Lock()
	s.closed = true
	s.stateMu.Unlock()

	s.mu.Lock()
	s.stopLocked()
	s.mu.Unlock()
}

// stopLocked 关闭 stdin 让侧车自然退出，超时未退则强杀。
func (s *Sidecar) stopLocked() {
	if s.proc == nil {
		return
	}
	proc, stdin := s.proc, s.stdin
	s.proc, s.stdin, s.stdout = nil, nil, nil
	s.clearProcRef(proc)

	if stdin != nil {
		_ = stdin.Close()
	}
	if proc.Process == nil {
		return
	}

	done := make(chan struct{})
	go func() {
		_ = proc.Wait()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		killProcessTree(proc)
		<-done
	}
}

// killLocked 立即终止侧车（读写出错 / 超时中断时使用）。
func (s *Sidecar) killLocked() {
	if s.proc == nil {
		return
	}
	proc := s.proc
	s.proc, s.stdin, s.stdout = nil, nil, nil
	s.clearProcRef(proc)
	killProcessTree(proc)
	_ = proc.Wait()
}

// clearProcRef 清除进程引用（仅当仍是同一个进程时，避免误清新进程）。
func (s *Sidecar) clearProcRef(proc *exec.Cmd) {
	s.stateMu.Lock()
	if s.procRef == proc {
		s.procRef = nil
	}
	s.stateMu.Unlock()
}

// killProcessTree 终止主进程，并尽力清理整个进程树（Windows 下 taskkill）。
func killProcessTree(proc *exec.Cmd) {
	if proc == nil || proc.Process == nil {
		return
	}
	pid := proc.Process.Pid
	_ = proc.Process.Kill()
	if runtime.GOOS == "windows" {
		_ = exec.Command("taskkill", "/PID", fmt.Sprint(pid), "/T", "/F").Run()
	}
}

// SidecarState 侧车运行状态。
type SidecarState struct {
	Capability    string     `json:"capability"`
	Running       bool       `json:"running"`
	PID           int        `json:"pid"`
	StartedAt     *time.Time `json:"started_at"`
	LastUsedAt    *time.Time `json:"last_used_at"`
	IdleSeconds   int        `json:"idle_seconds"`
	IdleTimeoutS  int        `json:"idle_timeout_seconds"`
	Python        string     `json:"python"`
	ProbeOK       bool       `json:"probe_ok"`
	ProbeError    string     `json:"probe_error,omitempty"`
	MissingModels []string   `json:"missing_models,omitempty"`
}

// State 返回侧车状态快照（供 /status 与桌面端展示）。
//
// 只读 stateMu，绝不触碰会话锁——批次执行期间也必须能秒回状态。
func (s *Sidecar) State(ctx context.Context) SidecarState {
	state := SidecarState{
		Capability:   s.capability,
		IdleTimeoutS: int(s.cfg.IdleTimeout.Seconds()),
		Python:       s.resolvePython(),
	}

	s.stateMu.RLock()
	if proc := s.procRef; proc != nil && proc.Process != nil {
		state.Running = true
		state.PID = proc.Process.Pid
		started, used := s.startedAt, s.lastUsed
		state.StartedAt = &started
		state.LastUsedAt = &used
		state.IdleSeconds = int(time.Since(used).Seconds())
	}
	s.stateMu.RUnlock()

	if probe := s.Probe(ctx); probe != nil {
		state.ProbeOK = probe.OK
		state.ProbeError = probe.Error
		if probe.Python != "" {
			state.Python = probe.Python
		}
		for model, ok := range probe.Models {
			if !ok {
				state.MissingModels = append(state.MissingModels, model)
			}
		}
	}
	return state
}

// Warm 主动拉起侧车（桌面端"启动模型"，用于预热或验证依赖）。
func (s *Sidecar) Warm(ctx context.Context) error {
	_, err := s.RunBatch(ctx, nil, nil)
	return err
}
