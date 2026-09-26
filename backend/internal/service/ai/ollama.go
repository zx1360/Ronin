package ai

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
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
}

// NewOllama 创建 Ollama 客户端。
func NewOllama(cfg config.AiConfig) *Ollama {
	return &Ollama{
		cfg:    cfg,
		client: &http.Client{Timeout: 10 * time.Minute},
	}
}

// Available 报告服务是否可达且目标模型已安装。
func (o *Ollama) Available(ctx context.Context) (bool, string) {
	tags, err := o.ListModels(ctx)
	if err != nil {
		return false, err.Error()
	}
	if o.modelInList(tags) {
		return true, ""
	}
	return false, fmt.Sprintf("模型 %s 未安装（ollama pull %s）", o.cfg.OllamaVLM, o.cfg.OllamaVLM)
}

// Ready 报告该能力是否**具备执行条件**（不一定已在运行）。
//
// 与侧车的就绪语义保持一致：检查的是"依赖是否齐备"，而不是"进程是否已启动"。
// 服务未运行时，只要能找到 ollama 可执行文件就算就绪——真正执行时
// Generate 会经 EnsureReady 按需拉起；连可执行文件都没有才算不可用。
func (o *Ollama) Ready(ctx context.Context) (bool, string) {
	if ok, reason := o.Available(ctx); ok {
		return true, ""
	} else if o.resolveExe() == "" {
		return false, reason
	}
	// 可达但模型缺失的情况已在上面拦下；此处是"服务未启动但可按需拉起"
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
func (o *Ollama) EnsureReady(ctx context.Context) error {
	if _, err := o.ListModels(ctx); err == nil {
		return nil
	}

	exe := o.resolveExe()
	if exe == "" {
		return fmt.Errorf("Ollama 不可达且未找到 ollama 可执行文件（可配置 OLLAMA_EXE）")
	}

	o.mu.Lock()
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
		tags, err := o.ListModels(ctx)
		if err == nil {
			if o.modelInList(tags) {
				return nil
			}
			return fmt.Errorf(
				"ollama 已启动但看不到模型 %s：自拉的 ollama serve 使用的模型目录是 %q，"+
					"请在 backend/.env 里把 OLLAMA_MODELS 指向 Ollama 应用实际使用的模型目录",
				o.cfg.OllamaVLM, o.modelRoot())
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

// modelInList 判断目标模型是否在已安装列表中（容忍 tag 差异）。
func (o *Ollama) modelInList(tags []string) bool {
	for _, name := range tags {
		if name == o.cfg.OllamaVLM || strings.HasPrefix(name, o.cfg.OllamaVLM+":") {
			return true
		}
	}
	return false
}

// Generate 对单张图片执行一次 VLM 标注。
func (o *Ollama) Generate(ctx context.Context, imagePath string) (*vlmResult, error) {
	if err := o.EnsureReady(ctx); err != nil {
		return nil, err
	}
	// 推理可能要几分钟：开始就刷新时间戳，避免空闲回收在推理过程中把服务杀掉
	o.touch()

	raw, err := os.ReadFile(imagePath)
	if err != nil {
		return nil, fmt.Errorf("读取图片失败: %w", err)
	}

	body, err := json.Marshal(map[string]any{
		"model":  o.cfg.OllamaVLM,
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
	})
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, o.cfg.OllamaURL+"/api/generate", bytes.NewReader(body))
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

	o.touch()
	return &result, nil
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
			if idleFor < idle {
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
	URL         string   `json:"url"`
	Model       string   `json:"model"`
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
}

// State 返回 Ollama 状态快照。
func (o *Ollama) State(ctx context.Context) OllamaState {
	state := OllamaState{
		URL:       o.cfg.OllamaURL,
		Model:     o.cfg.OllamaVLM,
		NumCtx:    o.cfg.OllamaVLMCTX,
		KeepAlive: "Ollama 默认（无请求 5 分钟后卸载模型）",
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
	state.ModelReady = o.modelInList(models)
	if !state.ModelReady {
		state.Error = fmt.Sprintf("模型 %s 未安装", o.cfg.OllamaVLM)
	}
	return state
}
