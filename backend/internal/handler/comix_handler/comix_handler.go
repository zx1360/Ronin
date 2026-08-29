// Package comix_handler 提供 comix 漫画爬虫管理接口。
//
// 接口分两类：
//   - 同步：config / init / sites / list / chapters（秒级完成，直接返回 CLI JSON）
//   - 异步任务：search / add / add-url / download / update-check / delete / clean
//     由服务端任务引擎管理生命周期，返回 task_id，状态/日志/结果经 /tasks 查询，
//     可通过 /tasks/:id/stop 中断。
//
// 响应约定与 comix 协议一致：业务错误（ok=false，如多候选、未找到）返回
// HTTP 200 并附带 candidates；仅传输/配置级故障返回 HTTP 500。
package comix_handler

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/repository/comix_repo"
	"monarch/internal/service/comix"
)

const syncTimeout = 90 * time.Second

// ---- 请求体 ----

type DownloadRequest struct {
	ComicID       int    `json:"comic_id"`
	Range         string `json:"range,omitempty"`
	Latest        *int   `json:"latest,omitempty"`
	NoRetryFailed bool   `json:"no_retry_failed,omitempty"`
}

type UpdateCheckRequest struct {
	ComicID  *int `json:"comic_id,omitempty"`
	All      bool `json:"all,omitempty"`
	Download bool `json:"download,omitempty"`
	Latest   *int `json:"latest,omitempty"`
}

type DeleteRequest struct {
	ComicID   int  `json:"comic_id"`
	KeepFiles bool `json:"keep_files,omitempty"`
}

// ---- 同步命令 ----

// GetConfig 返回 comix 集成配置（只读展示用）。
func GetConfig(c *gin.Context) {
	available, message := comix.Available()
	c.JSON(http.StatusOK, gin.H{
		"ok": true,
		"data": gin.H{
			"python":            comix.PythonExecutable(),
			"configured_python": config.ComixConf.Python,
			"root":              config.ComixConf.Root,
			"available":         available,
			"message":           message,
		},
	})
}

// ---- 同步查询（直查库，毫秒级） ----

// Init 建表并注册站点（幂等，Python 端）。
func Init(c *gin.Context) {
	runSync(c, "init")
}

// Sites 列出可用站点（直查库）。
func Sites(c *gin.Context) {
	sites, err := comix_repo.ListSites()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"ok": false, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": gin.H{"sites": sites}})
}

// List 列出已登记漫画（直查库，单条 SQL 聚合）。
func List(c *gin.Context) {
	comics, err := comix_repo.ListComics()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"ok": false, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": gin.H{"comics": comics}})
}

// Chapters 查看指定漫画的章节状态（直查库，精简列）。
func Chapters(c *gin.Context) {
	comicID, err := strconv.Atoi(c.Param("comic-id"))
	if err != nil || comicID <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"ok": false, "error": "comic-id 无效"})
		return
	}
	chapters, err := comix_repo.ListChapters(comicID)
	if err != nil {
		if errors.Is(err, comix_repo.ErrComicNotFound) {
			c.JSON(http.StatusOK, gin.H{"ok": false, "error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"ok": false, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"ok":   true,
		"data": gin.H{"comic_id": comicID, "chapters": chapters},
	})
}

// Delete 删除漫画（直查库：DB 级联 + 文件删除，可 keep-files）。
func Delete(c *gin.Context) {
	var req DeleteRequest
	if err := c.ShouldBindJSON(&req); err != nil || req.ComicID <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"ok": false, "error": "缺少 comic_id"})
		return
	}
	result, err := comix_repo.DeleteComic(req.ComicID, req.KeepFiles)
	if err != nil {
		if errors.Is(err, comix_repo.ErrComicNotFound) {
			c.JSON(http.StatusOK, gin.H{"ok": false, "error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"ok": false, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": result})
}

// ---- 异步任务（Python 端爬虫操作） ----

// DownloadURL 按详情页 URL 批量启动下载任务。
//
// 每个 URL 自动识别站点（comix.site.base_url host 匹配），识别成功后
// 启动独立异步任务（多个 URL 并发下载）；不支持的站点在对应条目中
// 返回明确错误，不影响其他 URL。
func DownloadURL(c *gin.Context) {
	var req struct {
		URLs   []string `json:"urls"`
		Latest *int     `json:"latest,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || len(req.URLs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"ok": false, "error": "缺少 urls 列表"})
		return
	}

	sites, err := comix_repo.ListSites()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"ok": false, "error": err.Error()})
		return
	}

	type urlTask struct {
		URL    string `json:"url"`
		Site   string `json:"site,omitempty"`
		TaskID string `json:"task_id,omitempty"`
		Status string `json:"status,omitempty"`
		Error  string `json:"error,omitempty"`
	}
	tasks := make([]urlTask, 0, len(req.URLs))

	for _, raw := range req.URLs {
		raw = strings.TrimSpace(raw)
		if raw == "" {
			continue
		}
		siteCode, matchErr := comix_repo.MatchSiteByURL(raw, sites)
		if matchErr != nil {
			tasks = append(tasks, urlTask{URL: raw, Error: matchErr.Error()})
			continue
		}
		args := []string{siteCode, raw}
		if req.Latest != nil {
			args = append(args, "--latest", strconv.Itoa(*req.Latest))
		}
		task, startErr := comix.Manager.Start("下载: "+raw, "add-url", args...)
		if startErr != nil {
			tasks = append(tasks, urlTask{URL: raw, Site: siteCode, Error: startErr.Error()})
			continue
		}
		tasks = append(tasks, urlTask{
			URL: raw, Site: siteCode, TaskID: task.ID, Status: string(task.Status),
		})
	}

	c.JSON(http.StatusOK, gin.H{"ok": true, "data": gin.H{"tasks": tasks}})
}

// Download 增量下载指定漫画。
func Download(c *gin.Context) {
	var req DownloadRequest
	if err := c.ShouldBindJSON(&req); err != nil || req.ComicID <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"ok": false, "error": "缺少 comic_id"})
		return
	}
	args := []string{strconv.Itoa(req.ComicID)}
	if req.Range != "" {
		args = append(args, "--range", req.Range)
	}
	if req.Latest != nil {
		args = append(args, "--latest", strconv.Itoa(*req.Latest))
	}
	if req.NoRetryFailed {
		args = append(args, "--no-retry-failed")
	}
	startTask(c, "下载 #"+strconv.Itoa(req.ComicID), "download", args...)
}

// UpdateCheck 连载更新检查（可选自动下载）。
func UpdateCheck(c *gin.Context) {
	var req UpdateCheckRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"ok": false, "error": "请求体无效"})
		return
	}
	args := []string{}
	if req.ComicID != nil {
		args = append(args, "--comic-id", strconv.Itoa(*req.ComicID))
	} else if req.All {
		args = append(args, "--all")
	}
	if req.Download {
		args = append(args, "--download")
	}
	if req.Latest != nil {
		args = append(args, "--latest", strconv.Itoa(*req.Latest))
	}
	name := "追更检查"
	if req.ComicID != nil {
		name = "追更检查 #" + strconv.Itoa(*req.ComicID)
	} else if req.All {
		name = "全站追更检查"
	}
	startTask(c, name, "update-check", args...)
}

// Clean 回收中断残留（running 任务 + .downloading 临时目录）。
func Clean(c *gin.Context) {
	startTask(c, "孤儿回收 clean", "clean")
}

// ---- 任务生命周期 ----

// ListTasks 列出任务（含运行中与最近完成的）。
func ListTasks(c *gin.Context) {
	tasks := comix.Manager.List()
	type summary struct {
		ID         string           `json:"id"`
		Name       string           `json:"name"`
		Command    string           `json:"command"`
		Status     comix.TaskStatus `json:"status"`
		PID        int              `json:"pid"`
		StartedAt  time.Time        `json:"started_at"`
		FinishedAt *time.Time       `json:"finished_at"`
		ExitCode   *int             `json:"exit_code"`
		Error      string           `json:"error"`
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

// GetTask 获取任务详情（状态/日志/结果）。
func GetTask(c *gin.Context) {
	task, err := comix.Manager.Get(c.Param("task-id"))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"ok": false, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": task})
}

// StopTask 中断运行中的任务。
func StopTask(c *gin.Context) {
	taskID := c.Param("task-id")
	if err := comix.Manager.Stop(taskID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"ok": false, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": gin.H{"task_id": taskID, "status": comix.TaskKilled}})
}

// ---- 内部辅助 ----

// runSync 同步执行一次快速 comix 命令并直接返回其 JSON 结果。
func runSync(c *gin.Context, cmd string, rest ...string) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), syncTimeout)
	defer cancel()
	result, err := comix.RunSync(ctx, cmd, rest...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"ok": false, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, result)
}

// startTask 创建异步任务并返回任务摘要。
func startTask(c *gin.Context, name, cmd string, rest ...string) {
	task, err := comix.Manager.Start(name, cmd, rest...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"ok": false, "error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"ok": true,
		"data": gin.H{
			"task_id":    task.ID,
			"name":       task.Name,
			"status":     task.Status,
			"command":    task.Command,
			"started_at": task.StartedAt,
		},
	})
}
