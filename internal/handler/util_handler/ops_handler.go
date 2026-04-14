package util_handler

import (
	"errors"
	"net/http"
	"os"
	"path/filepath"

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

// SystemOverview 返回服务端基础运维信息，便于桌面端统一展示。
func SystemOverview(c *gin.Context) {
	staticUsage := collectDirUsage(config.AppConf.StaticDir)
	galleryRootUsage := collectDirUsage(config.AppConf.GalleryDir)
	galleryMediaUsage := collectDirUsage(filepath.Join(config.AppConf.GalleryDir, "Media"))
	galleryThumbsUsage := collectDirUsage(filepath.Join(config.AppConf.GalleryDir, "Thumbs"))
	galleryPreviewUsage := collectDirUsage(filepath.Join(config.AppConf.GalleryDir, "Preview"))
	galleryDeletedUsage := collectDirUsage(filepath.Join(config.AppConf.GalleryDir, "Deleted"))

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
