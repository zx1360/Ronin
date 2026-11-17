package data_handler

import (
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strconv"

	"monarch/internal/model"
	"monarch/internal/repository/data_repo"

	"github.com/gin-gonic/gin"
)

func SyncHandler(c *gin.Context) {
	moduleName := c.Param("module")
	if !validModule(moduleName) {
		c.JSON(http.StatusNotFound, gin.H{"error": "模块未找到"})
		return
	}

	if moduleName == "preferences" {
		syncPreferences(c)
		return
	}
	syncFromDB(c, moduleName)
}

func syncFromDB(c *gin.Context, moduleName string) {
	if c.Query("sync_version") != strconv.Itoa(data_repo.SyncVersion) {
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
	if moduleName == "essay" {
		version, _ := strconv.Atoi(c.Query("essay_schema_version"))
		data["essay_schema_version"] = model.EssaySchemaFor(version)
	}
	c.JSON(http.StatusOK, data)
}

func syncPreferences(c *gin.Context) {
	backupMu.Lock()
	defer backupMu.Unlock()
	filePath := preferencesPath()
	content, err := os.ReadFile(filePath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "读取文件失败: " + err.Error()})
		return
	}
	data, err := readPreferences(content)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "解析文件 " + filepath.Base(filePath) + " 失败: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"preferences": data})
}
