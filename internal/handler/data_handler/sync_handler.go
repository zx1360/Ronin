package data_handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

// SyncHandler 处理数据同步请求
// @Summary 同步指定模块的数据
// @Description 读取指定模块的所有JSON配置文件，合并后返回
// @Tags sync
// @Accept json
// @Produce json
// @Param module path string true "模块名称"
// @Success 200 {object} map[string]interface{} "成功返回合并后的JSON数据"
// @Failure 404 {object} map[string]string "模块未找到"
// @Failure 500 {object} map[string]string "服务器内部错误"
// @Router /sync/{module} [get]
func SyncHandler(c *gin.Context) {
	moduleName := c.Param("module")
	moduleConfig := FindModuleConfigByName(moduleName)

	if moduleConfig == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "模块未找到"})
		return
	}

	// 合并所有JSON文件的内容
	mergedData := make(map[string]interface{})
	for _, filePath := range moduleConfig.JSONFiles {
		// 读取文件内容
		content, err := os.ReadFile(filePath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "读取文件失败: " + err.Error()})
			return
		}

		// 关键改动：使用 interface{} 来接收任意类型的JSON数据(否则不支持数组顶层结构)
		var data interface{}
		if err := json.Unmarshal(content, &data); err != nil {
			// 错误信息中加入文件名，方便定位问题
			c.JSON(http.StatusInternalServerError, gin.H{"error": "解析文件 " + filepath.Base(filePath) + " 失败: " + err.Error()})
			return
		}

		// 获取文件名（不带扩展名）作为键
		key := filepath.Base(filePath)
		key = key[:len(key)-len(filepath.Ext(key))] // 移除 .json

		mergedData[key] = data
	}
	for k, v := range mergedData {
		fmt.Println("Key:", k, "Value Type:", fmt.Sprintf("%T", v))
	}

	c.JSON(http.StatusOK, mergedData)
}
