package data_handler

import (
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

// CheckImagesRequest 客户端请求检查图片是否已存在的请求体
type CheckImagesRequest struct {
	Filenames []string `json:"filenames"`
}

// CheckImagesResponse 返回已存在和缺失的图片文件名
type CheckImagesResponse struct {
	Existing []string `json:"existing"`
	Missing  []string `json:"missing"`
}

// CheckImagesHandler 检查指定模块的图片目录中哪些文件已存在
// @Summary 检查图片文件是否已存在于服务端
// @Description 接收文件名列表，返回哪些已存在、哪些缺失（用于增量上传）
// @Tags user-data
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param module path string true "模块名称"
// @Param body body CheckImagesRequest true "待检查的文件名列表"
// @Success 200 {object} CheckImagesResponse
// @Failure 404 {object} map[string]string
// @Router /api/user-data/check-images/{module} [post]
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
		// 安全校验：只取文件名（不含路径），防止目录穿越
		baseName := filepath.Base(filename)
		fullPath := filepath.Join(moduleConfig.ImageDir, baseName)

		if _, err := os.Stat(fullPath); err == nil {
			existing = append(existing, filename)
		} else if os.IsNotExist(err) {
			missing = append(missing, filename)
		} else {
			// 其他错误（权限等）视为缺失
			missing = append(missing, filename)
		}
	}

	c.JSON(http.StatusOK, CheckImagesResponse{
		Existing: existing,
		Missing:  missing,
	})
}
