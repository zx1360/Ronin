package data_handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strconv"

	"monarch/internal/repository/data_repo"

	"github.com/gin-gonic/gin"
)

// SyncHandler 处理数据同步请求
func SyncHandler(c *gin.Context) {
	moduleName := c.Param("module")
	moduleConfig := FindModuleConfigByName(moduleName)

	if moduleConfig == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "模块未找到"})
		return
	}

	if moduleConfig.IsDB {
		syncFromDB(c, moduleName)
		return
	}

	// 原有 JSON 文件模式（preferences 等）
	syncFromFiles(c, moduleConfig)
}

func syncFromDB(c *gin.Context, moduleName string) {
	if c.Query("sync_version") != "2" {
		c.JSON(http.StatusConflict, gin.H{"error": "请更新客户端后使用增量合并同步（sync_version=2）"})
		return
	}
	after := int64(0)
	if raw := c.Query("after"); raw != "" {
		value, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || value < 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的同步游标"})
			return
		}
		after = value
	}
	data, err := data_repo.ReadSync(moduleName, after)
	if err != nil {
		if errors.Is(err, data_repo.ErrInvalidSyncCursor) {
			c.JSON(http.StatusConflict, gin.H{"error": err.Error(), "code": "invalid_sync_cursor"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}
	c.JSON(http.StatusOK, data)
}

// syncFromFiles 从 JSON 文件读取数据（保留原有逻辑，用于 preferences 等）
func syncFromFiles(c *gin.Context, moduleConfig *ModuleConfig) {
	backupMu.Lock()
	defer backupMu.Unlock()
	mergedData := make(map[string]interface{})
	for _, filePath := range moduleConfig.JSONFiles {
		content, err := os.ReadFile(filePath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "读取文件失败: " + err.Error()})
			return
		}

		var data interface{}
		if err := json.Unmarshal(content, &data); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "解析文件 " + filepath.Base(filePath) + " 失败: " + err.Error()})
			return
		}

		key := filepath.Base(filePath)
		key = key[:len(key)-len(filepath.Ext(key))]
		mergedData[key] = data
	}

	c.JSON(http.StatusOK, mergedData)
}
