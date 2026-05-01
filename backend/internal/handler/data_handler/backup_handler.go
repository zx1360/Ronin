package data_handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

// BackupHandler 处理指定模块的数据备份请求
// 接收 multipart/form-data 格式请求，包含 JSON 数据和图片文件，覆盖保存到对应路径
// @Summary 备份指定模块的数据
// @Description 接收模块 JSON 数据与图片文件并覆盖保存到服务器目录
// @Tags user-data
// @Accept mpfd
// @Produce json
// @Security ApiKeyAuth
// @Param module path string true "模块名称"
// @Param jsonData formData string true "JSON 字段集合，键名对应目标文件名（不含扩展名）"
// @Param files formData file false "待上传的图片文件（可多文件）"
// @Success 200 {object} map[string]string
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/user-data/backup/{module} [post]
func BackupHandler(c *gin.Context) {
	// 1. 获取 URL 路径中的模块名参数
	moduleName := c.Param("module")

	// 2. 根据模块名查找配置，未找到则返回 404
	moduleConfig := FindModuleConfigByName(moduleName)
	if moduleConfig == nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error":  "模块未找到",
			"module": moduleName,
		})
		return
	}

	// 3. 解析 multipart/form-data 表单（限制最大 10MB）
	if err := c.Request.ParseMultipartForm(10 << 20); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":  "解析表单数据失败",
			"detail": err.Error(),
		})
		return
	}

	// 4. 获取表单中的 jsonData 字段，缺失则返回 400
	jsonDataStr, exists := c.GetPostForm("jsonData")
	if !exists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 required 字段: jsonData"})
		return
	}

	// 5. 解析 jsonData 为 map 结构，格式错误则返回 400
	var jsonData map[string]json.RawMessage
	if err := json.Unmarshal([]byte(jsonDataStr), &jsonData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":  "jsonData 格式无效",
			"detail": err.Error(),
		})
		return
	}

	// 6. 遍历模块配置的 JSON 文件路径，逐一保存数据
	for _, filePath := range moduleConfig.JSONFiles {
		// 从文件名提取 JSON 数据的 key（去除文件扩展名）
		fileName := filepath.Base(filePath)
		key := fileName[:len(fileName)-len(filepath.Ext(fileName))]

		// 若 JSON 中无对应 key，跳过当前文件（不报错，仅忽略）
		rawData, exists := jsonData[key]
		if !exists {
			continue
		}

		// 确保文件所在目录存在，不存在则创建
		dirPath := filepath.Dir(filePath)
		if err := os.MkdirAll(dirPath, os.ModePerm); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":  "创建 JSON 文件目录失败",
				"detail": err.Error(),
			})
			return
		}

		// 写入原始 JSON 数据（覆盖现有文件）
		if err := os.WriteFile(filePath, rawData, 0644); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":  "写入 JSON 文件失败",
				"file":   filePath,
				"detail": err.Error(),
			})
			return
		}
	}

	// 7. 处理上传的图片文件（若有）
	form, err := c.MultipartForm()
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":  "获取上传文件列表失败",
			"detail": err.Error(),
		})
		return
	}

	// 遍历图片文件并保存到模块的图片目录
	files := form.File["files"]
	if len(files) > 0 {
		// 确保图片目录存在
		if err := os.MkdirAll(moduleConfig.ImageDir, os.ModePerm); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":  "创建图片目录失败",
				"detail": err.Error(),
			})
			return
		}

		// 逐个保存图片文件（覆盖同名文件）
		for _, file := range files {
			dstPath := filepath.Join(moduleConfig.ImageDir, file.Filename)
			if err := c.SaveUploadedFile(file, dstPath); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{
					"error":  "保存图片文件失败",
					"file":   file.Filename,
					"detail": err.Error(),
				})
				return
			}
		}
	}

	// 8. 备份成功，返回 200 响应
	c.JSON(http.StatusOK, gin.H{
		"status":  "success",
		"message": fmt.Sprintf("模块 %s 备份完成", moduleName),
	})
}
