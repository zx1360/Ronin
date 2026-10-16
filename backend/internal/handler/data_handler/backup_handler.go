package data_handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"sync"

	"monarch/internal/repository/data_repo"

	"github.com/gin-gonic/gin"
)

var backupMu sync.Mutex

func BackupHandler(c *gin.Context) {
	cfg := FindModuleConfigByName(c.Param("module"))
	if cfg == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "模块未找到"})
		return
	}
	var payload map[string]json.RawMessage
	if c.ContentType() == "application/json" {
		if !cfg.IsDB || c.ShouldBindJSON(&payload) != nil || payload == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "需要用户数据对象"})
			return
		}
	} else {
		if err := c.Request.ParseMultipartForm(10 << 20); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析表单失败: " + err.Error()})
			return
		}
		defer c.Request.MultipartForm.RemoveAll()
		if err := json.Unmarshal([]byte(c.PostForm("jsonData")), &payload); err != nil || payload == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "jsonData 必须为数据对象"})
			return
		}
	}
	writeData, refs, err := prepareBackup(cfg, payload)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	backupMu.Lock()
	defer backupMu.Unlock()
	files, err := newBackupFiles(filepath.Dir(cfg.ImageDir))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer files.close()
	var uploads []*multipart.FileHeader
	if c.Request.MultipartForm != nil {
		uploads = c.Request.MultipartForm.File["files"]
	}
	for _, file := range uploads {
		if file.Filename != filepath.Base(file.Filename) || file.Size == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的图片文件: " + file.Filename})
			return
		}
		if cfg.IsDB {
			if !refs[file.Filename] {
				c.JSON(http.StatusBadRequest, gin.H{"error": "上传图片未被数据引用: " + file.Filename})
				return
			}
			if old, err := os.ReadFile(filepath.Join(cfg.ImageDir, file.Filename)); err == nil {
				incoming, err := file.Open()
				if err != nil {
					c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
					return
				}
				raw, err := io.ReadAll(incoming)
				incoming.Close()
				if err != nil || !bytes.Equal(old, raw) {
					c.JSON(http.StatusConflict, gin.H{"error": "图片同名且内容不同，请重新选择图片: " + file.Filename})
					return
				}
				continue
			}
		}
		if err := files.add(filepath.Join(cfg.ImageDir, file.Filename), func(path string) error {
			return c.SaveUploadedFile(file, path)
		}); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "暂存图片失败: " + err.Error()})
			return
		}
	}
	for name := range refs {
		path := filepath.Join(cfg.ImageDir, name)
		if !files.contains(path) {
			if info, err := os.Stat(path); err != nil || !info.Mode().IsRegular() {
				c.JSON(http.StatusBadRequest, gin.H{"error": "缺少引用图片: " + name})
				return
			}
		}
	}
	for _, path := range cfg.JSONFiles {
		if err := files.add(path, func(staged string) error {
			return os.WriteFile(staged, payload[fileKey(path)], 0o644)
		}); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}
	if err := files.commit(writeData); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "数据未写入: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "success", "sync_version": data_repo.SyncVersion, "message": "数据合并完成"})
}

func prepareBackup(cfg *ModuleConfig, payload map[string]json.RawMessage) (func() error, map[string]bool, error) {
	refs := make(map[string]bool)
	addImage := func(path string) {
		if path != "" {
			refs[filepath.Base(path)] = true
		}
	}
	switch cfg.Name {
	case "booklet", "essay":
		raw, err := json.Marshal(payload)
		if err != nil {
			return nil, nil, err
		}
		var data data_repo.SyncData
		if err := json.Unmarshal(raw, &data); err != nil {
			return nil, nil, err
		}
		if data.SyncVersion != data_repo.SyncVersion {
			return nil, nil, fmt.Errorf("请更新客户端后使用增量合并同步（sync_version=2）")
		}
		refs, err := data.Images(cfg.Name)
		if err != nil {
			return nil, nil, err
		}
		return func() error { return data_repo.MergeSync(cfg.Name, data) }, refs, nil
	case "preferences":
		var prefs struct {
			BackgroundImages []string `json:"backgroundImages"`
			SidebarImages    []string `json:"sidebarImages"`
			AvatarPath       string   `json:"avatarPath"`
		}
		raw := payload["preferences"]
		if len(raw) == 0 || string(raw) == "null" {
			return nil, nil, fmt.Errorf("缺少 preferences 对象")
		}
		if err := json.Unmarshal(raw, &prefs); err != nil {
			return nil, nil, err
		}
		for _, image := range append(prefs.BackgroundImages, prefs.SidebarImages...) {
			addImage(image)
		}
		addImage(prefs.AvatarPath)
		return func() error { return nil }, refs, nil
	default:
		return nil, nil, fmt.Errorf("不支持的模块: %s", cfg.Name)
	}
}

func fileKey(path string) string {
	name := filepath.Base(path)
	return name[:len(name)-len(filepath.Ext(name))]
}
