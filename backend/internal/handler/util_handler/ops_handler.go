package util_handler

import (
	"context"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/galleryfs"
	"monarch/internal/service/db"
)

type dirUsage struct {
	Path    string `json:"path"`
	Exists  bool   `json:"exists"`
	Files   int64  `json:"files"`
	Bytes   int64  `json:"bytes"`
	Pending bool   `json:"pending,omitempty"`
	Error   string `json:"error,omitempty"`
}

// ---------------------------------------------------------------------------
// 目录用量按需异步扫描；首次返回待统计，过期时返回旧值。
// Gallery 的 Media/Deleted 单项统计来自数据库。
// ---------------------------------------------------------------------------

const usageCacheTTL = 5 * time.Minute

var (
	usageCacheMu sync.Mutex
	usageCache   = map[dirUsageKey]*dirUsageEntry{}
)

type dirUsageKey struct {
	root, subdirs string
}

type dirUsageEntry struct {
	usage      dirUsage
	subdirs    map[string]dirUsage
	updatedAt  time.Time
	refreshing bool
}

func refreshDirUsage(root string, names []string, entry *dirUsageEntry) {
	subdirs := make(map[string]dirUsage, len(names))
	for _, name := range names {
		subdirs[dirNameKey(name)] = inspectDir(filepath.Join(root, name))
	}
	usage := collectDirUsage(root, subdirs)
	usageCacheMu.Lock()
	defer usageCacheMu.Unlock()
	entry.usage, entry.subdirs, entry.updatedAt, entry.refreshing = usage, subdirs, time.Now(), false
}

func getCachedDirUsage(root string) dirUsage {
	usage, _ := getCachedDirUsages(root)
	return usage
}

// getCachedDirUsages 在同一次遍历中统计根目录和指定的直接子目录。
func getCachedDirUsages(root string, names ...string) (dirUsage, map[string]dirUsage) {
	usageCacheMu.Lock()
	defer usageCacheMu.Unlock()
	key := dirUsageKey{root: root, subdirs: strings.Join(names, "/")}
	entry, ok := usageCache[key]
	if !ok {
		entry = &dirUsageEntry{
			usage:   dirUsage{Path: root, Pending: true},
			subdirs: make(map[string]dirUsage, len(names)),
		}
		for _, name := range names {
			entry.subdirs[dirNameKey(name)] = dirUsage{Path: filepath.Join(root, name), Pending: true}
		}
		usageCache[key] = entry
	}
	if !entry.refreshing && (entry.updatedAt.IsZero() || time.Since(entry.updatedAt) >= usageCacheTTL) {
		entry.refreshing = true
		go refreshDirUsage(root, names, entry)
	}
	return entry.usage, entry.subdirs
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
	galleryUsage, gallerySubdirs := getCachedDirUsages(config.AppConf.GalleryDir, galleryfs.Thumbs, galleryfs.Preview)
	staticUsage := galleryUsage
	if dirNameKey(filepath.Clean(config.AppConf.StaticDir)) == dirNameKey(filepath.Clean(config.AppConf.GalleryDir)) {
		staticUsage.Path = config.AppConf.StaticDir
	} else {
		staticUsage = getCachedDirUsage(config.AppConf.StaticDir)
	}

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
			"static":         staticUsage,
			"galleryRoot":    galleryUsage,
			"galleryMedia":   galleryDirUsage(galleryfs.Media, galleryStats.MediaFiles, galleryStats.MediaBytes),
			"galleryThumbs":  gallerySubdirs[dirNameKey(galleryfs.Thumbs)],
			"galleryPreview": gallerySubdirs[dirNameKey(galleryfs.Preview)],
			"galleryDeleted": galleryDirUsage(galleryfs.Deleted, galleryStats.DeletedFiles, galleryStats.DeletedBytes),
		},
	})
}

func inspectDir(root string) dirUsage {
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
	usage.Exists = true
	if !info.IsDir() {
		usage.Error = "path is not a directory"
	}
	return usage
}

func dirNameKey(name string) string {
	if runtime.GOOS == "windows" {
		return strings.ToLower(name)
	}
	return name
}

func collectDirUsage(root string, subdirs map[string]dirUsage) dirUsage {
	usage := inspectDir(root)
	if !usage.Exists || usage.Error != "" {
		return usage
	}

	separator := string(filepath.Separator)
	prefix := strings.TrimSuffix(filepath.Clean(root), separator) + separator
	rootLink := false
	walkErr := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		if path == root {
			rootLink = true
		}
		fileInfo, statErr := d.Info()
		if statErr != nil {
			return nil
		}
		usage.Files++
		usage.Bytes += fileInfo.Size()
		if len(subdirs) > 0 {
			name, _, _ := strings.Cut(strings.TrimPrefix(path, prefix), separator)
			key := dirNameKey(name)
			if child, ok := subdirs[key]; ok && child.Exists && child.Error == "" {
				child.Files++
				child.Bytes += fileInfo.Size()
				subdirs[key] = child
			}
		}
		return nil
	})
	if walkErr != nil {
		usage.Error = walkErr.Error()
	}
	if rootLink {
		for name, child := range subdirs {
			subdirs[name] = collectDirUsage(child.Path, nil)
		}
	}

	return usage
}
