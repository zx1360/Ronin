package data_handler

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"monarch/internal/model"
	"monarch/internal/repository/data_repo"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// BackupHandler 处理指定模块的数据备份请求
// 接收 multipart/form-data 格式请求，包含 JSON 数据和图片文件。
// - booklet/essay: 写入数据库 user_data schema 对应表，图片保存到 img_storage/
// - preferences: 保持 JSON 文件存储（原逻辑）
// @Summary 备份指定模块的数据
// @Description 接收模块 JSON 数据与图片文件并保存
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
	moduleName := c.Param("module")

	moduleConfig := FindModuleConfigByName(moduleName)
	if moduleConfig == nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error":  "模块未找到",
			"module": moduleName,
		})
		return
	}

	// 解析 multipart/form-data 表单（限制最大 10MB）
	if err := c.Request.ParseMultipartForm(10 << 20); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":  "解析表单数据失败",
			"detail": err.Error(),
		})
		return
	}

	// 获取表单中的 jsonData 字段
	jsonDataStr, exists := c.GetPostForm("jsonData")
	if !exists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 required 字段: jsonData"})
		return
	}

	// 解析 jsonData 为 map 结构
	var jsonData map[string]json.RawMessage
	if err := json.Unmarshal([]byte(jsonDataStr), &jsonData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":  "jsonData 格式无效",
			"detail": err.Error(),
		})
		return
	}

	// 根据模块类型分流处理
	if moduleConfig.IsDB {
		backupToDB(c, moduleName, moduleConfig, jsonData)
		return
	}

	// 原有 JSON 文件模式（preferences 等）
	backupToFiles(c, moduleConfig, jsonData)
}

// ============================================================================
// DB 模式备份 (booklet / essay)
// ============================================================================

func backupToDB(c *gin.Context, moduleName string, cfg *ModuleConfig, jsonData map[string]json.RawMessage) {
	switch moduleName {
	case "booklet":
		backupBooklet(c, cfg, jsonData)
	case "essay":
		backupEssay(c, cfg, jsonData)
	default:
		c.JSON(http.StatusNotFound, gin.H{"error": "不支持的 DB 模块: " + moduleName})
	}
}

func backupBooklet(c *gin.Context, cfg *ModuleConfig, jsonData map[string]json.RawMessage) {
	// 解析 styles
	var stylesRaw []map[string]interface{}
	if raw, ok := jsonData["styles"]; ok {
		if err := json.Unmarshal(raw, &stylesRaw); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 styles 失败: " + err.Error()})
			return
		}
	}

	// 解析 records
	var recordsRaw []map[string]interface{}
	if raw, ok := jsonData["records"]; ok {
		if err := json.Unmarshal(raw, &recordsRaw); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 records 失败: " + err.Error()})
			return
		}
	}

	// 构建 DB 模型
	styles := make([]model.BookletStyle, 0, len(stylesRaw))
	styleIDs := make([]uuid.UUID, 0, len(stylesRaw))
	for _, s := range stylesRaw {
		style, err := parseBookletStyle(s)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 style 失败: " + err.Error()})
			return
		}
		styles = append(styles, style)
		styleIDs = append(styleIDs, style.ID)
	}

	records := make([]model.BookletRecord, 0, len(recordsRaw))
	recordIDs := make([]uuid.UUID, 0, len(recordsRaw))
	for _, r := range recordsRaw {
		record, err := parseBookletRecord(r)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 record 失败: " + err.Error()})
			return
		}
		records = append(records, record)
		recordIDs = append(recordIDs, record.ID)
	}

	// 事务性替换数据
	err := data_repo.ReplaceBookletData(data_repo.BookletBackupData{
		Styles:    styles,
		Records:   records,
		StyleIDs:  styleIDs,
		RecordIDs: recordIDs,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存打卡数据失败: " + err.Error()})
		return
	}

	// 保存图片文件
	backupSaveImages(c, cfg)

	// 清理孤儿图片
	backupCleanOrphanImages(cfg, "booklet")

	c.JSON(http.StatusOK, gin.H{"status": "success", "message": "打卡数据备份完成"})
}

func backupEssay(c *gin.Context, cfg *ModuleConfig, jsonData map[string]json.RawMessage) {
	// 解析 essays
	var essaysRaw []map[string]interface{}
	if raw, ok := jsonData["essays"]; ok {
		if err := json.Unmarshal(raw, &essaysRaw); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 essays 失败: " + err.Error()})
			return
		}
	}

	// 解析 labels
	var labelsRaw []map[string]interface{}
	if raw, ok := jsonData["labels"]; ok {
		if err := json.Unmarshal(raw, &labelsRaw); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 labels 失败: " + err.Error()})
			return
		}
	}

	// 解析 year_summaries
	var summariesRaw []map[string]interface{}
	if raw, ok := jsonData["year_summaries"]; ok {
		if err := json.Unmarshal(raw, &summariesRaw); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 year_summaries 失败: " + err.Error()})
			return
		}
	}

	// 构建 DB 模型
	articles := make([]model.EssayArticle, 0, len(essaysRaw))
	articleIDs := make([]uuid.UUID, 0, len(essaysRaw))
	for _, e := range essaysRaw {
		article, err := parseEssayArticle(e)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 essay 失败: " + err.Error()})
			return
		}
		articles = append(articles, article)
		articleIDs = append(articleIDs, article.ID)
	}

	labels := make([]model.EssayLabel, 0, len(labelsRaw))
	labelIDs := make([]uuid.UUID, 0, len(labelsRaw))
	for _, l := range labelsRaw {
		label, err := parseEssayLabel(l)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 label 失败: " + err.Error()})
			return
		}
		labels = append(labels, label)
		labelIDs = append(labelIDs, label.ID)
	}

	summaries := make([]model.EssayYearSummary, 0, len(summariesRaw))
	yearIDs := make([]int, 0, len(summariesRaw))
	for _, s := range summariesRaw {
		summary, err := parseEssayYearSummary(s)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "解析 year_summary 失败: " + err.Error()})
			return
		}
		summaries = append(summaries, summary)
		yearIDs = append(yearIDs, int(summary.Year))
	}

	// 事务性替换数据
	err := data_repo.ReplaceEssayData(data_repo.EssayBackupData{
		Articles:      articles,
		Labels:        labels,
		YearSummaries: summaries,
		ArticleIDs:    articleIDs,
		LabelIDs:      labelIDs,
		YearIDs:       yearIDs,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存随笔数据失败: " + err.Error()})
		return
	}

	// 保存图片文件
	backupSaveImages(c, cfg)

	// 清理孤儿图片
	backupCleanOrphanImages(cfg, "essay")

	c.JSON(http.StatusOK, gin.H{"status": "success", "message": "随笔数据备份完成"})
}

// ============================================================================
// 图片文件处理
// ============================================================================

// backupSaveImages 保存上传的图片文件到模块图片目录
func backupSaveImages(c *gin.Context, cfg *ModuleConfig) {
	form, err := c.MultipartForm()
	if err != nil {
		return // 没有文件也算正常
	}

	files := form.File["files"]
	if len(files) == 0 {
		return
	}

	// 确保图片目录存在
	if err := os.MkdirAll(cfg.ImageDir, os.ModePerm); err != nil {
		log.Printf("创建图片目录失败: %v", err)
		return
	}

	for _, file := range files {
		dstPath := filepath.Join(cfg.ImageDir, file.Filename)
		if err := c.SaveUploadedFile(file, dstPath); err != nil {
			log.Printf("保存图片文件失败: %s: %v", file.Filename, err)
		}
	}
}

// backupCleanOrphanImages 清理图片目录中不被当前数据引用的孤儿文件
func backupCleanOrphanImages(cfg *ModuleConfig, moduleName string) {
	var refs map[string]bool
	var err error

	switch moduleName {
	case "booklet":
		refs, err = data_repo.CollectBookletReferencedImages()
	case "essay":
		refs, err = data_repo.CollectEssayReferencedImages()
	default:
		return
	}

	if err != nil {
		log.Printf("收集引用图片列表失败 (%s): %v", moduleName, err)
		return
	}

	deleted, err := data_repo.CleanOrphanImages(cfg.ImageDir, refs)
	if err != nil {
		log.Printf("清理孤儿图片失败 (%s): %v", moduleName, err)
		return
	}

	if deleted > 0 {
		log.Printf("清理孤儿图片 (%s): 删除了 %d 个文件", moduleName, deleted)
	}
}

// ============================================================================
// JSON 文件模式备份 (preferences 等，保留原逻辑)
// ============================================================================

func backupToFiles(c *gin.Context, moduleConfig *ModuleConfig, jsonData map[string]json.RawMessage) {
	for _, filePath := range moduleConfig.JSONFiles {
		fileName := filepath.Base(filePath)
		key := fileName[:len(fileName)-len(filepath.Ext(fileName))]

		rawData, exists := jsonData[key]
		if !exists {
			continue
		}

		dirPath := filepath.Dir(filePath)
		if err := os.MkdirAll(dirPath, os.ModePerm); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":  "创建 JSON 文件目录失败",
				"detail": err.Error(),
			})
			return
		}

		if err := os.WriteFile(filePath, rawData, 0644); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":  "写入 JSON 文件失败",
				"file":   filePath,
				"detail": err.Error(),
			})
			return
		}
	}

	// 处理图片文件
	backupSaveImages(c, moduleConfig)

	c.JSON(http.StatusOK, gin.H{
		"status":  "success",
		"message": fmt.Sprintf("模块 %s 备份完成", moduleConfig.Name),
	})
}

// ============================================================================
// 数据解析辅助函数
// ============================================================================

// parseFlexTime 兼容多种日期格式
func parseFlexTime(s string) (time.Time, error) {
	formats := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02T15:04:05.999999999",
		"2006-01-02T15:04:05",
		"2006-01-02 15:04:05",
		"2006-01-02",
	}
	for _, f := range formats {
		if t, err := time.Parse(f, s); err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("无法解析日期: %s", s)
}

// dateOnly 将任意时刻规整为该时刻所在日期的 UTC 零点。
// booklet 的 start_date/date 语义为"日历日期"（无时间概念），
// 规整为 UTC 零点可保证同步往返稳定，并避免旧客户端"本地时间无时区字符串"
// 被 time.Parse 当作 UTC 解析后逐次备份累积偏移的问题。
func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// getString 从 map 中安全获取字符串
func getString(m map[string]interface{}, key string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// getInt 从 map 中安全获取整数（兼容 float64 JSON 数字）
func getInt(m map[string]interface{}, key string) int {
	if v, ok := m[key]; ok {
		switch n := v.(type) {
		case float64:
			return int(n)
		case int:
			return n
		case json.Number:
			i, _ := n.Int64()
			return int(i)
		}
	}
	return 0
}

// getStringSlice 从 map 中获取字符串数组
func getStringSlice(m map[string]interface{}, key string) []string {
	if v, ok := m[key]; ok {
		if arr, ok := v.([]interface{}); ok {
			result := make([]string, 0, len(arr))
			for _, item := range arr {
				if s, ok := item.(string); ok {
					result = append(result, s)
				}
			}
			return result
		}
	}
	return []string{}
}

// getOptionalString 从 map 中获取可选字符串指针
func getOptionalString(m map[string]interface{}, key string) *string {
	if v, ok := m[key]; ok && v != nil {
		if s, ok := v.(string); ok && s != "" {
			return &s
		}
	}
	return nil
}

// toJSONRaw 将 map 值序列化为 json.RawMessage
func toJSONRaw(v interface{}) json.RawMessage {
	if v == nil {
		return json.RawMessage("[]")
	}
	b, err := json.Marshal(v)
	if err != nil {
		return json.RawMessage("[]")
	}
	return b
}

// ============================================================================
// Booklet 解析
// ============================================================================

func parseBookletStyle(m map[string]interface{}) (model.BookletStyle, error) {
	id, err := uuid.Parse(getString(m, "id"))
	if err != nil {
		return model.BookletStyle{}, fmt.Errorf("无效的 style id: %w", err)
	}

	startDate, err := parseFlexTime(getString(m, "start_date"))
	if err != nil {
		return model.BookletStyle{}, fmt.Errorf("无效的 start_date: %w", err)
	}

	return model.BookletStyle{
		ID:                 id,
		StartDate:          dateOnly(startDate),
		ValidCheckIn:       getInt(m, "valid_check_in"),
		FullyDone:          getInt(m, "fully_done"),
		LongestStreak:      getInt(m, "longest_streak"),
		LongestFullyStreak: getInt(m, "longest_fully_streak"),
		Tasks:              toJSONRaw(m["tasks"]),
	}, nil
}

func parseBookletRecord(m map[string]interface{}) (model.BookletRecord, error) {
	id, err := uuid.Parse(getString(m, "id"))
	if err != nil {
		return model.BookletRecord{}, fmt.Errorf("无效的 record id: %w", err)
	}

	styleID, err := uuid.Parse(getString(m, "style_id"))
	if err != nil {
		return model.BookletRecord{}, fmt.Errorf("无效的 style_id: %w", err)
	}

	date, err := parseFlexTime(getString(m, "date"))
	if err != nil {
		return model.BookletRecord{}, fmt.Errorf("无效的 date: %w", err)
	}

	return model.BookletRecord{
		ID:             id,
		StyleID:        styleID,
		Date:           dateOnly(date),
		Message:        getString(m, "message"),
		TaskCompletion: toJSONRaw(m["task_completion"]),
		Mood:           getOptionalString(m, "mood"),
	}, nil
}

// ============================================================================
// Essay 解析
// ============================================================================

func parseEssayArticle(m map[string]interface{}) (model.EssayArticle, error) {
	id, err := uuid.Parse(getString(m, "id"))
	if err != nil {
		return model.EssayArticle{}, fmt.Errorf("无效的 essay id: %w", err)
	}

	date, err := parseFlexTime(getString(m, "date"))
	if err != nil {
		return model.EssayArticle{}, fmt.Errorf("无效的 date: %w", err)
	}

	return model.EssayArticle{
		ID:        id,
		Date:      date,
		WordCount: getInt(m, "word_count"),
		Content:   getString(m, "content"),
		Imgs:      getStringSlice(m, "imgs"),
		Labels:    getStringSlice(m, "labels"),
		Messages:  toJSONRaw(m["messages"]),
		Mood:      getOptionalString(m, "mood"),
	}, nil
}

func parseEssayLabel(m map[string]interface{}) (model.EssayLabel, error) {
	id, err := uuid.Parse(getString(m, "id"))
	if err != nil {
		return model.EssayLabel{}, fmt.Errorf("无效的 label id: %w", err)
	}

	return model.EssayLabel{
		ID:         id,
		Name:       getString(m, "name"),
		EssayCount: getInt(m, "essay_count"),
	}, nil
}

func parseEssayYearSummary(m map[string]interface{}) (model.EssayYearSummary, error) {
	// Android 端 year 字段为 String 类型（如 "2024"），FlexYear 会自动处理
	yearRaw := m["year"]
	yearJSON, err := json.Marshal(yearRaw)
	if err != nil {
		return model.EssayYearSummary{}, fmt.Errorf("无效的 year 值")
	}

	var year model.FlexYear
	if err := year.UnmarshalJSON(yearJSON); err != nil {
		return model.EssayYearSummary{}, fmt.Errorf("无效的 year: %w", err)
	}

	return model.EssayYearSummary{
		Year:           year,
		EssayCount:     getInt(m, "essay_count"),
		WordCount:      getInt(m, "word_count"),
		MonthSummaries: toJSONRaw(m["month_summaries"]),
	}, nil
}
