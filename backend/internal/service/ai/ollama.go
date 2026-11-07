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
	cfg    config.AiConfig
	getCfg func() config.AiConfig

	client *http.Client

	mu       sync.Mutex
	proc     *exec.Cmd // 仅当我们自己拉起了 ollama serve 时非空
	lastUsed time.Time
	active   int
	// keepAlive 最近一次对话请求要求的模型驻留时长，用于放宽自拉服务的空闲回收
	keepAlive time.Duration
	closed    bool
	modelsMu  sync.Mutex
	models    []ModelInfo
	modelsAt  time.Time
}

// NewOllama 创建 Ollama 客户端。
//
// cfg 只保存启动期参数（可执行文件位置、模型库）；上下文长度、驻留时长与
// 空闲回收阈值随界面配置变化，统一从 getCfg 取当前快照。
func NewOllama(cfg config.AiConfig, getCfg func() config.AiConfig) *Ollama {
	return &Ollama{
		cfg:    cfg,
		getCfg: getCfg,
		client: &http.Client{Timeout: 10 * time.Minute},
	}
}

// currentConfig 返回当前配置快照（无提供者时退回启动期配置）。
func (o *Ollama) currentConfig() config.AiConfig {
	if o.getCfg == nil {
		return o.cfg
	}
	return o.getCfg()
}

// Ready 报告该能力是否**具备执行条件**（不一定已在运行）。
//
// 与侧车的就绪语义保持一致：检查的是"依赖是否齐备"，而不是"进程是否已启动"。
// 服务未运行时，只要能找到 ollama 可执行文件就算就绪——真正执行时
// Generate 会经 EnsureReady 按需拉起；连可执行文件都没有才算不可用。
func (o *Ollama) Ready(ctx context.Context, model string) (bool, string) {
	models, err := o.ListModelInfo(ctx)
	if err != nil {
		if o.resolveExe() != "" {
			return true, ""
		}
		return false, err.Error()
	}
	if err := o.checkModel(models, model); err != nil {
		return false, err.Error()
	}
	return true, ""
}

// ModelInfo 本机 Ollama 里的一个已安装模型。
type ModelInfo struct {
	Name       string
	Completion bool
	// Vision 该模型是否带视觉能力：文本模型同样能承接对话，但拿去跑 VLM 标注会整批失败。
	Vision bool
	// Thinking 该模型是否支持思考链（决定客户端是否展示"深度思考"开关）。
	Thinking bool
	digest   string
}

// visionFamilies 带视觉编码器的模型族；仅在 Ollama 未上报 capabilities 时作为兜底判断。
var visionFamilies = map[string]bool{
	"clip": true, "mllama": true, "llava": true, "vision": true, "siglip": true,
	"qwen2vl": true, "qwen3vl": true, "gemma3": true, "minicpmv": true,
	"pixtral": true, "mistral3": true,
}

// ListModels 返回本地已安装模型名。
func (o *Ollama) ListModels(ctx context.Context) ([]string, error) {
	models, err := o.ListModelInfo(ctx)
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(models))
	for _, m := range models {
		names = append(names, m.Name)
	}
	return names, nil
}

// ListModelInfo 返回本地已安装模型及其能力信息（模型列表的唯一真源）。
func (o *Ollama) ListModelInfo(ctx context.Context) ([]ModelInfo, error) {
	o.modelsMu.Lock()
	defer o.modelsMu.Unlock()
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if time.Since(o.modelsAt) >= 5*time.Second {
		models, err := o.loadModelInfo(ctx)
		if err != nil {
			return nil, err
		}
		o.models, o.modelsAt = models, time.Now()
	}
	return append([]ModelInfo(nil), o.models...), nil
}

func (o *Ollama) loadModelInfo(ctx context.Context) ([]ModelInfo, error) {
	reqCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(reqCtx, http.MethodGet, o.currentConfig().OllamaURL+"/api/tags", nil)
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
			Name         string   `json:"name"`
			Digest       string   `json:"digest"`
			Capabilities []string `json:"capabilities"`
			Details      struct {
				Family   string   `json:"family"`
				Families []string `json:"families"`
			} `json:"details"`
		} `json:"models"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, fmt.Errorf("解析 Ollama 模型列表失败: %w", err)
	}
	previous := make(map[string]ModelInfo, len(o.models))
	for _, info := range o.models {
		previous[info.Name] = info
	}
	models := make([]ModelInfo, 0, len(parsed.Models))
	for _, m := range parsed.Models {
		capabilities := m.Capabilities
		if len(capabilities) == 0 {
			if cached := previous[m.Name]; m.Digest != "" && cached.digest == m.Digest {
				models = append(models, cached)
				continue
			}
			capabilities = o.showCapabilities(reqCtx, m.Name)
		}
		info := ModelInfo{Name: m.Name, Completion: true}
		if len(capabilities) > 0 {
			info.digest = m.Digest
			info.Completion = hasCapability(capabilities, "completion")
			info.Vision = hasCapability(capabilities, "vision")
			info.Thinking = hasCapability(capabilities, "thinking")
		} else {
			// 老版本 Ollama 不上报 capabilities：退回模型族与名称的启发式判断
			families := append([]string{m.Details.Family}, m.Details.Families...)
			for _, family := range families {
				if visionFamilies[strings.ToLower(strings.TrimSpace(family))] {
					info.Vision = true
					break
				}
			}
			info.Thinking = SupportsThinking(m.Name)
		}
		models = append(models, info)
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return models, nil
}

// 部分 Ollama 版本只在 /api/show 返回能力。
func (o *Ollama) showCapabilities(ctx context.Context, name string) []string {
	body, _ := json.Marshal(map[string]string{"model": name})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, o.currentConfig().OllamaURL+"/api/show", bytes.NewReader(body))
	if err != nil {
		return nil
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := o.client.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	var parsed struct {
		Capabilities []string                   `json:"capabilities"`
		ModelInfo    map[string]json.RawMessage `json:"model_info"`
	}
	if resp.StatusCode != http.StatusOK || json.NewDecoder(resp.Body).Decode(&parsed) != nil {
		return nil
	}
	if len(parsed.Capabilities) == 0 {
		for key := range parsed.ModelInfo {
			if strings.HasSuffix(key, ".pooling_type") {
				return []string{"embedding"}
			}
		}
	}
	return parsed.Capabilities
}

// hasCapability 判断 Ollama 上报的 capabilities 里是否含某项（大小写不敏感）。
func hasCapability(capabilities []string, want string) bool {
	for _, item := range capabilities {
		if strings.EqualFold(strings.TrimSpace(item), want) {
			return true
		}
	}
	return false
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
func (o *Ollama) EnsureReady(ctx context.Context, model string) error {
	o.beginRequest()
	defer o.endRequest()
	if err := ctx.Err(); err != nil {
		return err
	}
	o.mu.Lock()
	closed := o.closed
	o.mu.Unlock()
	if closed {
		return errors.New("Ollama 客户端已关闭")
	}
	// 模型目录缓存不代表服务仍在线，执行前重新确认。
	o.RefreshModels()
	if models, err := o.ListModelInfo(ctx); err == nil {
		return o.checkModel(models, model)
	}

	exe := o.resolveExe()
	if exe == "" {
		return fmt.Errorf("Ollama 不可达且未找到 ollama 可执行文件（可配置 OLLAMA_EXE）")
	}

	o.mu.Lock()
	if o.closed || ctx.Err() != nil {
		o.mu.Unlock()
		return errors.New("Ollama 启动已取消")
	}
	if o.proc == nil {
		cmd := exec.Command(exe, "serve")
		// 继承本进程环境：若 backend/.env 里配置了 OLLAMA_MODELS（godotenv 会写入
		// 本进程环境），自拉的 serve 才能看到用户已有的模型库。
		cmd.Env = os.Environ()
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
			cmd.Process.Pid, os.Getenv("OLLAMA_MODELS"))
	}
	o.mu.Unlock()

	// 等待就绪（首次启动通常 1-3s）。区分"服务没起来"和"服务起来了但看不到模型"：
	// 后者几乎总是 OLLAMA_MODELS 指向了另一个（空的）模型目录。
	deadline := time.Now().Add(30 * time.Second)
	var lastErr error
	for time.Now().Before(deadline) {
		models, err := o.ListModelInfo(ctx)
		if err == nil {
			return o.checkModel(models, model)
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

func (o *Ollama) checkModel(models []ModelInfo, model string) error {
	if model == "" {
		return nil
	}
	for _, info := range models {
		if strings.EqualFold(info.Name, model) || strings.EqualFold(info.Name, model+":latest") {
			if !info.Completion {
				return fmt.Errorf("模型 %s 不支持对话生成", info.Name)
			}
			return nil
		}
	}
	return fmt.Errorf("模型 %s 未安装，请检查 Ollama 模型库（后端自启时使用 %q）", model, o.modelRoot())
}

func (o *Ollama) RefreshModels() {
	o.modelsMu.Lock()
	o.modelsAt = time.Time{}
	o.modelsMu.Unlock()
}

// Unload 立即卸载指定模型（释放显存）；模型本来就没加载时同样返回成功。
func (o *Ollama) Unload(ctx context.Context, model string) error {
	body, err := json.Marshal(map[string]any{
		"model":      model,
		"keep_alive": 0,
	})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, o.currentConfig().OllamaURL+"/api/generate", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := o.client.Do(req)
	if err != nil {
		return fmt.Errorf("卸载模型失败: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("卸载模型失败: Ollama 返回 %d", resp.StatusCode)
	}
	return nil
}

// modelRoot 返回自拉的 ollama serve 实际会使用的模型目录（仅用于错误提示）。
func (o *Ollama) modelRoot() string {
	if root := strings.TrimSpace(os.Getenv("OLLAMA_MODELS")); root != "" {
		return root
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "(默认目录)"
	}
	return filepath.Join(home, ".ollama", "models")
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
	o.beginRequest()
	defer o.endRequest()
	if err := o.EnsureReady(ctx, model); err != nil {
		return nil, err
	}

	raw, err := os.ReadFile(imagePath)
	if err != nil {
		return nil, fmt.Errorf("读取图片失败: %w", err)
	}

	cfg := o.currentConfig()
	body, err := json.Marshal(map[string]any{
		"model":  model,
		"prompt": vlmPrompt,
		"images": []string{base64.StdEncoding.EncodeToString(raw)},
		"stream": false,
		"format": "json",
		// 关闭思考链，避免推理耗尽输出预算而没有 JSON 结果。
		"think": false,
		// 不传 keep_alive，沿用 Ollama 自身的默认（5 分钟无请求再卸载）：
		// 批量标注之外还要承接后续的交互式视觉问答，每次都卸载会让模型反复重载。
		"options": map[string]any{
			"temperature": 0.2,
			"num_predict": 256,
			"num_ctx":     cfg.OllamaVLMCTX,
		},
	})
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, cfg.OllamaURL+"/api/generate", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := o.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("调用 Ollama 失败: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Ollama 返回 %d", resp.StatusCode)
	}

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
	JSON        bool
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
	o.beginRequest()
	defer o.endRequest()
	if err := o.EnsureReady(ctx, model); err != nil {
		return err
	}
	keepAlive := o.keepAliveSeconds(opt.KeepAliveSeconds)
	o.mu.Lock()
	o.keepAlive = time.Duration(keepAlive) * time.Second
	o.mu.Unlock()

	cfg := o.currentConfig()
	numCtx := opt.NumCtx
	if numCtx < 2048 {
		numCtx = cfg.OllamaVLMCTX
	}
	temperature := opt.Temperature
	if temperature < 0 {
		temperature = defaultTemperature
	}

	options := map[string]any{"temperature": temperature, "num_ctx": numCtx}
	payload := map[string]any{
		"model":      model,
		"messages":   messages,
		"stream":     true,
		"think":      opt.Think,
		"keep_alive": keepAlive,
		"options":    options,
	}
	if opt.JSON {
		payload["format"] = "json"
		options["num_predict"] = 256
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, cfg.OllamaURL+"/api/chat", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := o.client.Do(req)
	if err != nil {
		return fmt.Errorf("调用 Ollama 失败: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		detail, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("Ollama 返回 %d: %s", resp.StatusCode, strings.TrimSpace(string(detail)))
	}

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
			return fmt.Errorf("读取对话流失败: %w", err)
		}
		if chunk.Error != "" {
			_ = emit(ChatEvent{Type: "error", Error: chunk.Error})
			return errors.New(chunk.Error)
		}
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

// keepAliveSeconds 返回本次请求下发的 keep_alive（秒）。
//
// 0 是合法值（回答完立即卸载），因此只有负数才回落到服务端默认值。
func (o *Ollama) keepAliveSeconds(override int) int {
	if override >= 0 {
		return override
	}
	return int(o.currentConfig().OllamaKeepAlive.Seconds())
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

func (o *Ollama) beginRequest() {
	o.mu.Lock()
	o.active++
	o.mu.Unlock()
}

func (o *Ollama) endRequest() {
	o.mu.Lock()
	o.active--
	o.lastUsed = time.Now()
	o.mu.Unlock()
}

// supervise 仅回收"由我们拉起"的 ollama 进程；用户自启的实例不会被触碰。
//
// 回收阈值每次从当前配置读取：界面改小后无需重启进程即可生效。
func (o *Ollama) supervise(ctx context.Context) {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			idle := o.currentConfig().OllamaIdle
			if idle <= 0 {
				idle = 120 * time.Second
			}
			o.reapIdle(idle)
		}
	}
}

func (o *Ollama) reapIdle(idle time.Duration) {
	o.mu.Lock()
	defer o.mu.Unlock()
	idleFor := time.Since(o.lastUsed)
	if o.proc != nil && o.active == 0 && idleFor >= max(idle, o.keepAlive) {
		log.Printf("[AI:ollama] 空闲 %s，回收按需拉起的 ollama serve", idleFor.Truncate(time.Second))
		o.stopLocked()
	}
}

// StopServer 停止由本服务拉起的 ollama serve（用户自启的实例不受影响）。
func (o *Ollama) StopServer() {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.stopLocked()
}

func (o *Ollama) stopLocked() {
	if o.proc != nil {
		killProcessTree(o.proc)
		_ = o.proc.Wait()
		o.proc = nil
		o.keepAlive = 0
	}
}

// Shutdown 关闭客户端（服务退出时调用）。
func (o *Ollama) Shutdown() {
	o.mu.Lock()
	o.closed = true
	o.mu.Unlock()
	o.StopServer()
	o.client.CloseIdleConnections()
}

// OllamaState Ollama 运行状态快照。
type OllamaState struct {
	OllamaProcessState
	URL string `json:"url"`
	// Model 当前选定的 VLM 标注模型（空 = 尚未选定）
	Model      string   `json:"model"`
	NumCtx     int      `json:"num_ctx"`
	Reachable  bool     `json:"reachable"`
	ModelReady bool     `json:"model_ready"`
	Error      string   `json:"error,omitempty"`
	Models     []string `json:"models,omitempty"`
	// ModelRoot 自拉的 ollama serve 会使用的模型目录（OLLAMA_MODELS，未配置时为默认目录）；
	// 服务不可达时它是排查"拉起来了却看不到模型"的第一线索。
	ModelRoot string `json:"model_root"`
	// KeepAlive 说明模型驻留策略（沿用 Ollama 默认驻留策略）
	KeepAlive string `json:"keep_alive"`
	// KeepAliveDefaultSeconds 对话请求未指定时的模型驻留时长（"后端默认值"）
	KeepAliveDefaultSeconds int `json:"keep_alive_default_seconds"`
	// Thinking 模型是否支持思考链（决定客户端是否显示"深度思考"开关）
	Thinking bool `json:"thinking"`
}

type OllamaProcessState struct {
	ActiveModel string `json:"active_model"`
	LastSwitch  string `json:"last_switch,omitempty"`
	OwnedServer bool   `json:"owned_server"`
	PID         int    `json:"pid"`
	IdleSeconds int    `json:"idle_seconds"`
}

func (o *Ollama) ProcessState() OllamaProcessState {
	o.mu.Lock()
	defer o.mu.Unlock()
	state := OllamaProcessState{}
	if o.proc != nil && o.proc.Process != nil {
		state.OwnedServer = true
		state.PID = o.proc.Process.Pid
		if !o.lastUsed.IsZero() {
			state.IdleSeconds = int(time.Since(o.lastUsed).Seconds())
		}
	}
	return state
}

func (o *Ollama) snapshot(model string) OllamaState {
	cfg := o.currentConfig()
	state := OllamaState{
		OllamaProcessState:      o.ProcessState(),
		URL:                     cfg.OllamaURL,
		Model:                   model,
		NumCtx:                  cfg.OllamaVLMCTX,
		KeepAlive:               fmt.Sprintf("对话请求下发 %ds；批量标注沿用 Ollama 默认（无请求 5 分钟后卸载模型）", int(cfg.OllamaKeepAlive.Seconds())),
		KeepAliveDefaultSeconds: int(cfg.OllamaKeepAlive.Seconds()),
		Thinking:                SupportsThinking(model),
		ModelRoot:               o.modelRoot(),
	}

	return state
}

func (o *Ollama) State(ctx context.Context, model string) OllamaState {
	state := o.snapshot(model)
	models, err := o.ListModelInfo(ctx)
	if err != nil {
		state.Error = err.Error()
		// 服务未运行但可按需拉起时把话说完：否则界面只看到"不可达"，
		// 用户不知道点一下"启动模型"就能用。
		if o.resolveExe() != "" {
			state.Error = fmt.Sprintf("%s；可按需拉起（点「启动模型」，模型目录 %s）", state.Error, state.ModelRoot)
		}
		return state
	}
	state.Reachable = true
	names := make([]string, 0, len(models))
	for _, info := range models {
		names = append(names, info.Name)
	}
	state.Models = names
	if model != "" {
		if err := o.checkModel(models, model); err != nil {
			state.Error = err.Error()
		} else {
			state.ModelReady = true
		}
	}
	// 思考能力以 Ollama 上报为准（拿不到该模型时保留按名称判断的结果）
	for _, info := range models {
		if strings.EqualFold(info.Name, model) {
			state.Thinking = info.Thinking
			break
		}
	}
	return state
}
