// Package ops 提供 ops 网页应用所需的本机能力。
//
// 网页应用无法自行启动进程、定位路径或写本机文件，这些能力统一由后端提供，
// 页面只经本地回环 http 调用（见 router 的 RequireLoopback 中间件）。
package ops

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"monarch/internal/config"
	"monarch/internal/service/db"
	"monarch/internal/service/proctask"
)

// ---------------------------------------------------------------------------
// gallery CLI 任务生命周期
//
// 复用通用任务引擎（internal/service/proctask）：内存任务表 + 子进程输出流式入
// 日志 + 进程树中断。与 comix 的差别只有"gallery CLI 没有 JSON 协议，stdout 与
// stderr 都是人读的日志"，因此不做结果解析。
// 任务集是固定的（ingest/execute/refresh），页面只能给参数，不能自定义可执行文件。
// ---------------------------------------------------------------------------

// TaskStatus 任务状态。
type TaskStatus = proctask.Status

// LogEntry 单条任务日志。
type LogEntry = proctask.LogEntry

// GalleryTask 一次 gallery CLI 执行。
type GalleryTask = proctask.Task

const (
	TaskRunning  = proctask.Running
	TaskFinished = proctask.Finished
	TaskFailed   = proctask.Failed
	TaskKilled   = proctask.Killed
)

// GalleryOptions 是 gallery CLI 的可调参数；零值表示用 CLI 自身默认值。
type GalleryOptions struct {
	Mode        string `json:"mode"`        // ingest / execute / refresh
	Concurrency int    `json:"concurrency"` // -concurrency
	Batch       int    `json:"batch"`       // -batch
	Resize      int    `json:"resize"`      // -resize（refresh 专用）
	ResizePrew  int    `json:"resize_preview"`
	ResizeThumb int    `json:"resize_thumb"`
}

// galleryModes 是允许的运行模式白名单。
var galleryModes = map[string]bool{"ingest": true, "execute": true, "refresh": true}

// GalleryManager 维护 gallery CLI 任务的内存注册表。
type GalleryManager struct{ *proctask.Manager }

// Gallery 全局 gallery 任务管理器。
var Gallery = &GalleryManager{proctask.NewManager("g", 2000, 20)}

// GalleryAvailable 报告 gallery CLI 是否可用；不可用时返回原因。
func GalleryAvailable() (bool, string) {
	cli := config.ResolveGalleryCLI()
	if cli == "" {
		return false, "未找到 gallery CLI（请构建 backend/gizmos/cmd/gallery 或配置 app.gallery_cli）"
	}
	if fi, err := os.Stat(cli); err != nil || fi.IsDir() {
		return false, fmt.Sprintf("gallery CLI 不可用: %s", cli)
	}
	if strings.TrimSpace(config.AppConf.GalleryDir) == "" {
		return false, "媒体库根目录未配置（设置 app.gallery_dir）"
	}
	return true, ""
}

// buildGalleryArgs 构建 gallery CLI 参数（不含可执行文件本身）。
func buildGalleryArgs(opt GalleryOptions) ([]string, error) {
	if !galleryModes[opt.Mode] {
		return nil, fmt.Errorf("不支持的运行模式: %s (可选: ingest, execute, refresh)", opt.Mode)
	}
	args := []string{
		"-mode", opt.Mode,
		"-gallery-root", config.AppConf.GalleryDir,
	}
	if opt.Concurrency > 0 {
		args = append(args, "-concurrency", fmt.Sprint(opt.Concurrency))
	}
	if opt.Batch > 0 {
		args = append(args, "-batch", fmt.Sprint(opt.Batch))
	}
	if opt.Mode == "refresh" {
		if opt.Resize > 0 {
			args = append(args, "-resize", fmt.Sprint(opt.Resize))
		}
		if opt.ResizePrew > 0 {
			args = append(args, "-resizePreview", fmt.Sprint(opt.ResizePrew))
		}
		if opt.ResizeThumb > 0 {
			args = append(args, "-resizeThumb", fmt.Sprint(opt.ResizeThumb))
		}
	}
	return args, nil
}

// StartGallery 启动一次 gallery 任务并立即返回。
func (m *GalleryManager) StartGallery(opt GalleryOptions) (*GalleryTask, error) {
	if ok, msg := GalleryAvailable(); !ok {
		return nil, fmt.Errorf("%s", msg)
	}
	args, err := buildGalleryArgs(opt)
	if err != nil {
		return nil, err
	}

	cli := config.ResolveGalleryCLI()
	return m.Manager.Start(proctask.Spec{
		Path: cli,
		Args: args,
		// CLI 的工作目录固定在可执行文件所在目录；数据库路径由 db.ChildEnv 传绝对
		// 路径，否则相对 DB_PATH 会被它按自己的工作目录解析而找不到库。
		Dir:     filepath.Dir(cli),
		Env:     db.ChildEnv(),
		Name:    opt.Mode,
		Command: filepath.Base(cli) + " " + strings.Join(args, " "),
	})
}

// StopGallery 中断任务。
func (m *GalleryManager) StopGallery(taskID string) error { return m.Manager.Stop(taskID) }

// GetGallery 获取任务详情。
func (m *GalleryManager) GetGallery(taskID string) (*GalleryTask, error) {
	return m.Manager.Get(taskID)
}

// ListGallery 返回任务列表（新建在前）。
func (m *GalleryManager) ListGallery() []*GalleryTask { return m.Manager.List() }

// KillAllGallery 中断全部运行中任务（服务退出前调用）。
func (m *GalleryManager) KillAllGallery() { m.Manager.KillAll() }

// ---------------------------------------------------------------------------
// ops 界面偏好
//
// 只存"页面自己长什么样"的轻量偏好，与 app_settings（服务端行为配置）分开：
// 前者是 UI 状态，后者会影响服务端行为，混在一起会让配置表失去意义。
// ---------------------------------------------------------------------------

// Preferences 是 ops 页面的界面偏好。
type Preferences struct {
	AutoRefreshSeconds int      `json:"auto_refresh_seconds"`
	CollapsedSections  []string `json:"collapsed_sections,omitempty"`
	LastTab            string   `json:"last_tab,omitempty"`
	LogAutoscroll      bool     `json:"log_autoscroll"`
}

// DefaultPreferences 返回默认偏好。
func DefaultPreferences() Preferences {
	return Preferences{AutoRefreshSeconds: 5, LogAutoscroll: true}
}

var (
	prefsMu  sync.Mutex
	prefsDir string
)

// InitPreferences 指定偏好文件所在目录（与数据库同级的应用目录）。
func InitPreferences(dir string) {
	prefsMu.Lock()
	prefsDir = dir
	prefsMu.Unlock()
}

// prefsFilePathLocked 返回偏好文件路径；调用方必须持有 prefsMu。
func prefsFilePathLocked() (string, error) {
	dir := prefsDir
	if dir == "" {
		dir = filepath.Dir(config.DBPath)
	}
	if dir == "" || dir == "." {
		return "", fmt.Errorf("偏好文件目录未确定")
	}
	return filepath.Join(dir, "ops_preferences.json"), nil
}

// UpdatePreferences 在锁内完成"读取 → 应用 → 写回"，避免两个并发 PUT 互相覆盖。
//
// apply 返回错误时保持文件不变（校验失败不该落盘）。
func UpdatePreferences(apply func(*Preferences) error) (Preferences, error) {
	prefsMu.Lock()
	defer prefsMu.Unlock()

	current := loadPreferencesLocked()
	if err := apply(&current); err != nil {
		return Preferences{}, err
	}
	if err := savePreferencesLocked(current); err != nil {
		return Preferences{}, err
	}
	return current, nil
}

// LoadPreferences 读取偏好；文件不存在或损坏时回退默认值。
func LoadPreferences() Preferences {
	prefsMu.Lock()
	defer prefsMu.Unlock()
	return loadPreferencesLocked()
}

func loadPreferencesLocked() Preferences {
	prefs := DefaultPreferences()
	path, err := prefsFilePathLocked()
	if err != nil {
		return prefs
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return prefs
	}
	if err := json.Unmarshal(data, &prefs); err != nil {
		return DefaultPreferences()
	}
	if prefs.AutoRefreshSeconds <= 0 {
		prefs.AutoRefreshSeconds = DefaultPreferences().AutoRefreshSeconds
	}
	return prefs
}

func savePreferencesLocked(prefs Preferences) error {
	path, err := prefsFilePathLocked()
	if err != nil {
		return err
	}
	if prefs.AutoRefreshSeconds <= 0 {
		prefs.AutoRefreshSeconds = DefaultPreferences().AutoRefreshSeconds
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(prefs, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, append(data, '\n'), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// ---------------------------------------------------------------------------
// 路径定位
// ---------------------------------------------------------------------------

// DirEntry 目录列表项（供页面做路径选择）。
type DirEntry struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

// ListDirs 列出 path 下的子目录；path 为空时列出可用盘符。
//
// 只读、只列目录：页面需要"选一个目录"的能力，但不应获得任意文件读写能力。
func ListDirs(path string) (string, []DirEntry, error) {
	if strings.TrimSpace(path) == "" {
		return "", listDrives(), nil
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return "", nil, fmt.Errorf("路径无效: %w", err)
	}
	entries, err := os.ReadDir(abs)
	if err != nil {
		return abs, nil, fmt.Errorf("读取目录失败: %w", err)
	}
	out := make([]DirEntry, 0, len(entries))
	for _, e := range entries {
		if !e.IsDir() || strings.HasPrefix(e.Name(), ".") {
			continue
		}
		out = append(out, DirEntry{Name: e.Name(), Path: filepath.Join(abs, e.Name())})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	parent := filepath.Dir(abs)
	if parent == abs {
		parent = ""
	}
	return parent, out, nil
}

// listDrives 在 Windows 上列出可用盘符；其它平台返回根目录。
func listDrives() []DirEntry {
	var out []DirEntry
	for c := 'A'; c <= 'Z'; c++ {
		root := string(c) + ":\\"
		if fi, err := os.Stat(root); err == nil && fi.IsDir() {
			out = append(out, DirEntry{Name: root, Path: root})
		}
	}
	if len(out) == 0 {
		out = append(out, DirEntry{Name: "/", Path: "/"})
	}
	return out
}

// RevealPath 在系统文件管理器中定位路径（Windows 用 explorer /select）。
//
// 只允许定位到媒体库或静态资源目录之内，避免把本机文件系统暴露成任意"打开"接口。
func RevealPath(target string) error {
	abs, err := filepath.Abs(target)
	if err != nil {
		return fmt.Errorf("路径无效: %w", err)
	}
	if !withinAllowedRoots(abs) {
		return fmt.Errorf("只允许定位媒体库或静态资源目录内的路径")
	}
	if _, err := os.Stat(abs); err != nil {
		return fmt.Errorf("路径不存在: %w", err)
	}
	return reveal(abs)
}

// withinAllowedRoots 报告路径是否位于允许的根目录内。
func withinAllowedRoots(abs string) bool {
	for _, root := range []string{config.AppConf.GalleryDir, config.AppConf.StaticDir} {
		if strings.TrimSpace(root) == "" {
			continue
		}
		rootAbs, err := filepath.Abs(root)
		if err != nil {
			continue
		}
		rel, err := filepath.Rel(rootAbs, abs)
		if err != nil {
			continue
		}
		if rel == "." || (!strings.HasPrefix(rel, ".."+string(filepath.Separator)) && rel != "..") {
			return true
		}
	}
	return false
}

// Dependency 一项外部依赖的可用性。
type Dependency struct {
	Name      string `json:"name"`
	Available bool   `json:"available"`
	Path      string `json:"path,omitempty"`
	Required  string `json:"required_for,omitempty"`
}

// CheckDependencies 检查 gallery 与视频处理所需的外部命令。
func CheckDependencies() []Dependency {
	specs := []struct {
		name string
		use  string
	}{
		{"ffmpeg", "gallery ingest/execute 生成视频缩略图"},
		{"ffprobe", "媒体时长探测与画廊剪辑"},
		{"python", "comix 漫画爬虫"},
	}
	out := make([]Dependency, 0, len(specs))
	for _, s := range specs {
		path, err := exec.LookPath(s.name)
		out = append(out, Dependency{
			Name:      s.name,
			Available: err == nil,
			Path:      path,
			Required:  s.use,
		})
	}
	cli := config.ResolveGalleryCLI()
	out = append(out, Dependency{
		Name:      "gallery",
		Available: cli != "",
		Path:      cli,
		Required:  "媒体库摄入/执行/刷新",
	})
	return out
}
