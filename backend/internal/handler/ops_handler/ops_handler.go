package ops_handler

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/service/ops"
	"monarch/internal/settings"
)

// Capabilities 下发 ops 页面所需的固定清单：可用运行模式与路径。
//
// 页面不硬编码任务种类、参数范围与路径，"能用什么"完全由后端决定。
// resize 标记某模式是否接受 resize 系列参数，页面据此决定是否显示这些输入框。
func Capabilities(c *gin.Context) {
	available, reason := ops.GalleryAvailable()
	c.JSON(http.StatusOK, gin.H{
		"gallery": gin.H{
			"available": available,
			"reason":    reason,
			"cli":       config.ResolveGalleryCLI(),
			"modes": []gin.H{
				{"value": "ingest", "label": "摄入", "help": "将 Raw 中的新文件摄入媒体库", "resize": false},
				{"value": "execute", "label": "执行删除", "help": "执行已标记的软删除", "resize": false},
				{"value": "refresh", "label": "刷新修复", "help": "清理无效记录、重建派生图、补齐缺失项", "resize": true},
			},
			"defaults": gin.H{"concurrency": 10, "batch": 160},
		},
		"paths": gin.H{
			"galleryDir": config.AppConf.GalleryDir,
			"staticDir":  config.AppConf.StaticDir,
			"opsDir":     config.ResolveOpsDir(),
			"database":   config.DBPath,
		},
	})
}

// Dependencies 报告外部命令可用性（页面据此提示缺失依赖）。
func Dependencies(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"dependencies": ops.CheckDependencies()})
}

// ListDirectories 列出目录，供页面选择媒体库根目录等路径。
func ListDirectories(c *gin.Context) {
	parent, entries, err := ops.ListDirs(c.Query("path"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"parent": parent, "entries": entries})
}

// Reveal 在系统文件管理器中定位路径。
func Reveal(c *gin.Context) {
	var req struct {
		Path string `json:"path"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || req.Path == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 path"})
		return
	}
	if err := ops.RevealPath(req.Path); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GetPreferences 读取 ops 页面偏好。
func GetPreferences(c *gin.Context) {
	c.JSON(http.StatusOK, ops.LoadPreferences())
}

// UpdatePreferences 写入 ops 页面偏好。
//
// 校验与落盘都在服务层的同一把锁内完成：先读后写若分两步，两个并发 PUT 会互相覆盖。
func UpdatePreferences(c *gin.Context) {
	var patch struct {
		AutoRefreshSeconds *int      `json:"auto_refresh_seconds"`
		CollapsedSections  *[]string `json:"collapsed_sections"`
		LastTab            *string   `json:"last_tab"`
		LogAutoscroll      *bool     `json:"log_autoscroll"`
	}
	if err := c.ShouldBindJSON(&patch); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体无效: " + err.Error()})
		return
	}

	updated, err := ops.UpdatePreferences(func(current *ops.Preferences) error {
		if patch.AutoRefreshSeconds != nil {
			if *patch.AutoRefreshSeconds < 1 || *patch.AutoRefreshSeconds > 3600 {
				return fmt.Errorf("auto_refresh_seconds 需在 1..3600")
			}
			current.AutoRefreshSeconds = *patch.AutoRefreshSeconds
		}
		if patch.CollapsedSections != nil {
			current.CollapsedSections = *patch.CollapsedSections
		}
		if patch.LastTab != nil {
			current.LastTab = *patch.LastTab
		}
		if patch.LogAutoscroll != nil {
			current.LogAutoscroll = *patch.LogAutoscroll
		}
		return nil
	})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, updated)
}

// RunGallery 启动一次 gallery CLI 任务。
func RunGallery(c *gin.Context) {
	var req ops.GalleryOptions
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体无效: " + err.Error()})
		return
	}
	task, err := ops.Gallery.StartGallery(req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusAccepted, task)
}

// ListGalleryTasks 返回 gallery 任务列表。
func ListGalleryTasks(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"tasks": ops.Gallery.ListGallery()})
}

// GetGalleryTask 返回单个 gallery 任务（含日志）。
func GetGalleryTask(c *gin.Context) {
	task, err := ops.Gallery.GetGallery(c.Param("task-id"))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, task)
}

// StopGalleryTask 中断 gallery 任务。
func StopGalleryTask(c *gin.Context) {
	taskID := c.Param("task-id")
	if _, err := ops.Gallery.GetGallery(taskID); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	if err := ops.Gallery.StopGallery(taskID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GetSettings 返回运行时配置：生效值与全部配置项描述。
//
// 页面按 schema 生成表单，新增配置项不需要改前端。
func GetSettings(c *gin.Context) {
	values := settings.All()
	c.JSON(http.StatusOK, gin.H{
		"values": values,
		"schema": settings.Schema(),
	})
}

// UpdateSettings 写入运行时配置，并立即刷新类型化配置对象。
func UpdateSettings(c *gin.Context) {
	var patch map[string]string
	if err := c.ShouldBindJSON(&patch); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体需为 配置项→值 的对象: " + err.Error()})
		return
	}
	changed, err := settings.Update(c.Request.Context(), patch)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	config.ApplySettings(settings.All())
	c.JSON(http.StatusOK, gin.H{
		"changed": changed,
		"values":  settings.All(),
	})
}
