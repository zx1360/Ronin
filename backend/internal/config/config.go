package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

// AppConfig 应用配置数据类
type AppConfig struct {
	StaticDir  string
	GalleryDir string
}

// NetConfig 网络配置
//
// 启动后同时监听两个端口，接口完全一致，只是协议不同：
// HTTPS（自签证书，供 Android 等局域网消费端）与 HTTP（供本机浏览器打开运维页面，
// 免得自签证书弹警告）。危险接口由"仅回环可访问"约束，与端口无关。
type NetConfig struct {
	LocalPort     string // HTTPS
	LocalHTTPPort string // HTTP
}

// DbConfig SQLite 单文件数据库配置
type DbConfig struct {
	File       string // 数据库文件（相对路径按 backend/ 解析）
	SchemaFile string // 幂等建表脚本（references/db/sqlite.sql）
}

// ComixConfig comix 爬虫集成配置（子进程调用 python -m comix.cli）
type ComixConfig struct {
	Python      string // python 可执行文件（默认 "python"）
	Root        string // comix 项目根目录（含 comix 包与 util 包）
	StorageRoot string // 漫画图片存储根目录（COMIC_STORAGE_ROOT）
}

// GalleryConfig gallery CLI（gizmos 模块）集成配置
type GalleryConfig struct {
	Exe string // gallery CLI 可执行文件（相对路径按 backend/ 解析）
}

// OpsConfig 网页运维端（ops）配置
type OpsConfig struct {
	WebDir string // 网页端静态资源目录（源码在 ops/web/）
}

// AiConfig 本地 AI 媒体处理配置。
//
// AI 能力以外部进程（Python 侧车 / Ollama）方式接入：只在有任务时拉起，
// 空闲超时后自动退出，不常驻占用内存。
type AiConfig struct {
	Enabled         bool          // 总开关；false 时不启动 worker（API 仍可查看状态）
	Python          string        // 侧车解释器；留空则自动探测 tools/ai/.venv
	SidecarDir      string        // 侧车项目目录（含 ronin_ai 包）
	IdleTimeout     time.Duration // 侧车空闲多久后退出
	BatchSize       int           // 单批媒体数（一次进程调用摊薄模型加载成本）
	JobTimeout      time.Duration // 单批处理超时
	MaxAttempts     int           // 单条任务最大尝试次数
	Workers         int           // 并发批次上限
	EmbedModel      string        // SigLIP 模型标识
	OllamaURL       string
	OllamaVLMCTX    int           // VLM 请求的上下文长度（token）
	OllamaKeepAlive time.Duration // 对话请求显式下发的模型驻留时长（前端"后端默认值"即此项）
	OllamaIdle      time.Duration // 自拉的 ollama serve 空闲多久后回收（应大于模型 keep_alive）
	OllamaExe       string        // 留空则从 PATH 探测；用于按需拉起 ollama serve
	Device          string        // 侧车推理设备：auto=Windows 上启用 DirectML，cpu=全部回退 CPU
	AutoCaps        []string      // 入库后自动入队的能力（数据库 ai.settings 可覆盖）
}

// 向外暴露数据对象
var (
	AppConf     AppConfig
	NetConf     NetConfig
	DbConf      DbConfig
	ComixConf   ComixConfig
	GalleryConf GalleryConfig
	OpsConf     OpsConfig
	AiConf      AiConfig
)

// Load 从 .env 与环境变量加载配置，并校验必要项。
func Load() error {
	// 尝试从 .env 文件加载环境变量（文件不存在时不报错）
	_ = godotenv.Load()

	AppConf.StaticDir = os.Getenv("STATIC_DIR")
	AppConf.GalleryDir = os.Getenv("GALLERY_DIR")

	NetConf.LocalPort = os.Getenv("LOCAL_PORT")
	NetConf.LocalHTTPPort = os.Getenv("LOCAL_HTTP_PORT")

	// SQLite 单文件数据库：默认 backend/data/monarch.db
	DbConf.File = envString("DB_FILE", filepath.Join("data", "monarch.db"))
	DbConf.SchemaFile = envString("DB_SCHEMA_FILE", filepath.Join("references", "db", "sqlite.sql"))

	// comix 集成配置（可选；未配置时相关 API 返回明确错误）
	ComixConf.Python = os.Getenv("COMIX_PYTHON")
	if strings.TrimSpace(ComixConf.Python) == "" {
		ComixConf.Python = "python"
	}
	ComixConf.Root = os.Getenv("COMIX_ROOT")
	ComixConf.StorageRoot = envAbs("COMIC_STORAGE_ROOT")

	// gallery CLI：默认取 gizmos 模块的构建产物（backend/gizmos/gallery.exe）
	GalleryConf.Exe = envAbsOr("GALLERY_CLI", filepath.Join("gizmos", "gallery.exe"))

	// 网页运维端静态资源目录（源码在 ops/web/，由后端内置 HTTP 服务托管）
	OpsConf.WebDir = envAbsOr("OPS_WEB_DIR", filepath.Join("..", "ops", "web"))

	loadAiConfig()

	return Validate()
}

// envAbs 读取路径配置并解析为绝对路径（相对路径按当前工作目录 = backend/ 解析）。
func envAbs(key string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return ""
	}
	if abs, err := filepath.Abs(value); err == nil {
		return abs
	}
	return value
}

// envAbsOr 同 envAbs，但环境变量未设置时使用默认值。
func envAbsOr(key, def string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		value = def
	}
	if abs, err := filepath.Abs(value); err == nil {
		return abs
	}
	return value
}

// loadAiConfig 装载 AI 处理层配置（全部可选，缺省即可用）。
func loadAiConfig() {
	AiConf.Enabled = os.Getenv("AI_ENABLED") != "false"
	AiConf.Python = strings.TrimSpace(os.Getenv("AI_PYTHON"))
	AiConf.SidecarDir = strings.TrimSpace(os.Getenv("AI_SIDECAR_DIR"))
	if AiConf.SidecarDir == "" {
		AiConf.SidecarDir = filepath.Join("tools", "ai")
	}
	// 解析为绝对路径：子进程的启动目录由服务端进程决定，相对路径很容易踩空
	if abs, err := filepath.Abs(AiConf.SidecarDir); err == nil {
		AiConf.SidecarDir = abs
	}
	AiConf.IdleTimeout = envSeconds("AI_IDLE_TIMEOUT", 120)
	AiConf.JobTimeout = envSeconds("AI_JOB_TIMEOUT", 900)
	AiConf.BatchSize = envInt("AI_BATCH_SIZE", 16, 1, 512)
	AiConf.MaxAttempts = envInt("AI_MAX_ATTEMPTS", 3, 1, 20)
	AiConf.Workers = envInt("AI_WORKERS", 1, 1, 4)
	AiConf.EmbedModel = envString("AI_EMBED_MODEL", "siglip2-base-patch16-224")
	AiConf.OllamaURL = strings.TrimRight(envString("OLLAMA_URL", "http://127.0.0.1:11434"), "/")
	// 标注/对话用哪个模型不在这里配置：候选实时来自本机 Ollama，
	// 选定结果存在 ai_config.json 的 vlm_model 里（从未选过时自动挑一个并落盘）。
	// 每次请求显式下发上下文窗口，使行为不受 Ollama 应用默认值影响。
	// 缺省 65,536 对批量标注（实测每张约 220 token）已是数十倍余量。
	AiConf.OllamaVLMCTX = envInt("OLLAMA_VLM_CTX", 65536, 2048, 262144)
	// 对话请求的模型驻留时长（keep_alive）。Ollama 自身默认也是 5 分钟，这里显式
	// 下发是为了让"后端默认值"可被客户端读取并展示，而不是靠隐式约定。
	AiConf.OllamaKeepAlive = envSeconds("OLLAMA_KEEP_ALIVE", 300)
	// 默认 6 分钟：略大于 Ollama 自身的 5 分钟模型 keep_alive，
	// 避免"模型还没卸载我们就先把服务杀了"导致反复重载。
	AiConf.OllamaIdle = envSeconds("OLLAMA_IDLE_TIMEOUT", 360)
	AiConf.OllamaExe = strings.TrimSpace(os.Getenv("OLLAMA_EXE"))
	AiConf.Device = parseDevice(envString("AI_DEVICE", "auto"))
	AiConf.AutoCaps = parseAutoCaps(envString("AI_AUTO_CAPS", "phash,embed,face,ocr"))
}

// parseDevice 解析侧车推理设备；只认 cpu，其余一律按 auto 处理。
func parseDevice(raw string) string {
	if strings.EqualFold(strings.TrimSpace(raw), "cpu") {
		return "cpu"
	}
	return "auto"
}

// parseAutoCaps 解析入库自动处理能力列表；`none`/`off` 表示完全关闭自动入队
// （此时只能从桌面端手动提交处理任务）。
func parseAutoCaps(raw string) []string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "none", "off":
		return nil
	default:
		return splitCSV(raw)
	}
}

func envString(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func envInt(key string, def, min, max int) int {
	v, err := strconv.Atoi(strings.TrimSpace(os.Getenv(key)))
	if err != nil || v < min || v > max {
		return def
	}
	return v
}

func envSeconds(key string, def int) time.Duration {
	return time.Duration(envInt(key, def, 1, 86400)) * time.Second
}

func splitCSV(raw string) []string {
	var out []string
	for _, part := range strings.Split(raw, ",") {
		if part = strings.TrimSpace(part); part != "" {
			out = append(out, part)
		}
	}
	return out
}

// Validate 校验必要配置项，返回缺失项列表
func Validate() error {
	required := map[string]string{
		"STATIC_DIR":      AppConf.StaticDir,
		"GALLERY_DIR":     AppConf.GalleryDir,
		"LOCAL_PORT":      NetConf.LocalPort,
		"LOCAL_HTTP_PORT": NetConf.LocalHTTPPort,
		"DB_FILE":         DbConf.File,
	}

	var missing []string
	for key, val := range required {
		if strings.TrimSpace(val) == "" {
			missing = append(missing, key)
		}
	}

	if len(missing) > 0 {
		return fmt.Errorf("缺少必要的环境变量: %s", strings.Join(missing, ", "))
	}

	return nil
}
