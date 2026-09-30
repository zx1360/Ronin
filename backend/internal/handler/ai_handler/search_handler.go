package ai_handler

import (
	"context"
	"errors"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"monarch/internal/repository/ai_repo"
	"monarch/internal/service/ai"
)

// Search 处理 GET /API/ai/search
//
// 参数：q 文本查询；mode=auto|semantic|keyword|filename；tag_ids / include_descendants /
// person_ids / vlm_tags / mime_type / from / to 结构化筛选；limit / offset 分页。
func Search(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}

	req, err := buildSearchRequest(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Minute)
	defer cancel()

	result, err := e.Search(ctx, req)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, result)
}

// SearchByImage 处理 POST /API/ai/search/image（multipart 表单字段 image）。
func SearchByImage(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}

	fileHeader, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少上传文件字段 image"})
		return
	}

	temp, err := os.CreateTemp("", "ai_query_*.img")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建临时文件失败: " + err.Error()})
		return
	}
	tempPath := temp.Name()
	temp.Close()
	defer os.Remove(tempPath)

	if err := c.SaveUploadedFile(fileHeader, tempPath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存上传文件失败: " + err.Error()})
		return
	}

	req, err := buildSearchRequest(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Minute)
	defer cancel()

	result, err := e.SearchByImageBytes(ctx, tempPath, req)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, result)
}

// Similar 处理 GET /API/ai/similar/:id：以图搜图（库内已有媒体）。
func Similar(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	id, ok := pathUUID(c, "id", "媒体 ID ")
	if !ok {
		return
	}
	result, err := e.SimilarMedia(id, queryInt(c, "limit", 40, 1, 200))
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, result)
}

// MediaDetail 处理 GET /API/ai/media/:id：单个媒体的 AI 结果。
func MediaDetail(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	id, ok := pathUUID(c, "id", "媒体 ID ")
	if !ok {
		return
	}
	detail, err := ai_repo.GetMediaDetail(id)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, detail)
}

// ListVLMTags 处理 GET /API/ai/tags：AI 标签清单（只读，与人工标签无关）。
func ListVLMTags(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	tags, err := ai_repo.ListVLMTags(queryInt(c, "limit", 500, 1, 2000))
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"tags": tags, "total": len(tags)})
}

func buildSearchRequest(c *gin.Context) (ai.SearchRequest, error) {
	req := ai.SearchRequest{
		Query:              strings.TrimSpace(c.Query("q")),
		Mode:               strings.TrimSpace(c.Query("mode")),
		MediaID:            strings.TrimSpace(c.Query("media_id")),
		IncludeDescendants: c.Query("include_descendants") == "true",
		MimeType:           strings.TrimSpace(c.Query("mime_type")),
		SortBy:             strings.TrimSpace(c.Query("sort_by")),
		SortOrder:          strings.TrimSpace(c.Query("sort_order")),
		Limit:              queryInt(c, "limit", 60, 1, 200),
		Offset:             queryInt(c, "offset", 0, 0, 1<<30),
	}
	if raw := strings.TrimSpace(c.Query("min_score")); raw != "" {
		value, err := strconv.ParseFloat(raw, 32)
		if err != nil {
			return req, errors.New("min_score 非法")
		}
		req.MinScore = float32(value)
	}
	// ID 列表在这里就校验：非法输入属于客户端错误（400），
	// 交给服务层报错会被统一映射成 500，掩盖真正的原因。
	tagIDs, err := parseUUIDParams(c, "tag_ids")
	if err != nil {
		return req, err
	}
	req.TagIDs = tagIDs
	personIDs, err := parseUUIDParams(c, "person_ids")
	if err != nil {
		return req, err
	}
	req.PersonIDs = personIDs
	for _, raw := range ai_repo.SplitAndTrim(c.Query("vlm_tags")) {
		req.VLMTags = append(req.VLMTags, raw)
	}
	from, err := parseOptionalTime(c, "from")
	if err != nil {
		return req, err
	}
	req.From = from
	to, err := parseOptionalTime(c, "to")
	if err != nil {
		return req, err
	}
	req.To = to
	return req, nil
}

func parseTime(raw string) (time.Time, error) {
	for _, layout := range []string{time.RFC3339, "2006-01-02", "2006-01-02 15:04:05"} {
		if parsed, err := time.Parse(layout, raw); err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, errors.New("无法解析时间")
}

// parseUUIDParams 解析逗号分隔的 UUID 查询参数；任一非法即报错（供 400 回写）。
func parseUUIDParams(c *gin.Context, key string) ([]string, error) {
	values := ai_repo.SplitAndTrim(c.Query(key))
	for _, raw := range values {
		if _, err := uuid.Parse(raw); err != nil {
			return nil, errors.New(key + " 含非法 ID: " + raw)
		}
	}
	return values, nil
}

// parseOptionalTime 解析可选的 from/to 时间参数；未提供时返回 nil。
func parseOptionalTime(c *gin.Context, key string) (*time.Time, error) {
	raw := strings.TrimSpace(c.Query(key))
	if raw == "" {
		return nil, nil
	}
	parsed, err := parseTime(raw)
	if err != nil {
		return nil, errors.New(key + " 时间格式非法")
	}
	return &parsed, nil
}
