package data_handler

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	"monarch/internal/model"
	"monarch/internal/repository/data_repo"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

var backupMu sync.Mutex

func BackupHandler(c *gin.Context) {
	cfg := FindModuleConfigByName(c.Param("module"))
	if cfg == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "模块未找到"})
		return
	}
	// 10 MiB 为内存阈值，大文件由 net/http 暂存到磁盘。
	if err := c.Request.ParseMultipartForm(10 << 20); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "解析表单失败: " + err.Error()})
		return
	}
	defer c.Request.MultipartForm.RemoveAll()
	var payload map[string]json.RawMessage
	if err := json.Unmarshal([]byte(c.PostForm("jsonData")), &payload); err != nil || payload == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "jsonData 必须为完整的数据对象"})
		return
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
	for _, file := range c.Request.MultipartForm.File["files"] {
		if file.Filename != filepath.Base(file.Filename) || file.Size == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的图片文件: " + file.Filename})
			return
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": "备份失败: " + err.Error()})
		return
	}
	if cfg.IsDB {
		if _, err := data_repo.CleanOrphanImages(cfg.ImageDir, refs); err != nil {
			log.Printf("清理孤儿图片 (%s): %v", cfg.Name, err)
		}
	}
	c.JSON(http.StatusOK, gin.H{"status": "success", "message": "数据备份完成"})
}

func prepareBackup(cfg *ModuleConfig, payload map[string]json.RawMessage) (func() error, map[string]bool, error) {
	refs := make(map[string]bool)
	addImage := func(path string) {
		if path != "" {
			refs[filepath.Base(path)] = true
		}
	}
	switch cfg.Name {
	case "booklet":
		var data data_repo.BookletBackupData
		if err := decodeCollection(payload, "styles", &data.Styles); err != nil {
			return nil, nil, err
		}
		if err := decodeCollection(payload, "records", &data.Records); err != nil {
			return nil, nil, err
		}
		for i := range data.Styles {
			s := &data.Styles[i]
			if s.ID == uuid.Nil || s.StartDate.Time().IsZero() {
				return nil, nil, fmt.Errorf("打卡样式缺少 id 或 start_date")
			}
			s.StartDate = dateOnly(s.StartDate)
			data.StyleIDs = append(data.StyleIDs, s.ID)
			var tasks []*struct {
				Image string `json:"image"`
			}
			if err := json.Unmarshal(s.Tasks, &tasks); err != nil {
				return nil, nil, fmt.Errorf("无效的 tasks: %w", err)
			}
			if tasks == nil {
				return nil, nil, fmt.Errorf("tasks 必须为数组")
			}
			for _, task := range tasks {
				if task == nil {
					return nil, nil, fmt.Errorf("tasks 包含空项")
				}
				addImage(task.Image)
			}
		}
		for i := range data.Records {
			r := &data.Records[i]
			if r.ID == uuid.Nil || r.StyleID == uuid.Nil || r.Date.Time().IsZero() {
				return nil, nil, fmt.Errorf("打卡记录缺少 id、style_id 或 date")
			}
			r.Date = dateOnly(r.Date)
			data.RecordIDs = append(data.RecordIDs, r.ID)
		}
		return func() error { return data_repo.ReplaceBookletData(data) }, refs, nil
	case "essay":
		var data data_repo.EssayBackupData
		if err := decodeCollection(payload, "essays", &data.Articles); err != nil {
			return nil, nil, err
		}
		if err := decodeCollection(payload, "labels", &data.Labels); err != nil {
			return nil, nil, err
		}
		if err := decodeCollection(payload, "year_summaries", &data.YearSummaries); err != nil {
			return nil, nil, err
		}
		for _, a := range data.Articles {
			if a.ID == uuid.Nil || a.Date.Time().IsZero() {
				return nil, nil, fmt.Errorf("随笔缺少 id 或 date")
			}
			data.ArticleIDs = append(data.ArticleIDs, a.ID)
			for _, img := range a.Imgs {
				addImage(img)
			}
		}
		for _, l := range data.Labels {
			if l.ID == uuid.Nil {
				return nil, nil, fmt.Errorf("标签缺少 id")
			}
			data.LabelIDs = append(data.LabelIDs, l.ID)
		}
		for _, s := range data.YearSummaries {
			if s.Year <= 0 {
				return nil, nil, fmt.Errorf("无效的年份")
			}
			data.YearIDs = append(data.YearIDs, int(s.Year))
		}
		return func() error { return data_repo.ReplaceEssayData(data) }, refs, nil
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

// 缺失/null 与显式空数组不同；只有后者允许清空数据。
func decodeCollection[T any](payload map[string]json.RawMessage, key string, target *[]T) error {
	if err := json.Unmarshal(payload[key], target); err != nil {
		return fmt.Errorf("无效的 %s: %w", key, err)
	}
	if *target == nil {
		return fmt.Errorf("%s 必须为数组", key)
	}
	return nil
}

// 打卡日期为日历日，不换算时区。
func dateOnly(value model.FlexTime) model.FlexTime {
	t := value.Time()
	return model.FlexTime(time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC))
}

func fileKey(path string) string {
	name := filepath.Base(path)
	return name[:len(name)-len(filepath.Ext(name))]
}
