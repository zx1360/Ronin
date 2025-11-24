package data

import (
	"fmt"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

// SyncData 处理 GET 请求，用于同步指定模块的数据
// 它会读取该模块配置的 JSON 文件并返回其内容
func SyncData(c *gin.Context) {
	moduleName := c.Param("module_name")

	config, exists := GetModuleConfig(moduleName)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("模块 '%s' 不存在", moduleName)})
		return
	}

	// 检查 JSON 文件是否存在
	if _, err := os.Stat(config.JSONPath); os.IsNotExist(err) {
		c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("模块 '%s' 的数据文件不存在", moduleName)})
		return
	}

	// 读取并返回 JSON 文件内容
	c.File(config.JSONPath)
}
