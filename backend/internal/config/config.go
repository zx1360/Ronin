// Package config 负责两件事：
//
//  1. Bootstrap：从 .env / 环境变量读取"连库之前就必须知道"的项（数据库路径、端口、API Key）。
//  2. 把 settings 包里的运行时配置解释成类型化的全局对象（AppConf / AiConf / ComixConf）。
//
// 除 Bootstrap 之外的配置一律入库，见 internal/settings 与 /API/settings。
package config

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"

	"monarch/internal/settings"
)

// AppConfig 应用路径配置。
type AppConfig struct {
	StaticDir  string
	GalleryDir string
	// OpsDir 是 ops 网页应用目录；为空时由 resolve 逻辑定位仓库中的 ops/。
	OpsDir string
	// GalleryCLI 是 gallery CLI 可执行文件；为空时由 resolve 逻辑定位 gizmos/gallery(.exe)。
	GalleryCLI string
}

// NetConfig 网络配置（Bootstrap 项）。
type NetConfig struct {
	LocalPort      string
	LocalDebugPort string
	APIKeyServer   string
}

// ComixConfig comix 爬虫集成配置（内置在 gizmos/comix，以子进程调用）。
type ComixConfig struct {
	Python      string // python 可执行文件
	StorageRoot string // 漫画图片落盘根目录
	MaxWorkers  int    // 下载并发
}

// AiConfig 本地 AI 媒体处理配置。
type AiConfig struct {
	Enabled         bool
	Python          string
	SidecarDir      string
	IdleTimeout     time.Duration
	BatchSize       int
	JobTimeout      time.Duration
	MaxAttempts     int
	EmbedModel      string
	AutoCaps        []string
	Device          string
	OllamaURL       string
	OllamaVLM       string
	OllamaVLMAlt    string
	OllamaVLMCTX    int
	OllamaKeepAlive time.Duration
	OllamaIdle      time.Duration
	OllamaExe       string
	OllamaModels    string
}

// IsLocalMode 运行模式：true=本地开发(HTTP+免鉴权+ops 页面)。
var IsLocalMode bool

// DBPath 是 SQLite 单文件路径（Bootstrap 项）。
var DBPath string

// 向外暴露数据对象。
var (
	AppConf   AppConfig
	NetConf   NetConfig
	ComixConf ComixConfig
	AiConf    AiConfig
)

// defaultDBPath 相对工作目录解析；应用目录即 backend/。
const defaultDBPath = "data/monarch.db"

// Load 读取 Bootstrap 配置（.env 文件不存在时只依赖真实环境变量）。
func Load() error {
	_ = godotenv.Load()

	DBPath = envString("DB_PATH", defaultDBPath)
	NetConf.LocalPort = os.Getenv("LOCAL_PORT")
	NetConf.LocalDebugPort = os.Getenv("LOCAL_DEBUG_PORT")
	NetConf.APIKeyServer = os.Getenv("API_KEY_SERVER")

	return ValidateBootstrap()
}

// ValidateBootstrap 校验 Bootstrap 必要项。
func ValidateBootstrap() error {
	required := map[string]string{
		"LOCAL_PORT":     NetConf.LocalPort,
		"API_KEY_SERVER": NetConf.APIKeyServer,
	}
	if IsLocalMode {
		required["LOCAL_DEBUG_PORT"] = NetConf.LocalDebugPort
	} else if strings.TrimSpace(NetConf.LocalDebugPort) == "" {
		// ops 页面走回环调试端口，生产模式同样需要它。
		required["LOCAL_DEBUG_PORT"] = NetConf.LocalDebugPort
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

// ApplySettings 用运行时配置刷新类型化全局对象；服务启动时与每次写入配置后调用。
func ApplySettings(vals map[string]string) {
	get := func(key string) string { return vals[key] }

	AppConf.StaticDir = strings.TrimSpace(get("app.static_dir"))
	if AppConf.StaticDir == "" {
		AppConf.StaticDir = "./static"
	}
	AppConf.GalleryDir = strings.TrimSpace(get("app.gallery_dir"))
	AppConf.OpsDir = strings.TrimSpace(get("app.ops_dir"))
	AppConf.GalleryCLI = strings.TrimSpace(get("app.gallery_cli"))

	applyComixSettings(get)
	applyAiSettings(get)
}

// ResolveOpsDir 定位 ops 网页应用目录：配置优先，其次按常见相对位置查找。
func ResolveOpsDir() string {
	if AppConf.OpsDir != "" {
		if abs, err := filepath.Abs(AppConf.OpsDir); err == nil {
			return abs
		}
		return AppConf.OpsDir
	}
	// findUpwards 以"文件存在"为命中判据，这里定位的是入口文件，返回其所在目录。
	if entry := findUpwards(filepath.Join("ops", "index.html")); entry != "" {
		return filepath.Dir(entry)
	}
	return ""
}

// ResolveGalleryCLI 定位 gallery CLI：配置优先，其次按常见相对位置查找。
func ResolveGalleryCLI() string {
	if AppConf.GalleryCLI != "" {
		if abs, err := filepath.Abs(AppConf.GalleryCLI); err == nil {
			return abs
		}
		return AppConf.GalleryCLI
	}
	name := "gallery"
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	return findUpwards(filepath.Join("gizmos", name))
}

// ResolveComixRoot 定位内置的 comix 项目根目录（backend/gizmos/comix）。
func ResolveComixRoot() string {
	entry := findUpwards(filepath.Join("gizmos", "comix", "comix", "cli.py"))
	if entry == "" {
		return ""
	}
	return filepath.Dir(filepath.Dir(entry))
}

// findUpwards 从工作目录与可执行文件目录向上查找相对路径 rel，返回首个存在的绝对路径。
//
// 存在的意义：服务既可能用 `go run ./cmd` 在 backend/ 下启动，也可能以编译好的
// exe 放在 backend/ 下运行，两种情形下仓库根的相对深度不同。
func findUpwards(rel string) string {
	starts := []string{}
	if wd, err := os.Getwd(); err == nil {
		starts = append(starts, wd)
	}
	if exe, err := os.Executable(); err == nil {
		starts = append(starts, filepath.Dir(exe))
	}
	for _, start := range starts {
		dir := start
		for depth := 0; depth < 3; depth++ {
			candidate := filepath.Join(dir, rel)
			if fi, err := os.Stat(candidate); err == nil && !fi.IsDir() {
				return candidate
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
		}
	}
	return ""
}

func applyComixSettings(get func(string) string) {
	ComixConf.Python = strings.TrimSpace(get("comix.python"))
	if ComixConf.Python == "" {
		ComixConf.Python = "python"
	}
	ComixConf.StorageRoot = strings.TrimSpace(get("comix.storage_root"))
	if ComixConf.StorageRoot == "" {
		ComixConf.StorageRoot = filepath.Join(AppConf.StaticDir, "comics")
	}
	// 必须是绝对路径：该值会下发给 comix 子进程（相对路径会按 comix 自己的工作目录解析），
	// 也要与 Go 侧的删除/定位保持同一目录。
	if abs, err := filepath.Abs(ComixConf.StorageRoot); err == nil {
		ComixConf.StorageRoot = abs
	}
	ComixConf.MaxWorkers = atoiDefault(get("comix.max_workers"), 2)
}

func applyAiSettings(get func(string) string) {
	AiConf.Enabled = strings.EqualFold(get("ai.enabled"), "true") || get("ai.enabled") == "1"
	AiConf.Python = strings.TrimSpace(get("ai.python"))
	AiConf.SidecarDir = strings.TrimSpace(get("ai.sidecar_dir"))
	if AiConf.SidecarDir == "" {
		AiConf.SidecarDir = filepath.Join("tools", "ai")
	}
	// 解析为绝对路径：子进程的启动目录由服务端进程决定，相对路径很容易踩空。
	if abs, err := filepath.Abs(AiConf.SidecarDir); err == nil {
		AiConf.SidecarDir = abs
	}
	AiConf.IdleTimeout = seconds(get("ai.idle_timeout"), 120)
	AiConf.JobTimeout = seconds(get("ai.job_timeout"), 900)
	AiConf.BatchSize = atoiDefault(get("ai.batch_size"), 16)
	AiConf.MaxAttempts = atoiDefault(get("ai.max_attempts"), 3)
	AiConf.EmbedModel = strings.TrimSpace(get("ai.embed_model"))
	AiConf.Device = parseDevice(get("ai.device"))
	AiConf.AutoCaps = splitCSV(get("ai.auto_capabilities"))

	AiConf.OllamaURL = strings.TrimRight(strings.TrimSpace(get("ai.ollama.url")), "/")
	AiConf.OllamaVLM = strings.TrimSpace(get("ai.vlm_model"))
	AiConf.OllamaVLMAlt = strings.TrimSpace(get("ai.ollama.vlm_model_alt"))
	AiConf.OllamaVLMCTX = atoiDefault(get("ai.ollama.vlm_ctx"), 65536)
	AiConf.OllamaKeepAlive = seconds(get("ai.ollama.keep_alive"), 300)
	AiConf.OllamaIdle = seconds(get("ai.ollama.idle_timeout"), 360)
	AiConf.OllamaExe = strings.TrimSpace(get("ai.ollama.exe"))
	AiConf.OllamaModels = strings.TrimSpace(get("ai.ollama.models"))
}

// LoadSettings 读取数据库配置并应用到全局对象。
func LoadSettings() error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := settings.Load(ctx); err != nil {
		return err
	}
	ApplySettings(settings.All())
	return nil
}

// parseDevice 解析侧车推理设备；只认 cpu，其余一律按 auto 处理。
func parseDevice(raw string) string {
	if strings.EqualFold(strings.TrimSpace(raw), "cpu") {
		return "cpu"
	}
	return "auto"
}

func envString(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func atoiDefault(raw string, def int) int {
	n, err := strconv.Atoi(strings.TrimSpace(raw))
	if err != nil || n <= 0 {
		return def
	}
	return n
}

func seconds(raw string, def int) time.Duration {
	return time.Duration(atoiDefault(raw, def)) * time.Second
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
