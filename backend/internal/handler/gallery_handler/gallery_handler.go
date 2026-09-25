package gallery_handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/repository/gallery_repo"
)
// ============ 视频取帧（供 Android 剪辑页拖动滑块时实时预览帧画面） ============

// frameCacheKey 取帧缓存键：assetID|取整到 0.05s 的秒数
type frameCacheKey struct {
	assetID uuid.UUID
	sec     int64
}

// frameCache 简单的 LRU 取帧缓存（FIFO 淘汰），避免拖动滑块时重复调用 ffmpeg
var (
	frameCacheMu    sync.Mutex
	frameCache      = make(map[frameCacheKey][]byte)
	frameCacheOrder []frameCacheKey
)

const (
	frameCacheMax = 64 // 缓存帧数上限（约几十 MB 级别，自用足够）
	frameSecStep  = 50 // 缓存键按 50ms 取整，拖动抖动不击穿缓存
)

// VideoInfo 视频信息响应（/API/gallery/:id/video-info）
type VideoInfo struct {
	DurationMs int64 `json:"duration_ms"`
	Width      int   `json:"width"`
	Height     int   `json:"height"`
}

// videoInfoCache 视频信息缓存（键: assetID）
var (
	videoInfoCacheMu sync.Mutex
	videoInfoCache   = make(map[uuid.UUID]VideoInfo)
)

// probeVideoInfo 用 ffprobe 探测视频时长与分辨率（带缓存）
func probeVideoInfo(assetID uuid.UUID, srcPath string) (VideoInfo, error) {
	videoInfoCacheMu.Lock()
	if info, ok := videoInfoCache[assetID]; ok {
		videoInfoCacheMu.Unlock()
		return info, nil
	}
	videoInfoCacheMu.Unlock()

	ffprobePath := "ffprobe"
	if _, err := exec.LookPath(ffprobePath); err != nil {
		return VideoInfo{}, fmt.Errorf("ffprobe 不可用: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, ffprobePath,
		"-v", "error",
		"-show_entries", "format=duration:stream=width,height",
		"-of", "json",
		srcPath,
	)
	out, err := cmd.Output()
	if err != nil {
		return VideoInfo{}, fmt.Errorf("ffprobe 失败: %w", err)
	}

	var parsed struct {
		Format struct {
			Duration string `json:"duration"`
		} `json:"format"`
		Streams []struct {
			Width  int    `json:"width"`
			Height int    `json:"height"`
			Codec  string `json:"codec_type"`
		} `json:"streams"`
	}
	if err := json.Unmarshal(out, &parsed); err != nil {
		return VideoInfo{}, fmt.Errorf("解析 ffprobe 输出失败: %w", err)
	}

	durSec, _ := strconv.ParseFloat(parsed.Format.Duration, 64)
	info := VideoInfo{DurationMs: int64(durSec * 1000)}
	for _, s := range parsed.Streams {
		if s.Codec == "video" {
			info.Width = s.Width
			info.Height = s.Height
			break
		}
	}

	videoInfoCacheMu.Lock()
	videoInfoCache[assetID] = info
	videoInfoCacheMu.Unlock()

	return info, nil
}

// extractVideoFrame 用 ffmpeg 提取视频指定秒数的帧（JPEG），带 LRU 缓存。
// `-ss` 置于 `-i` 前做输入侧快进，再解码到目标位置输出单帧：又快又准。
func extractVideoFrame(assetID uuid.UUID, srcPath string, sec float64) ([]byte, error) {
	if sec < 0 {
		sec = 0
	}
	key := frameCacheKey{assetID: assetID, sec: int64(sec * 1000 / frameSecStep)}

	frameCacheMu.Lock()
	if data, ok := frameCache[key]; ok {
		frameCacheMu.Unlock()
		return data, nil
	}
	frameCacheMu.Unlock()

	// 检查 ffmpeg 可用性
	ffmpegPath := "ffmpeg"
	if _, err := exec.LookPath(ffmpegPath); err != nil {
		return nil, fmt.Errorf("ffmpeg 不可用: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, ffmpegPath,
		"-ss", strconv.FormatFloat(sec, 'f', 2, 64),
		"-i", srcPath,
		"-frames:v", "1",
		"-q:v", "3",
		"-f", "image2pipe",
		"-vcodec", "mjpeg",
		"-",
	)
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("ffmpeg 提取帧失败: %w", err)
	}
	if out.Len() == 0 {
		return nil, fmt.Errorf("ffmpeg 未生成帧数据")
	}

	data := out.Bytes()

	// 写入缓存（FIFO 淘汰）
	frameCacheMu.Lock()
	if len(frameCache) >= frameCacheMax {
		if len(frameCacheOrder) > 0 {
			delete(frameCache, frameCacheOrder[0])
			frameCacheOrder = frameCacheOrder[1:]
		}
	}
	frameCache[key] = data
	frameCacheOrder = append(frameCacheOrder, key)
	frameCacheMu.Unlock()

	return data, nil
}

// FetchBatch 处理 GET /api/gallery/batch 请求
// 响应指定数量的媒体资产 + 全量标签 + 对应的标签关联关系
// 支持筛选: mime_type, year, month, day
// 支持排序: sort_by, sort_order, secondary_sort
// @Summary 分页获取媒体批次数据
// @Description 返回媒体资产、全量标签及媒体标签关联
// @Tags gallery
// @Produce json
// @Security ApiKeyAuth
// @Param limit query int false "返回条数（默认 200，最大 10000）"
// @Param offset query int false "偏移量（默认 0）"
// @Param mime_type query string false "MIME类型筛选: image, video, image/jpeg 等"
// @Param sort_by query string false "排序字段: sync_count, captured_at, size_bytes, file_path"
// @Param sort_order query string false "排序方向: asc, desc"
// @Param year query int false "筛选年份"
// @Param month query int false "筛选月份 (需同时指定year)"
// @Param day query int false "筛选日期 (需同时指定year, month)"
// @Success 200 {object} model.BatchData
// @Failure 500 {object} map[string]string
// @Router /api/gallery/batch [get]
func FetchBatch(c *gin.Context) {
	var params model.BatchQueryParams
	if err := c.ShouldBindQuery(&params); err != nil {
		// 解析失败则使用默认值
		params = model.BatchQueryParams{Limit: 200, Offset: 0}
	}

	// 设置默认值
	if params.Limit <= 0 {
		params.Limit = 200
	}
	if params.Limit > 10000 {
		params.Limit = 10000
	}
	if params.Offset < 0 {
		params.Offset = 0
	}

	// 查询媒体资产
	mediaAssets, err := gallery_repo.FetchMediaAssetsWithParams(params)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询媒体资产失败: " + err.Error()})
		return
	}

	// 查询全量标签
	tags, err := gallery_repo.FetchAllTags()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询标签失败: " + err.Error()})
		return
	}

	// 获取媒体 ID 列表
	mediaIDs := make([]uuid.UUID, len(mediaAssets))
	for i, asset := range mediaAssets {
		mediaIDs[i] = asset.ID
	}

	// 查询对应的标签关联
	mediaTagLinks, err := gallery_repo.FetchMediaTagLinks(mediaIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询标签关联失败: " + err.Error()})
		return
	}

	response := model.BatchData{
		MediaAssets:   mediaAssets,
		Tags:          tags,
		MediaTagLinks: mediaTagLinks,
	}

	c.JSON(http.StatusOK, response)
}

// FetchAllTags 处理 GET /api/gallery/tags 请求
// 响应完整的标签树
// @Summary 获取完整标签树
// @Tags gallery
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} model.TagsResponse
// @Failure 500 {object} map[string]string
// @Router /api/gallery/tags [get]
func FetchAllTags(c *gin.Context) {
	tags, err := gallery_repo.FetchAllTags()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询标签失败: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"tags": tags})
}

// FetchOverview 处理 GET /api/gallery/overview 请求
// 返回服务端媒体库总览统计数据
// @Summary 获取画廊总览统计
// @Description 返回媒体类型分布、标签统计、同步统计、年份分布等
// @Tags gallery
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} model.GalleryOverview
// @Failure 500 {object} map[string]string
// @Router /api/gallery/overview [get]
func FetchOverview(c *gin.Context) {
	overview, err := gallery_repo.FetchGalleryOverview()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询总览失败: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, overview)
}

// DownloadFile 处理文件下载请求（通用）
func downloadFile(c *gin.Context, filePath string) {
	// 检查文件是否存在
	if _, err := os.Stat(filePath); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "文件不存在"})
		return
	}

	// 使用 c.File 下载文件
	c.File(filePath)
}

// @Summary 下载媒体原图/缩略图/预览图
// @Tags gallery
// @Produce application/octet-stream
// @Security ApiKeyAuth
// @Param id path string true "媒体ID (UUID)"
// @Param type path string true "文件类型: file | thumb | preview"
// @Success 200 {file} file
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/gallery/{id}/{type} [get]
func FetchMediaAsset(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 ID 格式"})
		return
	}
	typeStr := c.Param("type")

	asset, err := gallery_repo.FetchMediaAssetByID(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询媒体资产失败: " + err.Error()})
		return
	}

	if asset == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "媒体资产不存在"})
		return
	}

	// 构造完整文件路径
	var filePath string
	switch typeStr {
	case "file":
		filePath = filepath.Join(config.AppConf.GalleryDir, "Media", asset.FilePath)
	case "thumb":
		if asset.ThumbPath == nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "缩略图不存在"})
			return
		}
		filePath = filepath.Join(config.AppConf.GalleryDir, "Thumbs", *asset.ThumbPath)
	case "preview":
		if asset.PreviewPath == nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "预览图不存在"})
			return
		}
		filePath = filepath.Join(config.AppConf.GalleryDir, "Preview", *asset.PreviewPath)
	case "frame":
		// 视频取帧：?sec=秒数，返回该位置一帧 JPEG（Android 剪辑页拖动预览用）
		if !isVideoAsset(asset) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "非视频资产"})
			return
		}
		sec := 0.0
		if raw := c.Query("sec"); raw != "" {
			if v, err := strconv.ParseFloat(raw, 64); err == nil {
				sec = v
			}
		}
		srcPath := filepath.Join(config.AppConf.GalleryDir, "Media", asset.FilePath)
		data, err := extractVideoFrame(id, srcPath, sec)
		if err != nil {
			log.Printf("gallery 取帧失败 [%s @%.1fs]: %v", asset.FilePath, sec, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "提取视频帧失败: " + err.Error()})
			return
		}
		c.Header("Cache-Control", "no-store")
		c.Data(http.StatusOK, "image/jpeg", data)
		return
	case "video-info":
		// 视频信息：时长/宽高（Android 剪辑页初始化用，避免引入视频播放器）
		if !isVideoAsset(asset) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "非视频资产"})
			return
		}
		srcPath := filepath.Join(config.AppConf.GalleryDir, "Media", asset.FilePath)
		info, err := probeVideoInfo(id, srcPath)
		if err != nil {
			log.Printf("gallery 探测视频信息失败 [%s]: %v", asset.FilePath, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "探测视频信息失败: " + err.Error()})
			return
		}
		c.JSON(http.StatusOK, info)
		return
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的类型参数"})
		return
	}
	downloadFile(c, filePath)
}

// isVideoAsset 根据 MIME 或扩展名判断是否为视频资产
func isVideoAsset(asset *model.MediaAsset) bool {
	if asset.MimeType != nil {
		if len(*asset.MimeType) >= 6 && (*asset.MimeType)[:6] == "video/" {
			return true
		}
	}
	ext := strings.ToLower(filepath.Ext(asset.FilePath))
	switch ext {
	case ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".flv", ".webm", ".m4v", ".3gp", ".ts":
		return true
	}
	return false
}

// ============ 标签与媒体标注操作（服务端权威，客户端"操作式写入"） ============

// respondRepoError 将仓库层业务错误映射为对应 HTTP 状态码
func respondRepoError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, gallery_repo.ErrTagNotFound),
		errors.Is(err, gallery_repo.ErrMediaNotFound):
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
	case errors.Is(err, gallery_repo.ErrTagNameConflict):
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	case errors.Is(err, gallery_repo.ErrTagParentNotFound),
		errors.Is(err, gallery_repo.ErrTagCycle),
		errors.Is(err, gallery_repo.ErrTagEmptyName),
		errors.Is(err, gallery_repo.ErrMediaSelfGroup):
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	}
}

// parseUUIDParam 解析路径参数中的 UUID
func parseUUIDParam(c *gin.Context, name string) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param(name))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 ID 格式"})
		return uuid.Nil, false
	}
	return id, true
}

// CreateTag 处理 POST /api/gallery/tags
// @Summary 新建标签
// @Tags gallery
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param body body model.TagCreateRequest true "标签信息"
// @Success 201 {object} map[string]model.Tag
// @Failure 400 {object} map[string]string
// @Failure 409 {object} map[string]string
// @Router /api/gallery/tags [post]
func CreateTag(c *gin.Context) {
	var req model.TagCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式错误: " + err.Error()})
		return
	}
	tag, err := gallery_repo.CreateTag(req.Name, req.ParentID)
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"tag": tag})
}

// UpdateTag 处理 PUT /api/gallery/tags/:id
// @Summary 更新标签（改名/移动/收藏）
// @Description 字段缺省表示不修改；parent_id 显式传 null 表示移动到根级
// @Tags gallery
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param id path string true "标签 ID"
// @Param body body model.TagUpdateRequest true "更新内容"
// @Success 200 {object} map[string]model.Tag
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 409 {object} map[string]string
// @Router /api/gallery/tags/{id} [put]
func UpdateTag(c *gin.Context) {
	id, ok := parseUUIDParam(c, "id")
	if !ok {
		return
	}
	var req model.TagUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式错误: " + err.Error()})
		return
	}

	patch := gallery_repo.TagPatch{Name: req.Name, IsFavorite: req.IsFavorite}
	if len(req.ParentID) > 0 {
		if strings.TrimSpace(string(req.ParentID)) == "null" {
			patch.MoveToRoot = true
		} else {
			var parentID uuid.UUID
			if err := json.Unmarshal(req.ParentID, &parentID); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "parent_id 格式错误"})
				return
			}
			patch.ParentID = &parentID
		}
	}

	tag, err := gallery_repo.UpdateTag(id, patch)
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"tag": tag})
}

// DeleteTag 处理 DELETE /api/gallery/tags/:id
// @Summary 删除标签（级联删除子孙与标签关联）
// @Tags gallery
// @Produce json
// @Security ApiKeyAuth
// @Param id path string true "标签 ID"
// @Success 200 {object} model.TagDeleteResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Router /api/gallery/tags/{id} [delete]
func DeleteTag(c *gin.Context) {
	id, ok := parseUUIDParam(c, "id")
	if !ok {
		return
	}
	deleted, err := gallery_repo.DeleteTag(id)
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, model.TagDeleteResponse{DeletedIDs: deleted})
}

// QueryMedia 处理 GET /api/gallery/media
// @Summary 按标签/类型/删除状态查询媒体及其标签关联
// @Tags gallery
// @Produce json
// @Security ApiKeyAuth
// @Param tag_ids query string false "标签 ID, 逗号分隔（任一命中）"
// @Param include_descendants query bool false "标签筛选是否包含子孙标签"
// @Param untagged query bool false "仅未打标签的媒体"
// @Param include_deleted query bool false "包含已软删除媒体"
// @Param mime_type query string false "image / video / image/jpeg"
// @Param ids query string false "指定媒体 ID, 逗号分隔"
// @Param sort_by query string false "captured_at(默认)/sync_count/size_bytes/file_path"
// @Param sort_order query string false "desc(默认)/asc"
// @Param limit query int false "默认 60, 上限 1000"
// @Param offset query int false "偏移量"
// @Success 200 {object} model.MediaQueryResponse
// @Failure 400 {object} map[string]string
// @Router /api/gallery/media [get]
func QueryMedia(c *gin.Context) {
	var params model.MediaQueryParams
	if err := c.ShouldBindQuery(&params); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "查询参数格式错误: " + err.Error()})
		return
	}
	if err := validateUUIDList(params.TagIDs, "tag_ids"); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := validateUUIDList(params.IDs, "ids"); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if params.SortBy != "" && !isValidMediaSort(params.SortBy) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "不支持的 sort_by: " + params.SortBy})
		return
	}
	if params.Limit <= 0 {
		params.Limit = 60
	}
	if params.Limit > 1000 {
		params.Limit = 1000
	}
	if params.Offset < 0 {
		params.Offset = 0
	}

	assets, links, total, err := gallery_repo.FetchMediaAssetsByQuery(params)
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, model.MediaQueryResponse{
		MediaAssets:   assets,
		MediaTagLinks: links,
		Total:         total,
	})
}

// SetMediaTags 处理 PUT /api/gallery/media/:id/tags
// @Summary 全量替换单个媒体的标签集合（幂等）
// @Tags gallery
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param id path string true "媒体 ID"
// @Param body body model.MediaTagsRequest true "标签集合"
// @Success 200 {object} model.MediaTagsResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Router /api/gallery/media/{id}/tags [put]
func SetMediaTags(c *gin.Context) {
	id, ok := parseUUIDParam(c, "id")
	if !ok {
		return
	}
	var req model.MediaTagsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式错误: " + err.Error()})
		return
	}

	applied, err := gallery_repo.ReplaceMediaTags(id, req.TagIDs)
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, model.MediaTagsResponse{MediaID: id, TagIDs: applied})
}

// BatchMediaTags 处理 POST /api/gallery/media/tags
// @Summary 批量为多个媒体增删标签（幂等）
// @Tags gallery
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param body body model.MediaTagsBatchRequest true "增删内容"
// @Success 200 {object} map[string]int64
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Router /api/gallery/media/tags [post]
func BatchMediaTags(c *gin.Context) {
	var req model.MediaTagsBatchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式错误: " + err.Error()})
		return
	}
	if len(req.MediaIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "media_ids 不能为空"})
		return
	}
	if len(req.AddTagIDs) == 0 && len(req.RemoveTagIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "add_tag_ids 与 remove_tag_ids 不能同时为空"})
		return
	}

	affected, err := gallery_repo.AddRemoveMediaTags(req.MediaIDs, req.AddTagIDs, req.RemoveTagIDs)
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"affected": affected})
}

// PatchMedia 处理 PATCH /api/gallery/media
// @Summary 更新媒体标注（软删除/备注/捆绑/编辑参数/处理游标）
// @Description 字段缺省表示不修改；message 空串表示清空；
//
//	group_id 传 null 表示解绑；edit_params 传 null 表示清除
//
// @Tags gallery
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param body body model.MediaPatchRequest true "更新内容"
// @Success 200 {object} model.MediaPatchResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Router /api/gallery/media [patch]
func PatchMedia(c *gin.Context) {
	var req model.MediaPatchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式错误: " + err.Error()})
		return
	}
	if len(req.MediaIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "media_ids 不能为空"})
		return
	}

	patch := gallery_repo.MediaPatch{
		MediaIDs:      req.MediaIDs,
		IsDeleted:     req.IsDeleted,
		Message:       req.Message,
		MarkProcessed: req.MarkProcessed,
	}

	if len(req.GroupID) > 0 {
		if strings.TrimSpace(string(req.GroupID)) == "null" {
			patch.ClearGroup = true
		} else {
			var groupID uuid.UUID
			if err := json.Unmarshal(req.GroupID, &groupID); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "group_id 格式错误"})
				return
			}
			patch.GroupID = &groupID
		}
	}

	if len(req.EditParams) > 0 {
		raw := strings.TrimSpace(string(req.EditParams))
		if raw == "null" {
			patch.ClearEditParams = true
		} else {
			text, err := normalizeJSONText(raw)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "edit_params 格式错误: " + err.Error()})
				return
			}
			if text == "" {
				patch.ClearEditParams = true
			} else {
				patch.SetEditParams = &text
			}
		}
	}

	assets, err := gallery_repo.PatchMediaAssets(patch)
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, model.MediaPatchResponse{MediaAssets: assets})
}

// normalizeJSONText 归一化 edit_params 取值：同时接受 JSON 字符串与 JSON 对象/数组文本
func normalizeJSONText(raw string) (string, error) {
	var asString string
	if err := json.Unmarshal([]byte(raw), &asString); err == nil {
		text := strings.TrimSpace(asString)
		if text == "" {
			return "", nil
		}
		if !json.Valid([]byte(text)) {
			return "", fmt.Errorf("不是合法 JSON")
		}
		return text, nil
	}
	if !json.Valid([]byte(raw)) {
		return "", fmt.Errorf("不是合法 JSON")
	}
	return raw, nil
}

// validateUUIDList 校验逗号分隔的 UUID 列表（空串合法）
func validateUUIDList(raw, field string) error {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		if _, err := uuid.Parse(part); err != nil {
			return fmt.Errorf("%s 含非法 UUID: %s", field, part)
		}
	}
	return nil
}

// isValidMediaSort 校验媒体列表排序字段
func isValidMediaSort(field string) bool {
	switch field {
	case "captured_at", "sync_count", "size_bytes", "file_path":
		return true
	}
	return false
}
