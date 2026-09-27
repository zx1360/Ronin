// Package ai 实现"按需启动、空闲退出"的本地 AI 媒体处理层。
//
// 设计要点：
//   - 每类 AI 能力对应一个外部进程（Python 侧车）或外部服务（Ollama），
//     只在有任务时拉起，空闲超时后自动退出，不常驻占用内存；
//   - 处理单元持久化在 ai_jobs（SQLite），支持失败重试、超时中断与进度查询；
//   - pHash 由 Go 进程内完成，不依赖任何外部工具；
//   - 向量检索在 Go 侧对 int8 量化向量做精确扫描，不依赖任何向量扩展。
package ai

import (
	"context"
	"encoding/base64"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
)

// Default 全局引擎实例（由 cmd 装配后赋值，供 handler 使用）。
var Default *Engine

// MediaItem 一个待处理的媒体文件。
type MediaItem struct {
	MediaID string
	Path    string // 用于 AI 推理的绝对路径（按能力的输入档位解析）
	Tier    string // 实际使用的输入档位，写入 ai_results 供溯源
}

// Engine AI 处理层门面：进程监管 + 任务队列 + 检索索引 + 分组。
type Engine struct {
	cfg     config.AiConfig
	started bool

	embed  *Sidecar
	text   *Sidecar
	face   *Sidecar
	ocr    *Sidecar
	ollama *Ollama

	index   *Index
	cluster *Clusterer

	// arbiter 串行化本地模型（同一时刻只跑一个，见 models.go）
	arbiter modelArbiter

	wake     chan struct{}
	cancel   context.CancelFunc
	stopOnce sync.Once

	// 最近一次批次执行信息（供 /status 展示）
	runMu       sync.RWMutex
	lastRun     *RunInfo
	runCancelMu sync.Mutex
	runCancel   context.CancelFunc

	// cancelRequested 区分"用户主动中断"与"超时失败"
	cancelRequested atomic.Bool
	// paused 用户暂停队列：中断当前批次后不再认领新任务，直到 Resume
	paused atomic.Bool
	// clusterRun 串行化重新聚类操作
	clusterRun sync.Mutex

	// "尚无产物"统计的缓存（整表扫描，不能每次状态轮询都算；异步刷新）
	missingMu          sync.Mutex
	missingCountsCache map[string]int
	missingAt          time.Time
	missingRefreshing  bool
}

// RunInfo 描述当前/最近一次批次执行。
type RunInfo struct {
	Capability string    `json:"capability"`
	Total      int       `json:"total"`     // 本批任务数
	Processed  int       `json:"processed"` // 已写库条数
	Failed     int       `json:"failed"`
	StartedAt  time.Time `json:"started_at"`
	Running    bool      `json:"running"`
}

// New 构建引擎（不启动任何外部进程）。
func New(cfg config.AiConfig) *Engine {
	e := &Engine{
		cfg:   cfg,
		wake:  make(chan struct{}, 1),
		index: NewIndex(cfg.EmbedModel),
	}
	e.embed = NewSidecar("embed", cfg)
	e.text = NewSidecar("embed_text", cfg)
	e.face = NewSidecar("face", cfg)
	e.ocr = NewSidecar("ocr", cfg)
	e.ollama = NewOllama(cfg)
	e.cluster = NewClusterer()
	return e
}

// Start 启动后台循环；AI 未启用或 schema 缺失时安全退出（不影响主服务）。
func (e *Engine) Start() {
	if !e.cfg.Enabled {
		log.Println("[AI] 已通过 AI_ENABLED=false 关闭，跳过启动")
		return
	}
	if !ai_repo.SchemaReady(context.Background()) {
		log.Println("[AI] AI 数据表缺失，AI 能力停用（检查 DB_PATH 指向的库是否正确）")
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	e.cancel = cancel
	e.started = true

	// 服务刚启动，不可能有本进程的任务在跑：把遗留的 running 全部回收
	if n, err := ai_repo.RecoverStaleRunning(0, e.cfg.MaxAttempts); err != nil {
		log.Printf("[AI] 回收孤儿任务失败: %v", err)
	} else if n > 0 {
		log.Printf("[AI] 已回收 %d 条中断任务", n)
	}

	go e.reconcileLoop(ctx)
	go e.workerLoop(ctx)
	for _, s := range e.sidecars() {
		go s.supervise(ctx, e.cfg.IdleTimeout)
	}
	go e.ollama.supervise(ctx, e.cfg.OllamaIdle)

	log.Printf("[AI] 处理层已启动（批大小=%d 侧车空闲退出=%s ollama 空闲回收=%s）",
		e.cfg.BatchSize, e.cfg.IdleTimeout, e.cfg.OllamaIdle)
}

// Stop 停止全部后台循环并回收外部进程（服务退出时调用）。
func (e *Engine) Stop() {
	e.stopOnce.Do(func() {
		if e.cancel != nil {
			e.cancel()
		}
		for _, s := range e.sidecars() {
			s.Shutdown()
		}
		e.ollama.Shutdown()
	})
}

// Wake 唤醒 worker 立即检查队列（入队后调用，避免等待轮询间隔）。
func (e *Engine) Wake() {
	select {
	case e.wake <- struct{}{}:
	default:
	}
}

func (e *Engine) sidecars() []*Sidecar {
	return []*Sidecar{e.embed, e.text, e.face, e.ocr}
}

// ---------------------------------------------------------------------------
// 路径解析
// ---------------------------------------------------------------------------

// MediaAbsPath 返回原始媒体文件的绝对路径。
func MediaAbsPath(filePath string) string {
	return filepath.Join(config.AppConf.GalleryDir, "Media", filepath.FromSlash(filePath))
}

// PreviewAbsPath 返回预览图绝对路径（无预览图时返回空串）。
func PreviewAbsPath(previewPath *string) string {
	if previewPath == nil || strings.TrimSpace(*previewPath) == "" {
		return ""
	}
	return filepath.Join(config.AppConf.GalleryDir, "Preview", filepath.FromSlash(*previewPath))
}

// ThumbAbsPath 返回缩略图绝对路径（无缩略图时返回空串）。
func ThumbAbsPath(thumbPath *string) string {
	if thumbPath == nil || strings.TrimSpace(*thumbPath) == "" {
		return ""
	}
	return filepath.Join(config.AppConf.GalleryDir, "Thumbs", filepath.FromSlash(*thumbPath))
}

// firstExisting 返回第一个真实存在的路径（全部不存在时返回空串）。
func firstExisting(paths ...string) string {
	for _, p := range paths {
		if p == "" {
			continue
		}
		if fi, err := os.Stat(p); err == nil && !fi.IsDir() {
			return p
		}
	}
	return ""
}

// resolveItems 按能力准备输入文件项，并跳过无法准备输入的媒体。
//
// 输入档位由能力决定（见 model.AIInputTier）：
//   - phash / embed 用 256 预览图：体积小、统一 JPEG，判据本身也不需要更高分辨率；
//     预览缺失时退回缩略图/原图，档位仍记为 preview256（同一档位族，不构成规格失配）；
//   - face / ocr / vlm 用长边 1024 的 AI 专用派生档（按需生成并缓存），
//     256 图上的小字与人脸细节不足以支撑检测与识别。派生档生成失败即视为该媒体
//     处理失败（原因一并返回），否则"登记低档 + 期望高档"会让它被无限重排。
//
// 每项都带上**实际使用**的档位，供结果溯源如实登记。
func (e *Engine) resolveItems(capability string, mediaIDs []string) ([]MediaItem, map[string]string, error) {
	ids, err := parseUUIDs(mediaIDs)
	if err != nil {
		return nil, nil, err
	}
	assets, err := fetchAssets(ids)
	if err != nil {
		return nil, nil, err
	}

	useAITier := model.AIInputTier(capability) == model.TierAI1024

	items := make([]MediaItem, 0, len(assets))
	failed := map[string]string{}
	for _, asset := range assets {
		path, tier := "", ""
		if useAITier {
			path, tier, err = e.ensureAITier(asset)
			if err != nil {
				failed[asset.ID.String()] = fmt.Sprintf("生成 %s 派生档失败: %v", capability, err)
				continue
			}
		} else {
			path = firstExisting(
				PreviewAbsPath(asset.PreviewPath),
				ThumbAbsPath(asset.ThumbPath),
				MediaAbsPath(asset.FilePath),
			)
			tier = model.TierPreview256
		}
		if path == "" {
			failed[asset.ID.String()] = "媒体文件缺失"
			continue
		}
		items = append(items, MediaItem{MediaID: asset.ID.String(), Path: path, Tier: tier})
	}
	return items, failed, nil
}

// VLMModel 返回当前生效的 VLM 模型（数据库设置优先，其次进程配置）。
//
// 数据库不可用时退回进程配置：模型选择不应让整个 AI 层不可用。
func (e *Engine) VLMModel() string {
	if model := ai_repo.VLMModel(); model != "" {
		return model
	}
	return e.cfg.OllamaVLM
}

// VLMAltModel 返回备选（无审查版）模型名，供两端做模型切换。
func (e *Engine) VLMAltModel() string { return e.cfg.OllamaVLMAlt }

// ResolveChatImages 把媒体 ID 批量解析为 base64 图片，供对话请求内联发送。
//
// 与 vlm 标注走同一套路径解析（即 ai1024 派生档），手机端因此无需把原图下载再上传；
// 派生档生成失败时会退回预览图。
// 返回的 missing 为不可用的媒体 ID（不存在或文件读取失败），调用方应据此报错
// 而不是静默丢图——用户会疑惑"为什么 AI 看不到这张图"。
func (e *Engine) ResolveChatImages(mediaIDs []string) (map[string]string, []string, error) {
	items, _, err := e.resolveItems(model.CapVLM, mediaIDs)
	if err != nil {
		return nil, nil, err
	}
	images := make(map[string]string, len(items))
	for _, item := range items {
		raw, err := os.ReadFile(item.Path)
		if err != nil {
			continue
		}
		images[item.MediaID] = base64.StdEncoding.EncodeToString(raw)
	}

	var missing []string
	for _, raw := range mediaIDs {
		if id := strings.TrimSpace(raw); id != "" {
			if _, ok := images[id]; !ok {
				missing = append(missing, id)
			}
		}
	}
	return images, missing, nil
}

// IgnoredDuplicates 返回被人工标记为"非重复"的媒体资产。
func (e *Engine) IgnoredDuplicates() ([]model.MediaAsset, error) {
	ids, err := ai_repo.ListDuplicateIgnoreIDs()
	if err != nil {
		return nil, err
	}
	return fetchAssets(ids)
}

// ---------------------------------------------------------------------------
// 运行信息
// ---------------------------------------------------------------------------
func (e *Engine) setRun(info *RunInfo) {
	e.runMu.Lock()
	e.lastRun = info
	e.runMu.Unlock()
}

// LastRun 返回最近一次批次执行信息的副本。
func (e *Engine) LastRun() *RunInfo {
	e.runMu.RLock()
	defer e.runMu.RUnlock()
	if e.lastRun == nil {
		return nil
	}
	copied := *e.lastRun
	return &copied
}
