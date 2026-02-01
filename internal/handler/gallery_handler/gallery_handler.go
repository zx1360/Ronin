package gallery_handler

import (
	"net/http"
	"os"
	"path/filepath"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/repository/gallery_repo"
)

// FetchBatch 处理 GET /api/gallery/batch 请求
// 响应指定数量的媒体资产 + 全量标签 + 对应的标签关联关系
func FetchBatch(c *gin.Context) {
	// 解析分页参数
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 50
	}
	if limit > 2000 {
		limit = 2000 // 限制最大查询数量
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	// 查询媒体资产
	mediaAssets, err := gallery_repo.FetchMediaAssets(limit, offset)
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
func FetchAllTags(c *gin.Context) {
	tags, err := gallery_repo.FetchAllTags()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询标签失败: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"tags": tags})
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
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的类型参数"})
		return
	}
	downloadFile(c, filePath)
}

// Push 处理 POST /api/gallery/push 请求
// 接收客户端上传的数据，更新数据库
func Push(c *gin.Context) {
	var req model.BatchData
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式错误: " + err.Error()})
		return
	}

	// TODO: 下方三个步骤置于事务中, 确保原子性一致性.
	// 更新媒体资产（除 file_path 字段）
	if len(req.MediaAssets) > 0 {
		if err := gallery_repo.UpdateMediaAssets(req.MediaAssets); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "更新媒体资产失败: " + err.Error()})
			return
		}
	}

	// 全量覆写标签表
	if err := gallery_repo.UpsertTags(req.Tags); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新标签失败: " + err.Error()})
		return
	}

	// 获取本次推送涉及的媒体 ID
	mediaIDs := make([]uuid.UUID, len(req.MediaAssets))
	for i, asset := range req.MediaAssets {
		mediaIDs[i] = asset.ID
	}

	// 全量覆写媒体-标签关联
	if err := gallery_repo.UpsertMediaTagLinks(mediaIDs, req.MediaTagLinks); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新标签关联失败: " + err.Error()})
		return
	}

	// 将媒体资产的 sync_count 加 1
	if err := gallery_repo.IncrementSyncCount(mediaIDs); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新同步计数失败: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, model.PushResponse{
		Success: true,
		Message: "数据同步成功",
	})
}
