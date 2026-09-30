package ai

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"monarch/internal/config"
)

// VLM 标注提示词：约束为 JSON，便于解析；关键词要求具体名词。
const vlmPrompt = `你是个人相册的标注助手。请用中文描述这张图片，并给出检索用关键词。
只输出 JSON，格式：{"caption":"一句话描述，不超过40字","tags":["关键词1","关键词2"]}
tags 要求 3-8 个，优先具体名词（人物、物体、场景、风格、情绪、作品名），不要"图片""照片"这类空泛词。`

// vlmResult VLM 返回结构。
type vlmResult struct {
	Caption string   `json:"caption"`
	Tags    []string `json:"tags"`
}

// Ollama 封装本地 Ollama 服务：按需拉起、请求后立即卸载模型。
type Ollama struct {
	cfg config.AiConfig

	client *http.Client

	mu       sync.Mutex
	proc     *exec.Cmd // 仅当我们自己拉起了 ollama serve 时非空
	lastUsed time.Time
	// keepAlive 最近一次对话请求要求的模型驻留时长，用于放宽自拉服务的空闲回收
	keepAlive time.Duration
}

// NewOllama 创建 Ollama 客户端。
func NewOllama(cfg config.AiConfig) *Ollama {
	return &Ollama{
		cfg:    cfg,
		client: &http.Client{Timeout: 10 * time.Minute},
	}
}

// Ready 报告该能力是否**具备执行条件**（不一定已在运行）。
//
// 与侧车的就绪语义保持一致：检查的是"依赖是否齐备"，而不是"进程是否已启动"。
// 三种情形必须分开：模型已装 → 就绪；服务可达但模型缺失 → 不可用（可按需拉起
// 也补不齐缺失的模型，谎报就绪只会让前端发起注定失败的推理）；服务未运行但
// 找得到可执行文件 → 就绪，真正执行时 EnsureReady 会按需拉起。
func (o *Ollama) Ready(ctx context.Context, model string) (bool, string) {
	model = strings.TrimSpace(model)
	if model == "" {
		return false, "未配置 VLM 模型（可在设置里填写 ai.vlm_model）"
	}
	tags, err := o.ListModels(ctx)
	if err == nil {
		if o.modelInList(tags, model) {
			return true, ""
		}
		return false, fmt.Sprintf("模型 %s 未安装（ollama pull %s）", model, model)
	}
	if o.resolveExe() == "" {
		return false, err.Error()
	}
	return true, ""
}

// ListModels 返回本地已安装模型名。
func (o *Ollama) ListModels(ctx context.Context) ([]string, error) {
	reqCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(reqCtx, http.MethodGet, o.cfg.OllamaURL+"/api/tags", nil)
	if err != nil {
		return nil, err
	}
	resp, err := o.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("Ollama 不可达: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Ollama 返回 %d", resp.StatusCode)
	}

	var parsed struct {
		Models []struct {
			Name string `json:"name"`
		} `json:"models"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, fmt.Errorf("解析 Ollama 模型列表失败: %w", err)
	}
	names := make([]string, 0, len(parsed.Models))
	for _, m := range parsed.Models {
		names = append(names, m.Name)
	}
	return names, nil
}

// sendJSON 是所有 Ollama 推理往返的公共出口：序列化请求体、构造请求、设置
// Content-Type、发送，并把传输错误与非 200 统一成可读错误（Ollama 把失败原因
// 写在响应体里，读出来才能诊断 400/404）。
//
// 返回的响应体由调用方关闭并解析——各协议的请求体与响应语义差别都在那之后，
// 刻意不在这里合并。ctx 取消即中断请求。
func (o *Ollama) sendJSON(ctx context.Context, path string, payload any) (*http.Response, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, o.cfg.OllamaURL+path, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := o.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("调用 Ollama 失败: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		detail, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		resp.Body.Close()
		return nil, fmt.Errorf("Ollama 返回 %d: %s", resp.StatusCode, strings.TrimSpace(string(detail)))
	}
	return resp, nil
}

// resolveExe 解析 ollama 可执行文件（未配置时从 PATH 查找）。
func (o *Ollama) resolveExe() string {
	if exe := strings.TrimSpace(o.cfg.OllamaExe); exe != "" {
		return exe
	}
	if path, err := exec.LookPath("ollama"); err == nil {
		return path
	}
	return ""
}

// EnsureReady 确保 Ollama 可用：已运行则直接复用（不接管用户自启的实例），
// 未运行且能找到可执行文件时按需拉起，并在空闲后由 supervise 回收。
//
// 服务已在运行时也必须核对模型是否安装：拉得起服务不等于拉得起缺失的模型。
func (o *Ollama) EnsureReady(ctx context.Context, model string) error {
	model = strings.TrimSpace(model)
	if model == "" {
		return fmt.Errorf("未配置 VLM 模型（可在设置里填写 ai.vlm_model）")
	}
	if tags, err := o.ListModels(ctx); err == nil {
		if o.modelInList(tags, model) {
			return nil
		}
		return fmt.Errorf("Ollama 已运行但未安装模型 %s（ollama pull %s）", model, model)
	}

	exe := o.resolveExe()
	if exe == "" {
		return fmt.Errorf("Ollama 不可达且未找到 ollama 可执行文件（可在设置里填写 ai.ollama.exe）")
	}

	o.mu.Lock()
	if o.proc == nil {
		cmd := exec.Command(exe, "serve")
		// 继承本进程环境后覆盖 OLLAMA_MODELS：该设置由 ops 页面写入 app_settings，
		// 是模型库位置的唯一真相源（见 settings 的 ai.ollama.models）。
		cmd.Env = o.childEnv()
		if err := cmd.Start(); err != nil {
			o.mu.Unlock()
			return fmt.Errorf("启动 ollama serve 失败: %w", err)
		}
		// 降到前台之下（只降一档：推理本身延迟敏感，不能再低）
		if err := yieldToInteractive(cmd.Process.Pid); err != nil {
			log.Printf("[AI:ollama] 降低进程优先级失败（不影响推理）: %v", err)
		}
		o.proc = cmd
		// 必须同时初始化 lastUsed：否则 supervise 会算出"自零时刻起已空闲"，
		// 在新进程刚起来的第一个 tick 就把它回收掉。
		o.lastUsed = time.Now()
		log.Printf("[AI:ollama] 已按需启动 ollama serve (pid=%d, OLLAMA_MODELS=%q)",
			cmd.Process.Pid, o.modelRoot())
	}
	o.mu.Unlock()

	// 等待就绪（首次启动通常 1-3s）。区分"服务没起来"和"服务起来了但看不到模型"：
	// 后者几乎总是模型库目录指向了另一个（空的）目录。
	deadline := time.Now().Add(30 * time.Second)
	var lastErr error
	for time.Now().Before(deadline) {
		tags, err := o.ListModels(ctx)
		if err == nil {
			if o.modelInList(tags, model) {
				return nil
			}
			return fmt.Errorf(
				"ollama 已启动但看不到模型 %s：自拉的 ollama serve 使用的模型库目录是 %q，"+
					"请在 ops 设置页把 ai.ollama.models 指向 Ollama 应用实际使用的模型目录",
				model, o.modelRoot())
		}
		lastErr = err
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(time.Second):
		}
	}
	return fmt.Errorf("ollama serve 启动后仍未就绪: %v", lastErr)
}

// Unload 立即卸载指定模型（释放显存）；模型本来就没加载时同样返回成功。
func (o *Ollama) Unload(ctx context.Context, model string) error {
	resp, err := o.sendJSON(ctx, "/api/generate", map[string]any{
		"model":      model,
		"keep_alive": 0,
	})
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

// modelRoot 返回自拉的 ollama serve 实际会使用的模型库目录。
//
// 配置项优先（app_settings 的 ai.ollama.models），其次环境变量，最后 Ollama 默认目录。
func (o *Ollama) modelRoot() string {
	if root := strings.TrimSpace(o.cfg.OllamaModels); root != "" {
		return root
	}
	if root := strings.TrimSpace(os.Getenv("OLLAMA_MODELS")); root != "" {
		return root
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "(默认目录)"
	}
	return filepath.Join(home, ".ollama", "models")
}

// childEnv 返回自拉 ollama serve 的环境：继承本进程后固定 OLLAMA_MODELS。
func (o *Ollama) childEnv() []string {
	root := strings.TrimSpace(o.modelRoot())
	if root == "" {
		return os.Environ()
	}
	env := os.Environ()
	out := make([]string, 0, len(env)+1)
	for _, kv := range env {
		if strings.HasPrefix(kv, "OLLAMA_MODELS=") {
			continue
		}
		out = append(out, kv)
	}
	return append(out, "OLLAMA_MODELS="+root)
}

// modelInList 判断目标模型是否在已安装列表中（容忍 tag 差异）。
func (o *Ollama) modelInList(tags []string, model string) bool {
	for _, name := range tags {
		if name == model || strings.HasPrefix(name, model+":") {
			return true
		}
	}
	return false
}

// SupportsThinking 粗略判断模型是否支持思考链，决定客户端是否展示"深度思考"开关。
// 去掉命名空间前缀后再判断，否则 huihui_ai/qwen3.5-abliterated:4b 这类社区模型会被漏判。
func SupportsThinking(model string) bool {
	name := strings.ToLower(model)
	if i := strings.LastIndex(name, "/"); i >= 0 {
		name = name[i+1:]
	}
	return strings.HasPrefix(name, "qwen3") ||
		strings.HasPrefix(name, "deepseek-r1") ||
		strings.Contains(name, "thinking")
}

// Generate 对单张图片执行一次 VLM 标注。
func (o *Ollama) Generate(ctx context.Context, model, imagePath string) (*vlmResult, error) {
	if err := o.EnsureReady(ctx, model); err != nil {
		return nil, err
	}
	// 推理可能要几分钟：开始就刷新时间戳，避免空闲回收在推理过程中把服务杀掉
	o.touch()

	raw, err := os.ReadFile(imagePath)
	if err != nil {
		return nil, fmt.Errorf("读取图片失败: %w", err)
	}

	body := map[string]any{
		"model":  model,
		"prompt": vlmPrompt,
		"images": []string{base64.StdEncoding.EncodeToString(raw)},
		"stream": false,
		"format": "json",
		// 关闭思考链：qwen3.5 默认 think=true，会把 num_predict 全用在推理上，
		// 实测 256 token 耗尽后 response 为空 → 每张图都解析失败且慢 10 倍以上。
		// 标注只要求"看到什么"，不需要推理。
		"think": false,
		// 不传 keep_alive，沿用 Ollama 自身的默认（5 分钟无请求再卸载）：
		// 批量标注之外还要承接后续的交互式视觉问答，每次都卸载会让模型反复重载。
		"options": map[string]any{
			"temperature": 0.2,
			"num_predict": 256,
			"num_ctx":     o.cfg.OllamaVLMCTX,
		},
	}

	resp, err := o.sendJSON(ctx, "/api/generate", body)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var parsed struct {
		Response string `json:"response"`
		Error    string `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, fmt.Errorf("解析 Ollama 响应失败: %w", err)
	}
	if parsed.Error != "" {
		return nil, errors.New(parsed.Error)
	}

	// Ollama 的 format=json 保证是合法 JSON，但模型仍可能包一层代码块
	payload := extractJSONObject(parsed.Response)
	if payload == "" {
		return nil, fmt.Errorf("VLM 未返回可解析的 JSON: %.200s", parsed.Response)
	}

	var result vlmResult
	if err := json.Unmarshal([]byte(payload), &result); err != nil {
		return nil, fmt.Errorf("解析 VLM 标注失败: %w", err)
	}
	result.Caption = strings.TrimSpace(result.Caption)

	// 清洗关键词：去空白、去重、限长
	seen := map[string]bool{}
	cleaned := make([]string, 0, len(result.Tags))
	for _, tag := range result.Tags {
		tag = strings.TrimSpace(tag)
		if tag == "" || len([]rune(tag)) > 20 || seen[tag] {
			continue
		}
		seen[tag] = true
		cleaned = append(cleaned, tag)
	}
	result.Tags = cleaned

	o.touch()
	return &result, nil
}

// ---------------------------------------------------------------------------
// 交互式对话（流式）
// ---------------------------------------------------------------------------

// ChatMessage 一条对话消息。图片以 base64 内联（与 Ollama 协议一致，不含 data: 前缀）。
type ChatMessage struct {
	Role    string   `json:"role"`
	Content string   `json:"content"`
	Images  []string `json:"images,omitempty"`
}

// ChatOptions 单次对话的可调项。Temperature 为负表示沿用默认值。
type ChatOptions struct {
	NumCtx      int
	Think       bool
	Temperature float64
	// KeepAliveSeconds 模型驻留秒数：负数 = 沿用服务端默认（OLLAMA_KEEP_ALIVE），
	// 0 = 回答完立即卸载，正数 = 显式驻留时长。
	KeepAliveSeconds int
}

// ChatEvent 流式事件，逐行以 JSON 下发。
type ChatEvent struct {
	Type      string `json:"type"` // delta / thinking / done / error
	Content   string `json:"content,omitempty"`
	Error     string `json:"error,omitempty"`
	EvalCount int    `json:"eval_count,omitempty"`
	TotalMs   int64  `json:"total_duration_ms,omitempty"`
}

// defaultTemperature 未指定时的采样温度。
const defaultTemperature = 0.7

// Chat 执行一次多轮对话并把增量结果推给 onEvent（nil 表示只消费不回调）。
//
// 流式而非一次性返回：思考链与回答都要逐字出现，否则首字节要等几十秒。
func (o *Ollama) Chat(ctx context.Context, model string, messages []ChatMessage, opt ChatOptions, onEvent func(ChatEvent) error) error {
	if err := o.EnsureReady(ctx, model); err != nil {
		return err
	}
	// 推理可能要几分钟：开始就刷新时间戳，避免空闲回收在推理过程中把服务杀掉
	o.touch()
	o.setKeepAlive(opt.KeepAliveSeconds)

	numCtx := opt.NumCtx
	if numCtx < 2048 {
		numCtx = o.cfg.OllamaVLMCTX
	}
	temperature := opt.Temperature
	if temperature < 0 {
		temperature = defaultTemperature
	}

	body := map[string]any{
		"model":      model,
		"messages":   messages,
		"stream":     true,
		"think":      opt.Think,
		"keep_alive": o.keepAliveSeconds(opt.KeepAliveSeconds),
		"options": map[string]any{
			"temperature": temperature,
			"num_ctx":     numCtx,
		},
	}

	resp, err := o.sendJSON(ctx, "/api/chat", body)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	emit := func(event ChatEvent) error {
		if onEvent == nil {
			return nil
		}
		return onEvent(event)
	}

	decoder := json.NewDecoder(resp.Body)
	for {
		var chunk struct {
			Message struct {
				Content  string `json:"content"`
				Thinking string `json:"thinking"`
			} `json:"message"`
			Done          bool   `json:"done"`
			Error         string `json:"error"`
			EvalCount     int    `json:"eval_count"`
			TotalDuration int64  `json:"total_duration"`
		}
		if err := decoder.Decode(&chunk); err != nil {
			if errors.Is(err, io.EOF) {
				return nil
			}
			return fmt.Errorf("读取对话流失败: %w", err)
		}
		if chunk.Error != "" {
			_ = emit(ChatEvent{Type: "error", Error: chunk.Error})
			return errors.New(chunk.Error)
		}
		o.touch()
		if chunk.Message.Thinking != "" {
			if err := emit(ChatEvent{Type: "thinking", Content: chunk.Message.Thinking}); err != nil {
				return err
			}
		}
		if chunk.Message.Content != "" {
			if err := emit(ChatEvent{Type: "delta", Content: chunk.Message.Content}); err != nil {
				return err
			}
		}
		if chunk.Done {
			return emit(ChatEvent{
				Type:      "done",
				EvalCount: chunk.EvalCount,
				TotalMs:   chunk.TotalDuration / int64(time.Millisecond),
			})
		}
	}
}

// setKeepAlive 记录本次请求要求的模型驻留时长（忽略非正值）。
func (o *Ollama) setKeepAlive(seconds int) {
	if seconds <= 0 {
		return
	}
	o.mu.Lock()
	o.keepAlive = time.Duration(seconds) * time.Second
	o.mu.Unlock()
}

// keepAliveSeconds 返回本次请求下发的 keep_alive（秒）。
//
// 0 是合法值（回答完立即卸载），因此只有负数才回落到服务端默认值。
func (o *Ollama) keepAliveSeconds(override int) int {
	if override >= 0 {
		return override
	}
	return int(o.cfg.OllamaKeepAlive.Seconds())
}

// idleLimit 返回自拉 ollama serve 的回收阈值：不小于配置值，且覆盖用户要求的驻留时长
// （否则用户把驻留调到 30 分钟，服务却在 6 分钟时被回收，设置形同虚设）。
func (o *Ollama) idleLimit(base time.Duration) time.Duration {
	o.mu.Lock()
	keepAlive := o.keepAlive
	o.mu.Unlock()
	if keepAlive > base {
		return keepAlive
	}
	return base
}

// extractJSONObject 从模型输出中截取第一个完整的 JSON 对象。
func extractJSONObject(raw string) string {
	start := strings.Index(raw, "{")
	end := strings.LastIndex(raw, "}")
	if start < 0 || end <= start {
		return ""
	}
	return raw[start : end+1]
}

func (o *Ollama) touch() {
	o.mu.Lock()
	o.lastUsed = time.Now()
	o.mu.Unlock()
}

// supervise 仅回收"由我们拉起"的 ollama 进程；用户自启的实例不会被触碰。
func (o *Ollama) supervise(ctx context.Context, idle time.Duration) {
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
			o.mu.Lock()
			owned := o.proc != nil
			lastUsed := o.lastUsed
			o.mu.Unlock()
			if !owned || lastUsed.IsZero() {
				// 未记录使用时间时按"刚刚用过"处理：绝不能当成"空闲了 292 年"
				// 而把刚拉起的进程立刻回收。
				continue
			}
			idleFor := time.Since(lastUsed)
			if idleFor < o.idleLimit(idle) {
				continue
			}
			log.Printf("[AI:ollama] 空闲 %s，回收按需拉起的 ollama serve", idleFor.Truncate(time.Second))
			o.StopServer()
		}
	}
}

// StopServer 停止由本服务拉起的 ollama serve（用户自启的实例不受影响）。
func (o *Ollama) StopServer() {
	o.mu.Lock()
	proc := o.proc
	o.proc = nil
	o.mu.Unlock()
	if proc != nil {
		killProcessTree(proc)
	}
}

// Shutdown 关闭客户端（服务退出时调用）。
func (o *Ollama) Shutdown() {
	o.StopServer()
}

// OllamaState Ollama 运行状态快照。
type OllamaState struct {
	URL string `json:"url"`
	// Model 当前生效的 VLM 标注模型；ModelDefault/ModelAlt 为两个候选（默认 / 无审查版）
	Model        string `json:"model"`
	ModelDefault string `json:"model_default"`
	ModelAlt     string `json:"model_alt"`
	ActiveModel  string `json:"active_model"` // 当前正在推理的模型（空 = 空闲）
	// LastSwitch 最近一次"后台批次被前台对话抢占"的说明（空 = 无）
	LastSwitch  string   `json:"last_switch,omitempty"`
	NumCtx      int      `json:"num_ctx"`
	Reachable   bool     `json:"reachable"`
	ModelReady  bool     `json:"model_ready"`
	Error       string   `json:"error,omitempty"`
	OwnedServer bool     `json:"owned_server"` // true 表示进程由本服务按需拉起
	PID         int      `json:"pid"`
	IdleSeconds int      `json:"idle_seconds"`
	Models      []string `json:"models,omitempty"`
	// KeepAlive 说明模型驻留策略（沿用 Ollama 默认，不再逐次卸载）
	KeepAlive string `json:"keep_alive"`
	// KeepAliveDefaultSeconds 对话请求未指定时的模型驻留时长（"后端默认值"）
	KeepAliveDefaultSeconds int `json:"keep_alive_default_seconds"`
	// Thinking 模型是否支持思考链（决定客户端是否显示"深度思考"开关）
	Thinking bool `json:"thinking"`
}

// State 返回 Ollama 状态快照；model 为当前生效的 VLM 模型。
func (o *Ollama) State(ctx context.Context, model, modelAlt string) OllamaState {
	state := OllamaState{
		URL:                     o.cfg.OllamaURL,
		Model:                   model,
		ModelDefault:            o.cfg.OllamaVLM,
		ModelAlt:                modelAlt,
		NumCtx:                  o.cfg.OllamaVLMCTX,
		KeepAlive:               fmt.Sprintf("对话请求下发 %ds；批量标注沿用 Ollama 默认（无请求 5 分钟后卸载模型）", int(o.cfg.OllamaKeepAlive.Seconds())),
		KeepAliveDefaultSeconds: int(o.cfg.OllamaKeepAlive.Seconds()),
		Thinking:                SupportsThinking(model),
	}

	o.mu.Lock()
	if o.proc != nil && o.proc.Process != nil {
		state.OwnedServer = true
		state.PID = o.proc.Process.Pid
		if !o.lastUsed.IsZero() {
			state.IdleSeconds = int(time.Since(o.lastUsed).Seconds())
		}
	}
	o.mu.Unlock()

	models, err := o.ListModels(ctx)
	if err != nil {
		state.Error = err.Error()
		return state
	}
	state.Reachable = true
	state.Models = models
	state.ModelReady = o.modelInList(models, model)
	if !state.ModelReady {
		state.Error = fmt.Sprintf("模型 %s 未安装", model)
	}
	return state
}
