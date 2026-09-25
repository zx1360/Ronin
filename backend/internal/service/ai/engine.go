// Package ai 实现"按需启动、空闲退出"的本地 AI 媒体处理层。
//
// 设计要点：
//   - 每类 AI 能力对应一个外部进程（Python 侧车）或外部服务（Ollama），
//     只在有任务时拉起，空闲超时后自动退出，不常驻占用内存；
//   - 处理单元持久化在 ai.jobs（PostgreSQL），支持失败重试、超时中断与进度查询；
//   - pHash 由 Go 进程内完成，不依赖任何外部工具；
//   - 向量检索在 Go 侧对 int8 量化向量做精确扫描，无需 pgvector。
package ai

import (
	"context"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"monarch/internal/config"
	"monarch/internal/repository/ai_repo"
)

// Default 全局引擎实例（由 cmd 装配后赋值，供 handler 使用）。
var Default *Engine

// MediaItem 一个待处理的媒体文件。
type MediaItem struct {
	MediaID string
	Path    string // 用于 AI 推理的绝对路径（优先预览图）
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
		log.Println("[AI] ai schema 未初始化，AI 能力停用（执行 references/db/ai.sql 后重启）")
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

	log.Printf("[AI] 处理层已启动（worker=%d 批大小=%d 侧车空闲退出=%s ollama 空闲回收=%s）",
		e.cfg.Workers, e.cfg.BatchSize, e.cfg.IdleTimeout, e.cfg.OllamaIdle)
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

// resolveItems 把媒体 ID 解析为可推理的文件项，并跳过文件缺失的媒体。
//
// 推理优先使用预览图：体积小、统一 JPEG、且已由入库流程生成，
// 可避免 HEIC/WebP 等格式在侧车里额外解码，也避免读取 GB 级原图。
func (e *Engine) resolveItems(mediaIDs []string) ([]MediaItem, []string, error) {
	ids, err := parseUUIDs(mediaIDs)
	if err != nil {
		return nil, nil, err
	}
	assets, err := fetchAssets(ids)
	if err != nil {
		return nil, nil, err
	}

	items := make([]MediaItem, 0, len(assets))
	var missing []string
	for _, asset := range assets {
		path := firstExisting(
			PreviewAbsPath(asset.PreviewPath),
			ThumbAbsPath(asset.ThumbPath),
			MediaAbsPath(asset.FilePath),
		)
		if path == "" {
			missing = append(missing, asset.ID.String())
			continue
		}
		items = append(items, MediaItem{MediaID: asset.ID.String(), Path: path})
	}
	return items, missing, nil
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
