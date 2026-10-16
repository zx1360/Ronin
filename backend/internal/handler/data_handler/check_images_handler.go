package data_handler

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"monarch/internal/model"

	"github.com/gin-gonic/gin"
)

// CheckImagesRequest 客户端请求检查图片是否已存在的请求体
type CheckImagesRequest struct {
	Filenames []string `json:"filenames"`
}

// CheckImagesResponse 返回已存在和缺失的图片文件名
type CheckImagesResponse struct {
	Existing           []string `json:"existing"`
	Missing            []string `json:"missing"`
	EssaySchemaVersion int      `json:"essay_schema_version,omitempty"`
}

// CheckImagesHandler 检查指定模块的图片目录中哪些文件已存在
func CheckImagesHandler(c *gin.Context) {
	moduleName := c.Param("module")
	moduleConfig := FindModuleConfigByName(moduleName)
	if moduleConfig == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "模块未找到"})
		return
	}

	var req CheckImagesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求格式无效: " + err.Error()})
		return
	}

	existing := make([]string, 0)
	missing := make([]string, 0)

	for _, filename := range req.Filenames {
		if filename != filepath.Base(filename) || !filepath.IsLocal(filename) || filename == "." || strings.ContainsAny(filename, "/\\") {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的图片文件名"})
			return
		}
		fullPath := filepath.Join(moduleConfig.ImageDir, filename)

		if info, err := os.Stat(fullPath); err == nil && info.Mode().IsRegular() && info.Size() > 0 {
			existing = append(existing, filename)
		} else {
			missing = append(missing, filename)
		}
	}

	version := 0
	if moduleName == "essay" {
		version = model.EssaySchemaVersion
	}
	c.JSON(http.StatusOK, CheckImagesResponse{
		Existing:           existing,
		Missing:            missing,
		EssaySchemaVersion: version,
	})
}
