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
// 目录用量缓存：首次访问计算，过期后返回旧值并异步刷新。
// gallery 的 Media/Deleted 数量与体积不遍历磁盘，改由 DB 聚合提供。
// ---------------------------------------------------------------------------

const usageCacheTTL = 5 * time.Minute

var (
	usageCacheMu sync.Mutex
	usageCache   = map[string]*dirUsageEntry{}
)

type dirUsageEntry struct {
	usage      dirUsage
	updatedAt  time.Time
	refreshing bool
	ready      chan struct{}
}

func refreshDirUsage(root string, entry *dirUsageEntry) {
	usage := collectDirUsage(root)
	usageCacheMu.Lock()
	defer usageCacheMu.Unlock()
	if entry.updatedAt.IsZero() {
		close(entry.ready)
	}
	entry.usage, entry.updatedAt, entry.refreshing = usage, time.Now(), false
}

// getCachedDirUsage 同一目录的并发访问共用一次扫描。
func getCachedDirUsage(root string) dirUsage {
	usageCacheMu.Lock()
	entry, ok := usageCache[root]
	if !ok {
		entry = &dirUsageEntry{ready: make(chan struct{})}
		usageCache[root] = entry
	}
	if entry.updatedAt.IsZero() {
		usageCacheMu.Unlock()
		if !ok {
			refreshDirUsage(root, entry)
		}
		<-entry.ready
		usageCacheMu.Lock()
	} else if !entry.refreshing && time.Since(entry.updatedAt) >= usageCacheTTL {
		entry.refreshing = true
		go refreshDirUsage(root, entry)
	}
	usage := entry.usage
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

// SystemOverview 返回服务端基础运维信息，便于网页运维端统一展示。
func SystemOverview(c *gin.Context) {
	galleryStats := queryGalleryDBStats(c.Request.Context())

	// 网页端需要直接读写文件（如资源管理器定位），因此必须给出绝对路径：
	// 服务端与浏览器的路径视角不同，相对路径无法解析。
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
			"port":           ServedPort(c),
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
