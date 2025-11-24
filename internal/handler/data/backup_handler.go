package data

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

// BackupData 处理 POST 请求，用于备份指定模块的数据
// 它期望接收一个 JSON 字段和一个或多个图片文件
func BackupData(c *gin.Context) {
	moduleName := c.Param("module_name")

	config, exists := GetModuleConfig(moduleName)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("模块 '%s' 不存在", moduleName)})
		return
	}

	// 1. 确保目标目录存在，如果不存在则创建
	if err := os.MkdirAll(config.ImageDir, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "无法创建图片存储目录"})
		return
	}

	// 2. 处理 JSON 数据
	// 定义一个结构体来接收 JSON 数据
	var jsonData map[string]interface{}
	if err := c.ShouldBindJSON(&jsonData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 JSON 数据"})
		return
	}

	// 将 JSON 数据保存到文件
	jsonFilePath := config.JSONPath
	data, _ := c.GetRawData()
	if err := os.WriteFile(jsonFilePath, []byte(data), 0644); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "无法保存 JSON 数据"})
		return
	}

	// 3. 处理上传的图片文件
	// 假设前端使用 "images" 作为表单字段名
	form, _ := c.MultipartForm()
	files := form.File["images"]

	if len(files) == 0 {
		c.JSON(http.StatusOK, gin.H{
			"message": "JSON 数据已备份，但未收到任何图片文件。",
			"data":    jsonData,
		})
		return
	}

	for _, file := range files {
		// 构建文件路径
		filename := filepath.Base(file.Filename)
		dst := filepath.Join(config.ImageDir, filename)

		// 保存文件
		if err := c.SaveUploadedFile(file, dst); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": fmt.Sprintf("保存文件 %s 失败: %v", filename, err),
			})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message": fmt.Sprintf("模块 '%s' 的数据和 %d 个图片文件已成功备份。", moduleName, len(files)),
		"data":    jsonData,
	})
}
