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
type NetConfig struct {
	LocalPort      string
	LocalDebugPort string
}

// DbConfig 数据库配置
type DbConfig struct {
	DbIP       string
	DbPort     string
	DbUser     string
	DbPassword string
	DbName     string
}

// ComixConfig comix 爬虫集成配置（子进程调用 python -m comix.cli）
type ComixConfig struct {
	Python string // python 可执行文件（默认 "python"）
	Root   string // comix 项目根目录（依赖 .env 与 util 包，必须设置）
}

// AiConfig 本地 AI 媒体处理配置。
//
// AI 能力以外部进程（Python 侧车 / Ollama）方式接入：只在有任务时拉起，
// 空闲超时后自动退出，不常驻占用内存。
type AiConfig struct {
	Enabled     bool          // 总开关；false 时不启动 worker（API 仍可查看状态）
	Python      string        // 侧车解释器；留空则自动探测 tools/ai/.venv
	SidecarDir  string        // 侧车项目目录（含 ronin_ai 包）
	IdleTimeout time.Duration // 侧车空闲多久后退出
	BatchSize   int           // 单批媒体数（一次进程调用摊薄模型加载成本）
	JobTimeout  time.Duration // 单批处理超时
	MaxAttempts int           // 单条任务最大尝试次数
	Workers     int           // 并发批次上限
	EmbedModel  string        // SigLIP 模型标识
	OllamaURL   string
	OllamaVLM   string        // VLM 模型名
	OllamaIdle  time.Duration // 自拉的 ollama serve 空闲多久后回收（应大于模型 keep_alive）
	OllamaExe   string        // 留空则从 PATH 探测；用于按需拉起 ollama serve
	AutoCaps    []string      // 入库后自动入队的能力（数据库 ai.settings 可覆盖）
}

// IsLocalMode 运行模式：true=本地开发(HTTP+免鉴权)
var IsLocalMode bool

// 向外暴露数据对象
var (
	AppConf   AppConfig
	NetConf   NetConfig
	DbConf    DbConfig
	ComixConf ComixConfig
	AiConf    AiConfig
)

// Load 从 .env 与环境变量加载配置，并校验必要项。
func Load() error {
	// 尝试从 .env 文件加载环境变量（文件不存在时不报错）
	_ = godotenv.Load()

	AppConf.StaticDir = os.Getenv("STATIC_DIR")
	AppConf.GalleryDir = os.Getenv("GALLERY_DIR")

	NetConf.LocalPort = os.Getenv("LOCAL_PORT")
	NetConf.LocalDebugPort = os.Getenv("LOCAL_DEBUG_PORT")

	DbConf.DbIP = os.Getenv("DB_IP")
	DbConf.DbPort = os.Getenv("DB_PORT")
	DbConf.DbUser = os.Getenv("DB_USER")
	DbConf.DbPassword = os.Getenv("DB_PASSWORD")
	DbConf.DbName = os.Getenv("DB_NAME")

	// comix 爬虫集成配置（可选；未配置时相关 API 返回明确错误）
	ComixConf.Python = os.Getenv("COMIX_PYTHON")
	if strings.TrimSpace(ComixConf.Python) == "" {
		ComixConf.Python = "python"
	}
	ComixConf.Root = os.Getenv("COMIX_ROOT")

	loadAiConfig()

	return Validate()
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
	AiConf.OllamaVLM = envString("OLLAMA_VLM_MODEL", "qwen2.5vl:7b")
	// 默认 6 分钟：略大于 Ollama 自身的 5 分钟模型 keep_alive，
	// 避免"模型还没卸载我们就先把服务杀了"导致反复重载。
	AiConf.OllamaIdle = envSeconds("OLLAMA_IDLE_TIMEOUT", 360)
	AiConf.OllamaExe = strings.TrimSpace(os.Getenv("OLLAMA_EXE"))
	AiConf.AutoCaps = parseAutoCaps(envString("AI_AUTO_CAPS", "phash,embed,face,ocr"))
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
		"STATIC_DIR":  AppConf.StaticDir,
		"GALLERY_DIR": AppConf.GalleryDir,
		"LOCAL_PORT":  NetConf.LocalPort,
		"DB_IP":       DbConf.DbIP,
		"DB_PORT":     DbConf.DbPort,
		"DB_USER":     DbConf.DbUser,
		"DB_PASSWORD": DbConf.DbPassword,
		"DB_NAME":     DbConf.DbName,
	}

	var missing []string
	for key, val := range required {
		if strings.TrimSpace(val) == "" {
			missing = append(missing, key)
		}
	}

	// LOCAL_DEBUG_PORT 仅在 local 模式需要
	if IsLocalMode && strings.TrimSpace(NetConf.LocalDebugPort) == "" {
		missing = append(missing, "LOCAL_DEBUG_PORT")
	}

	if len(missing) > 0 {
		return fmt.Errorf("缺少必要的环境变量: %s", strings.Join(missing, ", "))
	}

	return nil
}
