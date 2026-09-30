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
	"encoding/base64"
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
	Path    string // 用于 AI 推理的绝对路径（按能力档位解析而来）
	Tier    string // 实际使用的输入档位
}

// Engine AI 处理层门面：进程监管 + 任务队列 + 检索索引 + 分组。
type Engine struct {
	rt      *runtimeStore
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
//
// store 为运行时配置文件存储；引擎全程读取它提供的配置快照，因此界面改完配置
// 立即生效，无需重建引擎。
func New(store *config.ConfigStore, cfg config.AiConfig) *Engine {
	rt := newRuntimeStore(store, cfg)
	if store != nil {
		if model := store.Snapshot().VLMModel; model != nil {
			rt.vlmModel = *model
		}
	}
	e := &Engine{
		rt:    rt,
		wake:  make(chan struct{}, 1),
		index: NewIndex(cfg.EmbedModel),
	}
	e.embed = NewSidecar("embed", cfg, e.Config)
	e.text = NewSidecar("embed_text", cfg, e.Config)
	e.face = NewSidecar("face", cfg, e.Config)
	e.ocr = NewSidecar("ocr", cfg, e.Config)
	e.ollama = NewOllama(cfg, e.Config)
	e.cluster = NewClusterer()
	return e
}

// Config 返回当前生效的 AI 配置副本。
func (e *Engine) Config() config.AiConfig { return e.rt.Config() }

// ConfigPath 返回运行时配置文件路径（空串表示未启用文件存储）。
func (e *Engine) ConfigPath() string { return e.rt.StorePath() }

// Start 启动后台循环；AI 未启用或 schema 缺失时安全退出（不影响主服务）。
func (e *Engine) Start() {
	cfg := e.Config()
	if !cfg.Enabled {
		log.Println("[AI] 已通过 AI_ENABLED=false 关闭，跳过启动")
		return
	}
	if !ai_repo.SchemaReady(context.Background()) {
		log.Println("[AI] ai schema 未初始化，AI 能力停用（执行 references/db/sqlite.sql 后重启）")
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	e.cancel = cancel
	e.started = true

	// 服务刚启动，不可能有本进程的任务在跑：把遗留的 running 全部回收
	if n, err := ai_repo.RecoverStaleRunning(0, cfg.MaxAttempts); err != nil {
		log.Printf("[AI] 回收孤儿任务失败: %v", err)
	} else if n > 0 {
		log.Printf("[AI] 已回收 %d 条中断任务", n)
	}

	go e.reconcileLoop(ctx)
	go e.workerLoop(ctx)
	for _, s := range e.sidecars() {
		go s.supervise(ctx)
	}
	go e.ollama.supervise(ctx)

	log.Printf("[AI] 处理层已启动（worker=%d 批大小=%d 侧车空闲退出=%s ollama 空闲回收=%s 配置=%s）",
		cfg.Workers, cfg.BatchSize, cfg.IdleTimeout, cfg.OllamaIdle, e.ConfigPath())
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
		if fileExists(p) {
			return p
		}
	}
	return ""
}

// resolveItems 按能力档位把媒体 ID 解析为可推理的文件项，并跳过无图源的媒体。
//
// 档位由能力决定：phash/embed 用 256 预览档（同一张图始终得到同样的哈希/向量），
// face/ocr/vlm 用长边 1024 的 AI 专用派生档（按需生成并缓存）。两者都不使用原图。
func (e *Engine) resolveItems(capability string, mediaIDs []string) ([]MediaItem, []string, error) {
	ids, err := parseUUIDs(mediaIDs)
	if err != nil {
		return nil, nil, err
	}
	assets, err := fetchAssets(ids)
	if err != nil {
		return nil, nil, err
	}

	tier := e.inputTier(capability)
	items := make([]MediaItem, 0, len(assets))
	var missing []string
	for _, asset := range assets {
		source, err := resolveSource(mediaPaths{
			Preview: PreviewAbsPath(asset.PreviewPath),
			Thumb:   ThumbAbsPath(asset.ThumbPath),
			Media:   MediaAbsPath(asset.FilePath),
		}, tier, asset.ID)
		if err != nil {
			missing = append(missing, asset.ID.String())
			continue
		}
		items = append(items, MediaItem{MediaID: asset.ID.String(), Path: source.Path, Tier: source.Tier})
	}
	return items, missing, nil
}

// ResolveChatImages 把媒体 ID 批量解析为 base64 图片，供对话请求内联发送。
//
// 与 face/ocr/vlm 同档：手机端因此无需把原图下载再上传。
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
