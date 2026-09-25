// Package gallery_handler 提供画廊(媒体资产/标签)的 HTTP 接口。
//
// 服务端是标签与媒体标注的唯一权威：客户端以"操作式写入"提交意图，
// 服务端在同一事务内完成校验与落库，并把更新后的行回传供客户端刷新缓存。
package gallery_handler

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/repository/gallery_repo"
	"monarch/internal/service/media_probe"
)

// FetchBatch 处理 GET /API/gallery/batch
//
// 返回指定数量的媒体资产 + 全量标签 + 对应的标签关联关系，
// 供 Android 端下载到本地缓存后离线浏览。
func FetchBatch(c *gin.Context) {
	var params model.BatchQueryParams
	if err := c.ShouldBindQuery(&params); err != nil {
		params = model.BatchQueryParams{}
	}
	if params.Limit <= 0 {
		params.Limit = 200
	}
	if params.Limit > 10000 {
		params.Limit = 10000
	}
	if params.Offset < 0 {
		params.Offset = 0
	}

	mediaAssets, err := gallery_repo.FetchMediaAssetsWithParams(params)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询媒体资产失败: " + err.Error()})
		return
	}

	tags, err := gallery_repo.FetchAllTags()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询标签失败: " + err.Error()})
		return
	}

	mediaIDs := make([]uuid.UUID, len(mediaAssets))
	for i, asset := range mediaAssets {
		mediaIDs[i] = asset.ID
	}

	mediaTagLinks, err := gallery_repo.FetchMediaTagLinks(mediaIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询标签关联失败: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, model.BatchData{
		MediaAssets:   mediaAssets,
		Tags:          tags,
		MediaTagLinks: mediaTagLinks,
	})
}

// FetchAllTags 处理 GET /API/gallery/tags，返回完整标签树。
func FetchAllTags(c *gin.Context) {
	tags, err := gallery_repo.FetchAllTags()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询标签失败: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"tags": tags})
}

// FetchOverview 处理 GET /API/gallery/overview，返回媒体库总览统计。
func FetchOverview(c *gin.Context) {
	overview, err := gallery_repo.FetchGalleryOverview()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询总览失败: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, overview)
}

// FetchMediaAsset 处理 GET /API/gallery/:id/:type
//
// type 取值：file(原文件) / thumb(缩略图) / preview(预览图) /
// frame(视频取帧，配合 ?sec= 秒数) / video-info(视频时长与分辨率)。
func FetchMediaAsset(c *gin.Context) {
	id, ok := parseUUIDParam(c, "id")
	if !ok {
		return
	}

	asset, err := gallery_repo.FetchMediaAssetByID(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询媒体资产失败: " + err.Error()})
		return
	}
	if asset == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "媒体资产不存在"})
		return
	}

	switch typeStr := c.Param("type"); typeStr {
	case "file":
		downloadFile(c, filepath.Join(config.AppConf.GalleryDir, "Media", asset.FilePath))
	case "thumb":
		if asset.ThumbPath == nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "缩略图不存在"})
			return
		}
		downloadFile(c, filepath.Join(config.AppConf.GalleryDir, "Thumbs", *asset.ThumbPath))
	case "preview":
		if asset.PreviewPath == nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "预览图不存在"})
			return
		}
		downloadFile(c, filepath.Join(config.AppConf.GalleryDir, "Preview", *asset.PreviewPath))
	case "frame":
		if !isVideoAsset(asset) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "非视频资产"})
			return
		}
		sec, _ := strconv.ParseFloat(c.Query("sec"), 64)
		srcPath := filepath.Join(config.AppConf.GalleryDir, "Media", asset.FilePath)
		data, err := media_probe.ExtractFrame(id, srcPath, sec)
		if err != nil {
			log.Printf("gallery 取帧失败 [%s @%.1fs]: %v", asset.FilePath, sec, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "提取视频帧失败: " + err.Error()})
			return
		}
		c.Header("Cache-Control", "no-store")
		c.Data(http.StatusOK, "image/jpeg", data)
	case "video-info":
		if !isVideoAsset(asset) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "非视频资产"})
			return
		}
		srcPath := filepath.Join(config.AppConf.GalleryDir, "Media", asset.FilePath)
		info, err := media_probe.ProbeVideo(id, srcPath)
		if err != nil {
			log.Printf("gallery 探测视频信息失败 [%s]: %v", asset.FilePath, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "探测视频信息失败: " + err.Error()})
			return
		}
		c.JSON(http.StatusOK, info)
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的类型参数"})
	}
}

// downloadFile 校验文件存在后交给 gin 做流式响应。
func downloadFile(c *gin.Context, filePath string) {
	if _, err := os.Stat(filePath); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "文件不存在"})
		return
	}
	c.File(filePath)
}

// isVideoAsset 根据 MIME 或扩展名判断是否为视频资产
func isVideoAsset(asset *model.MediaAsset) bool {
	if asset.MimeType != nil && strings.HasPrefix(*asset.MimeType, "video/") {
		return true
	}
	switch strings.ToLower(filepath.Ext(asset.FilePath)) {
	case ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".flv", ".webm", ".m4v", ".3gp", ".ts":
		return true
	}
	return false
}

// ============ 标签与媒体标注操作 ============

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

// bindJSON 解析请求体，失败时已写出响应，调用方直接返回。
func bindJSON(c *gin.Context, target any) bool {
	if err := c.ShouldBindJSON(target); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式错误: " + err.Error()})
		return false
	}
	return true
}

// CreateTag 处理 POST /API/gallery/tags
func CreateTag(c *gin.Context) {
	var req model.TagCreateRequest
	if !bindJSON(c, &req) {
		return
	}
	tag, err := gallery_repo.CreateTag(req.Name, req.ParentID)
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"tag": tag})
}

// UpdateTag 处理 PUT /API/gallery/tags/:id（字段缺省表示不修改）
func UpdateTag(c *gin.Context) {
	id, ok := parseUUIDParam(c, "id")
	if !ok {
		return
	}
	var req model.TagUpdateRequest
	if !bindJSON(c, &req) {
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

// DeleteTag 处理 DELETE /API/gallery/tags/:id（级联删除子孙与标签关联）
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

// QueryMedia 处理 GET /API/gallery/media
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
	if params.SortBy != "" && !gallery_repo.IsValidSortField(params.SortBy) {
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

// SetMediaTags 处理 PUT /API/gallery/media/:id/tags（全量替换，幂等）
func SetMediaTags(c *gin.Context) {
	id, ok := parseUUIDParam(c, "id")
	if !ok {
		return
	}
	var req model.MediaTagsRequest
	if !bindJSON(c, &req) {
		return
	}

	applied, err := gallery_repo.ReplaceMediaTags(id, req.TagIDs)
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, model.MediaTagsResponse{MediaID: id, TagIDs: applied})
}

// BatchMediaTags 处理 POST /API/gallery/media/tags（多媒体的标签增删，幂等）
func BatchMediaTags(c *gin.Context) {
	var req model.MediaTagsBatchRequest
	if !bindJSON(c, &req) {
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

// PatchMedia 处理 PATCH /API/gallery/media
//
// 字段缺省表示不修改；message 空串表示清空；group_id 传 null 表示解绑；
// edit_params 传 null 表示清除。
func PatchMedia(c *gin.Context) {
	var req model.MediaPatchRequest
	if !bindJSON(c, &req) {
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
		switch raw := strings.TrimSpace(string(req.EditParams)); raw {
		case "null":
			patch.ClearEditParams = true
		default:
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
