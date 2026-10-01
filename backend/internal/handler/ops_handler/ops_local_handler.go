// Package ops_handler 提供网页运维端（ops）所需的本机能力接口。
//
// 网页端没有本机权限，凡是它做不到的事都由这里代劳：路径定位（资源管理器定位）、
// gallery CLI 进程生命周期、界面偏好读写。这些接口只在服务端所在机器上才有意义，
// 因此统一挂在 /API/ops/local 下，并由 router 的 LocalOnly 中间件限制为本机回环访问。
package ops_handler

import (
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/service/comix"
	"monarch/internal/service/gallery"
	"monarch/internal/service/taskengine"
)

// store 网页端偏好存储，由服务启动时注入。
var store *config.OpsStore

// SetStore 注入网页端偏好存储（服务启动时调用一次）。
func SetStore(s *config.OpsStore) { store = s }

// Bootstrap 返回网页端启动所需的全部本机信息：API 密钥、界面偏好、
// 服务端路径与本机能力可用性。页面本身不假设拥有任何本机权限。
//
// API 密钥由服务端下发而不是让用户手填：网页端与 Monarch 同源同机，
// 且本接口仅回环可访问，密钥不会离开本机。留空表示服务端未启用鉴权。
func Bootstrap(c *gin.Context) {
	port := config.NetConf.LocalPort
	if config.IsLocalMode {
		port = config.NetConf.LocalDebugPort
	}

	galleryOK, galleryMsg := gallery.Available()
	comixOK, comixMsg := comix.Available()

	c.JSON(http.StatusOK, gin.H{
		"apiKey":       os.Getenv("API_KEY_SERVER"),
		"settings":     store.Snapshot(),
		"settingsPath": absPath(store.Path()),
		"service": gin.H{
			"isLocalMode": config.IsLocalMode,
			"port":        port,
		},
		"paths": gin.H{
			"staticDir":    absPath(config.AppConf.StaticDir),
			"galleryDir":   absPath(config.AppConf.GalleryDir),
			"galleryMedia": absPath(filepath.Join(config.AppConf.GalleryDir, "Media")),
			"opsWebDir":    absPath(config.OpsConf.WebDir),
			"dbFile":       absPath(config.DbConf.File),
		},
		"cli": gin.H{
			"gallery": gin.H{
				"path": gallery.ExecutablePath(), "available": galleryOK, "message": galleryMsg,
				"defaults": gallery.DefaultOptions(),
			},
			"comix": gin.H{
				"available": comixOK, "message": comixMsg, "root": config.ComixConf.Root,
			},
		},
		"deps": gin.H{
			"ffmpeg":  commandAvailable("ffmpeg"),
			"ffprobe": commandAvailable("ffprobe"),
		},
	})
}

// UpdateSettings 局部更新网页端界面偏好（未提供的项保持不变）。
func UpdateSettings(c *gin.Context) {
	var update config.OpsSettings
	if err := c.ShouldBindJSON(&update); err != nil {
		badRequest(c, "请求体无效: "+err.Error())
		return
	}
	if err := store.Update(update); err != nil {
		badRequest(c, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": gin.H{"settings": store.Snapshot()}})
}

// ListTasks 列出 gallery CLI 任务（不含日志，日志走详情接口）。
func ListTasks(c *gin.Context) {
	tasks := gallery.Manager.List()
	type summary struct {
		ID         string            `json:"id"`
		Name       string            `json:"name"`
		Command    string            `json:"command"`
		Status     taskengine.Status `json:"status"`
		PID        int               `json:"pid"`
		StartedAt  time.Time         `json:"started_at"`
		FinishedAt *time.Time        `json:"finished_at"`
		ExitCode   *int              `json:"exit_code"`
		Error      string            `json:"error"`
	}
	out := make([]summary, 0, len(tasks))
	for _, t := range tasks {
		out = append(out, summary{
			ID: t.ID, Name: t.Name, Command: t.Command, Status: t.Status,
			PID: t.PID, StartedAt: t.StartedAt, FinishedAt: t.FinishedAt,
			ExitCode: t.ExitCode, Error: t.Error,
		})
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": gin.H{"tasks": out}})
}

// StartTask 启动一次 gallery CLI 任务（同一时刻只允许一个）。
func StartTask(c *gin.Context) {
	opt := gallery.DefaultOptions()
	if err := c.ShouldBindJSON(&opt); err != nil {
		badRequest(c, "请求体无效: "+err.Error())
		return
	}

	task, err := gallery.Start(opt)
	if err != nil {
		badRequest(c, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"ok": true,
		"data": gin.H{
			"task_id": task.ID, "name": task.Name, "status": task.Status,
			"command": task.Command, "started_at": task.StartedAt,
		},
	})
}

// GetTask 返回任务详情（状态/日志/结果）。
func GetTask(c *gin.Context) {
	task, err := gallery.Manager.Get(c.Param("task-id"))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"ok": false, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": task})
}

// StopTask 中断运行中的 gallery 任务。
func StopTask(c *gin.Context) {
	taskID := c.Param("task-id")
	if err := gallery.Manager.Stop(taskID); err != nil {
		badRequest(c, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"ok": true,
		"data": gin.H{"task_id": taskID, "status": taskengine.StatusKilled},
	})
}

// Reveal 在资源管理器中定位文件或目录（网页端无法调用本机程序）。
//
// 接受绝对路径（path）或 gallery 库内相对路径（rel_path，与 gallery 根目录拼接）。
func Reveal(c *gin.Context) {
	var req struct {
		Path    string `json:"path"`
		RelPath string `json:"rel_path"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "请求体无效: "+err.Error())
		return
	}

	target, err := resolveRevealPath(req.Path, req.RelPath)
	if err != nil {
		badRequest(c, err.Error())
		return
	}
	if _, statErr := os.Stat(target); statErr != nil {
		badRequest(c, "路径不可用: "+target)
		return
	}

	// explorer 的 /select 参数必须与路径同处一个参数；explorer 自身会立即返回，
	// 因此不等待（它的退出码总是非 0），失败只可能发生在启动阶段。
	if err := exec.Command("explorer.exe", "/select,"+target).Start(); err != nil {
		badRequest(c, "打开资源管理器失败: "+err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": gin.H{"path": target}})
}

// resolveRevealPath 归一化定位目标；相对路径只在 gallery 根目录内解析。
func resolveRevealPath(path, relPath string) (string, error) {
	if trimmed := strings.TrimSpace(path); trimmed != "" {
		if !filepath.IsAbs(trimmed) {
			return "", fmt.Errorf("path 必须是绝对路径: %s", trimmed)
		}
		return filepath.Clean(trimmed), nil
	}

	relative := strings.TrimSpace(relPath)
	if relative == "" {
		return "", errors.New("需要提供 path 或 rel_path")
	}
	root := absPath(config.AppConf.GalleryDir)
	target := filepath.Clean(filepath.Join(root, filepath.FromSlash(relative)))
	if !strings.HasPrefix(target, root+string(filepath.Separator)) {
		return "", fmt.Errorf("rel_path 越出 gallery 根目录: %s", relative)
	}
	return target, nil
}

// --- 内部辅助 ---

func badRequest(c *gin.Context, msg string) {
	c.JSON(http.StatusBadRequest, gin.H{"ok": false, "error": msg})
}

// absPath 返回绝对路径（失败时原样返回，便于界面如实展示配置值）。
func absPath(path string) string {
	if strings.TrimSpace(path) == "" {
		return ""
	}
	if abs, err := filepath.Abs(path); err == nil {
		return abs
	}
	return path
}

// commandAvailable 报告外部命令是否可从 PATH 解析。
func commandAvailable(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}
