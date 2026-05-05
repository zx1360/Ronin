package data_handler

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"

	"monarch/internal/repository/data_repo"

	"github.com/gin-gonic/gin"
)

// SyncHandler 处理数据同步请求
// @Summary 同步指定模块的数据
// @Description 读取指定模块的所有数据（DB 表或 JSON 文件），合并后返回
// @Tags user-data
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param module path string true "模块名称"
// @Success 200 {object} map[string]interface{} "成功返回合并后的JSON数据"
// @Failure 404 {object} map[string]string "模块未找到"
// @Failure 500 {object} map[string]string "服务器内部错误"
// @Router /api/user-data/sync/{module} [get]
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

// syncFromDB 从数据库读取 booklet/essay 数据并返回 JSON
func syncFromDB(c *gin.Context, moduleName string) {
	mergedData := make(map[string]interface{})

	switch moduleName {
	case "booklet":
		styles, err := data_repo.FetchAllBookletStyles()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "读取打卡样式失败: " + err.Error()})
			return
		}
		records, err := data_repo.FetchAllBookletRecords()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "读取打卡记录失败: " + err.Error()})
			return
		}

		// 将 DB 模型转为 JSON 友好格式
		stylesJSON := make([]map[string]interface{}, 0, len(styles))
		for _, s := range styles {
			stylesJSON = append(stylesJSON, toMap(s))
		}
		recordsJSON := make([]map[string]interface{}, 0, len(records))
		for _, r := range records {
			recordsJSON = append(recordsJSON, toMap(r))
		}

		mergedData["styles"] = stylesJSON
		mergedData["records"] = recordsJSON

	case "essay":
		articles, err := data_repo.FetchAllEssayArticles()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "读取随笔失败: " + err.Error()})
			return
		}
		labels, err := data_repo.FetchAllEssayLabels()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "读取标签失败: " + err.Error()})
			return
		}
		summaries, err := data_repo.FetchAllEssayYearSummaries()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "读取年度汇总失败: " + err.Error()})
			return
		}

		essaysJSON := make([]map[string]interface{}, 0, len(articles))
		for _, a := range articles {
			essaysJSON = append(essaysJSON, toMap(a))
		}
		labelsJSON := make([]map[string]interface{}, 0, len(labels))
		for _, l := range labels {
			labelsJSON = append(labelsJSON, toMap(l))
		}
		summariesJSON := make([]map[string]interface{}, 0, len(summaries))
		for _, s := range summaries {
			summariesJSON = append(summariesJSON, toMap(s))
		}

		mergedData["essays"] = essaysJSON
		mergedData["labels"] = labelsJSON
		mergedData["year_summaries"] = summariesJSON

	default:
		c.JSON(http.StatusNotFound, gin.H{"error": "不支持的 DB 模块: " + moduleName})
		return
	}

	c.JSON(http.StatusOK, mergedData)
}

// syncFromFiles 从 JSON 文件读取数据（保留原有逻辑，用于 preferences 等）
func syncFromFiles(c *gin.Context, moduleConfig *ModuleConfig) {
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

// ============================================================================
// DB 模型 → JSON Map 转换（保持与 Android 端 JSON 格式兼容）
// ============================================================================

// toMap 将任意 struct 通过 JSON 往返转换为 map[string]interface{}
// json.RawMessage 字段会正确展开为 JSON 对象/数组
func toMap(v interface{}) map[string]interface{} {
	b, _ := json.Marshal(v)
	var m map[string]interface{}
	json.Unmarshal(b, &m)
	return m
}
