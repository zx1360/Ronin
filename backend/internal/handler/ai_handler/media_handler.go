package ai_handler

import (
	"context"
	"errors"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/service/ai"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

// Search 处理 GET /API/ai/search
//
// 参数：q 文本查询；mode=auto|semantic|keyword|filename；tag_ids / include_descendants /
// person_ids / vlm_tags / mime_type / from / to / include_deleted 结构化筛选；limit / offset 分页。
// filename_only=true 限定文件名。semantic_limit 限定向量候选数，先取相关候选再按 sort_by 排序。
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
	result, err := e.SimilarMedia(c.Request.Context(), id, queryInt(c, "limit", 40, 1, 200))
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

// Duplicates 处理 GET /API/ai/duplicates：基于 pHash 的近重复分组。
func Duplicates(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	groups, err := e.Index().DuplicateGroups(queryInt(c, "max_distance", 4, 1, 4),
		queryInt(c, "min_group", 2, 2, 100))
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"groups":        groups,
		"total":         len(groups),
		"ignored_total": e.Index().IgnoreCount(),
	})
}

// duplicateIgnoreRequest 标记/取消"非重复"的请求体。
type duplicateIgnoreRequest struct {
	MediaIDs []string `json:"media_ids"`
}

// IgnoreDuplicates 处理 POST /API/ai/duplicates/ignore：把选中媒体标记为"非重复"。
//
// 语义是"人工否决"：这些媒体之后的近重复分组中不再出现，随时可恢复。
func IgnoreDuplicates(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	ids, ok := parseMediaIDBody(c)
	if !ok {
		return
	}
	n, err := ai_repo.IgnoreDuplicates(ids)
	if err != nil {
		fail(c, err)
		return
	}
	e.Index().InvalidateIgnores()
	if err := e.Index().EnsureIgnores(); err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"ignored": n, "total": e.Index().IgnoreCount()})
}

// UnignoreDuplicates 处理 POST /API/ai/duplicates/unignore：恢复被标记的媒体。
func UnignoreDuplicates(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	ids, ok := parseMediaIDBody(c)
	if !ok {
		return
	}
	n, err := ai_repo.UnignoreDuplicates(ids)
	if err != nil {
		fail(c, err)
		return
	}
	e.Index().InvalidateIgnores()
	if err := e.Index().EnsureIgnores(); err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"restored": n, "total": e.Index().IgnoreCount()})
}

// ListIgnoredDuplicates 处理 GET /API/ai/duplicates/ignored：已标记"非重复"的媒体。
func ListIgnoredDuplicates(c *gin.Context) {
	e := engine(c)
	if e == nil || !schemaGuard(c) {
		return
	}
	assets, err := e.IgnoredDuplicates()
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"media_assets": assets, "total": len(assets)})
}

// parseMediaIDBody 解析请求体中的 media_ids 并校验为合法 UUID；失败时已写回响应。
func parseMediaIDBody(c *gin.Context) ([]uuid.UUID, bool) {
	var req duplicateIgnoreRequest
	if !bindJSON(c, &req) {
		return nil, false
	}
	if len(req.MediaIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "media_ids 不能为空"})
		return nil, false
	}
	return bodyUUIDs(c, "media_ids", req.MediaIDs)
}

// ListVLMTags 处理 GET /API/ai/tags：AI 标签清单（只读，与人工标签无关）。
func ListVLMTags(c *gin.Context) {
	if !schemaGuard(c) {
		return
	}
	tags, err := ai_repo.ListVLMTags(c.Request.Context(), queryInt(c, "limit", 500, 1, 2000))
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
		FilenameOnly:       c.Query("filename_only") == "true",
		MediaID:            strings.TrimSpace(c.Query("media_id")),
		IncludeDescendants: c.Query("include_descendants") == "true",
		IncludeDeleted:     c.Query("include_deleted") == "true",
		MimeType:           strings.TrimSpace(c.Query("mime_type")),
		SortBy:             strings.TrimSpace(c.Query("sort_by")),
		SortOrder:          strings.TrimSpace(c.Query("sort_order")),
		Limit:              queryInt(c, "limit", 60, 1, 200),
		Offset:             queryInt(c, "offset", 0, 0, 1<<30),
		SemanticLimit:      queryInt(c, "semantic_limit", 0, 0, 2000),
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
	req.VLMTags = append(req.VLMTags, ai_repo.SplitAndTrim(c.Query("vlm_tags"))...)
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

// parseTime 解析带时区的 RFC3339 或不带时区的本机时间。
//
// 时间戳按本机本地时区存库（见 AGENTS_DB.md）；不带时区的写法必须按本地解析，
// 否则 `2024-05-31` 会被当成 UTC 零点，在 UTC+8 下整体偏移 8 小时。
func parseTime(raw string) (time.Time, error) {
	if parsed, err := time.Parse(time.RFC3339, raw); err == nil {
		return parsed, nil
	}
	for _, layout := range []string{"2006-01-02 15:04:05", "2006-01-02T15:04:05"} {
		if parsed, err := time.ParseInLocation(layout, raw, time.Local); err == nil {
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
//
// 只写日期（界面上的日期选择器）时按本地日历日解释，且 to 取该日末尾：
// 否则"到 5 月 31 日"会把 5 月 31 日整天排除在外。
func parseOptionalTime(c *gin.Context, key string) (*time.Time, error) {
	raw := strings.TrimSpace(c.Query(key))
	if raw == "" {
		return nil, nil
	}
	if parsed, err := time.ParseInLocation("2006-01-02", raw, time.Local); err == nil {
		if key == "to" {
			parsed = parsed.AddDate(0, 0, 1).Add(-time.Millisecond)
		}
		return &parsed, nil
	}
	parsed, err := parseTime(raw)
	if err != nil {
		return nil, errors.New(key + " 时间格式非法")
	}
	return &parsed, nil
}
