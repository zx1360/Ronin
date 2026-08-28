package util_handler

import (
	"context"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/service/db"
)

type dirUsage struct {
	Path   string `json:"path"`
	Exists bool   `json:"exists"`
	Files  int64  `json:"files"`
	Bytes  int64  `json:"bytes"`
	Error  string `json:"error,omitempty"`
}

// ---------------------------------------------------------------------------
// 目录用量缓存：static 等大目录的统计在后台按 TTL 刷新，请求只读缓存（毫秒级）。
// ---------------------------------------------------------------------------

const usageCacheTTL = 5 * time.Minute

var (
	usageCacheMu   sync.Mutex
	usageCache     = map[string]dirUsage{}
	usageRefresher sync.Once
)

// StartDirUsageRefresher 启动后台目录统计刷新（服务启动时调用，预热缓存）。
func StartDirUsageRefresher() {
	usageRefresher.Do(func() {
		go func() {
			refreshAllDirUsage()
			ticker := time.NewTicker(usageCacheTTL)
			defer ticker.Stop()
			for range ticker.C {
				refreshAllDirUsage()
			}
		}()
	})
}

func refreshAllDirUsage() {
	roots := cachedUsageRoots()
	for _, root := range roots {
		usage := collectDirUsage(root)
		usageCacheMu.Lock()
		usageCache[root] = usage
		usageCacheMu.Unlock()
	}
}

func cachedUsageRoots() []string {
	// static 目录与 gallery 中不依赖 DB 统计的子目录（Media/Deleted 由 DB 提供）
	roots := []string{config.AppConf.StaticDir}
	if config.AppConf.GalleryDir != "" {
		roots = append(roots,
			config.AppConf.GalleryDir,
			filepath.Join(config.AppConf.GalleryDir, "Thumbs"),
			filepath.Join(config.AppConf.GalleryDir, "Preview"),
		)
	}
	return roots
}

// getCachedDirUsage 返回目录用量；缓存未就绪时同步计算（服务刚启动的罕见情况）。
func getCachedDirUsage(root string) dirUsage {
	usageCacheMu.Lock()
	usage, ok := usageCache[root]
	usageCacheMu.Unlock()
	if ok {
		return usage
	}
	usage = collectDirUsage(root)
	usageCacheMu.Lock()
	usageCache[root] = usage
	usageCacheMu.Unlock()
	return usage
}

// ---------------------------------------------------------------------------
// gallery DB 统计（media_assets 聚合，毫秒级，无需遍历磁盘）
// ---------------------------------------------------------------------------

type galleryDBStats struct {
	MediaFiles   int64
	MediaBytes   int64
	DeletedFiles int64
	DeletedBytes int64
	DBError      string
}

func queryGalleryDBStats(ctx context.Context) galleryDBStats {
	var stats galleryDBStats
	pool := db.GetPool()
	if pool == nil {
		stats.DBError = "database pool is nil"
		return stats
	}
	err := pool.QueryRow(ctx, `
		SELECT
			COUNT(*)                                                      AS total,
			COUNT(*) FILTER (WHERE is_deleted)                            AS deleted,
			COALESCE(SUM(size_bytes) FILTER (WHERE NOT is_deleted), 0)    AS media_bytes,
			COALESCE(SUM(size_bytes) FILTER (WHERE is_deleted), 0)        AS deleted_bytes
		FROM gallery.media_assets
	`).Scan(&stats.MediaFiles, &stats.DeletedFiles, &stats.MediaBytes, &stats.DeletedBytes)
	if err != nil {
		stats.DBError = err.Error()
		return stats
	}
	stats.MediaFiles -= stats.DeletedFiles
	return stats
}

// SystemOverview 返回服务端基础运维信息，便于桌面端统一展示。
// 优化：gallery Media/Deleted 用 DB 聚合（毫秒级）；static 等目录用量由后台
// TTL 缓存提供（5 分钟刷新，启动预热），避免每次请求全量遍历磁盘。
// @Summary 获取服务端运行概览
// @Tags util
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} map[string]interface{}
// @Router /api/ops/overview [get]
func SystemOverview(c *gin.Context) {
	StartDirUsageRefresher() // 幂等：确保后台刷新已启动

	galleryStats := queryGalleryDBStats(c.Request.Context())

	staticUsage := getCachedDirUsage(config.AppConf.StaticDir)
	galleryRootUsage := getCachedDirUsage(config.AppConf.GalleryDir)
	galleryThumbsUsage := getCachedDirUsage(filepath.Join(config.AppConf.GalleryDir, "Thumbs"))
	galleryPreviewUsage := getCachedDirUsage(filepath.Join(config.AppConf.GalleryDir, "Preview"))

	galleryMediaUsage := dirUsage{
		Path:   filepath.Join(config.AppConf.GalleryDir, "Media"),
		Exists: true,
		Files:  galleryStats.MediaFiles,
		Bytes:  galleryStats.MediaBytes,
		Error:  galleryStats.DBError,
	}
	galleryDeletedUsage := dirUsage{
		Path:   filepath.Join(config.AppConf.GalleryDir, "Deleted"),
		Exists: true,
		Files:  galleryStats.DeletedFiles,
		Bytes:  galleryStats.DeletedBytes,
		Error:  galleryStats.DBError,
	}

	dbReachable := false
	dbErr := ""
	if pool := db.GetPool(); pool != nil {
		if err := pool.Ping(c.Request.Context()); err != nil {
			dbErr = err.Error()
		} else {
			dbReachable = true
		}
	} else {
		dbErr = "database pool is nil"
	}

	c.JSON(http.StatusOK, gin.H{
		"service": gin.H{
			"isLocalMode": config.IsLocalMode,
			"port": func() string {
				if config.IsLocalMode {
					return config.NetConf.LocalDebugPort
				}
				return config.NetConf.LocalPort
			}(),
		},
		"database": gin.H{
			"reachable": dbReachable,
			"error":     dbErr,
		},
		"storage": gin.H{
			"static":         staticUsage,
			"galleryRoot":    galleryRootUsage,
			"galleryMedia":   galleryMediaUsage,
			"galleryThumbs":  galleryThumbsUsage,
			"galleryPreview": galleryPreviewUsage,
			"galleryDeleted": galleryDeletedUsage,
		},
	})
}

func collectDirUsage(root string) dirUsage {
	usage := dirUsage{Path: root}
	if root == "" {
		usage.Error = "path is empty"
		return usage
	}

	info, err := os.Stat(root)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			usage.Exists = false
			return usage
		}
		usage.Error = err.Error()
		return usage
	}
	if !info.IsDir() {
		usage.Exists = true
		usage.Error = "path is not a directory"
		return usage
	}

	usage.Exists = true
	walkErr := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			return nil
		}
		fileInfo, statErr := d.Info()
		if statErr != nil {
			return nil
		}
		usage.Files++
		usage.Bytes += fileInfo.Size()
		return nil
	})
	if walkErr != nil {
		usage.Error = walkErr.Error()
	}

	return usage
}
