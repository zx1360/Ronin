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
// 目录用量缓存：static 等大目录的统计由后台按 TTL 刷新，请求只读缓存（毫秒级）。
// gallery 的 Media/Deleted 数量与体积不遍历磁盘，改由 DB 聚合提供。
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
	for _, root := range cachedUsageRoots() {
		usage := collectDirUsage(root)
		usageCacheMu.Lock()
		usageCache[root] = usage
		usageCacheMu.Unlock()
	}
}

func cachedUsageRoots() []string {
	roots := []string{config.AppConf.StaticDir}
	if config.AppConf.GalleryDir == "" {
		return roots
	}
	return append(roots,
		config.AppConf.GalleryDir,
		filepath.Join(config.AppConf.GalleryDir, "Thumbs"),
		filepath.Join(config.AppConf.GalleryDir, "Preview"),
	)
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

// galleryDBStats gallery 媒体文件的聚合统计（由 media_assets 直接算出，无需遍历磁盘）。
type galleryDBStats struct {
	MediaFiles   int64
	MediaBytes   int64
	DeletedFiles int64
	DeletedBytes int64
	DBError      string
}

func queryGalleryDBStats(ctx context.Context) galleryDBStats {
	var stats galleryDBStats
	pool := db.Read()
	if pool == nil {
		stats.DBError = "database pool is nil"
		return stats
	}
	err := pool.QueryRowContext(ctx, `
		SELECT
			COUNT(*) FILTER (WHERE NOT is_deleted),
			COALESCE(SUM(size_bytes) FILTER (WHERE NOT is_deleted), 0),
			COUNT(*) FILTER (WHERE is_deleted),
			COALESCE(SUM(size_bytes) FILTER (WHERE is_deleted), 0)
		FROM media_assets
	`).Scan(&stats.MediaFiles, &stats.MediaBytes, &stats.DeletedFiles, &stats.DeletedBytes)
	if err != nil {
		stats.DBError = err.Error()
	}
	return stats
}

// SystemOverview 返回服务端基础运维信息，便于桌面端统一展示。
func SystemOverview(c *gin.Context) {
	galleryStats := queryGalleryDBStats(c.Request.Context())

	currentPort := config.NetConf.LocalPort
	if config.IsLocalMode {
		currentPort = config.NetConf.LocalDebugPort
	}
	// 桌面端需要直接读写封面等文件，因此必须给出绝对路径：服务端与客户端的
	// 工作目录不同，相对路径在客户端无法解析。
	staticDir, absErr := filepath.Abs(config.AppConf.StaticDir)
	staticDirError := ""
	if absErr != nil {
		staticDirError = absErr.Error()
	}

	dbReachable, dbErr := false, ""
	if err := db.Ping(c.Request.Context()); err != nil {
		dbErr = err.Error()
	} else {
		dbReachable = true
	}

	galleryDirUsage := func(sub string, files, bytes int64) dirUsage {
		return dirUsage{
			Path:   filepath.Join(config.AppConf.GalleryDir, sub),
			Exists: true,
			Files:  files,
			Bytes:  bytes,
			Error:  galleryStats.DBError,
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"service": gin.H{
			"isLocalMode":    config.IsLocalMode,
			"port":           currentPort,
			"staticDir":      staticDir,
			"staticDirError": staticDirError,
		},
		"database": gin.H{
			"reachable": dbReachable,
			"error":     dbErr,
		},
		"storage": gin.H{
			"static":         getCachedDirUsage(config.AppConf.StaticDir),
			"galleryRoot":    getCachedDirUsage(config.AppConf.GalleryDir),
			"galleryMedia":   galleryDirUsage("Media", galleryStats.MediaFiles, galleryStats.MediaBytes),
			"galleryThumbs":  getCachedDirUsage(filepath.Join(config.AppConf.GalleryDir, "Thumbs")),
			"galleryPreview": getCachedDirUsage(filepath.Join(config.AppConf.GalleryDir, "Preview")),
			"galleryDeleted": galleryDirUsage("Deleted", galleryStats.DeletedFiles, galleryStats.DeletedBytes),
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
