package gallery_handler

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/repository/gallery_repo"
)

// FetchBatch 处理 GET /api/gallery/batch 请求
// 响应指定数量的媒体资产 + 全量标签 + 对应的标签关联关系
// 支持筛选: mime_type, year, month, day
// 支持排序: sort_by, sort_order, secondary_sort
// @Summary 分页获取媒体批次数据
// @Description 返回媒体资产、全量标签及媒体标签关联
// @Tags gallery
// @Produce json
// @Security ApiKeyAuth
// @Param limit query int false "返回条数（默认 50，最大 10000）"
// @Param offset query int false "偏移量（默认 0）"
// @Param mime_type query string false "MIME类型筛选: image, video, image/jpeg 等"
// @Param sort_by query string false "排序字段: sync_count, captured_at, size_bytes, file_path"
// @Param sort_order query string false "排序方向: asc, desc"
// @Param year query int false "筛选年份"
// @Param month query int false "筛选月份 (需同时指定year)"
// @Param day query int false "筛选日期 (需同时指定year, month)"
// @Param secondary_sort query string false "二次排序字段"
// @Success 200 {object} model.BatchData
// @Failure 500 {object} map[string]string
// @Router /api/gallery/batch [get]
func FetchBatch(c *gin.Context) {
	var params model.BatchQueryParams
	if err := c.ShouldBindQuery(&params); err != nil {
		// 解析失败则使用默认值
		params = model.BatchQueryParams{Limit: 50, Offset: 0}
	}

	// 设置默认值
	if params.Limit <= 0 {
		params.Limit = 50
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
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的类型参数"})
		return
	}
	downloadFile(c, filePath)
}

// Push 处理 POST /api/gallery/push 请求
// 接收客户端上传的数据，更新数据库
// 使用事务确保三个表操作的原子性
// @Summary 推送媒体与标签数据
// @Description 客户端全量/增量推送媒体资产、标签和标签关联
// @Tags gallery
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param body body model.BatchData true "推送数据"
// @Success 200 {object} model.PushResponse
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /api/gallery/push [post]
func Push(c *gin.Context) {
	var req model.BatchData
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式错误: " + err.Error()})
		return
	}

	// 创建带超时的上下文
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// 开启事务，确保三个表操作的原子性
	tx, err := gallery_repo.BeginTx(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "开启事务失败: " + err.Error()})
		return
	}
	defer tx.Rollback(ctx) // 确保出错时回滚

	// 1. 更新媒体资产.
	if len(req.MediaAssets) > 0 {
		if err := gallery_repo.UpdateMediaAssetsTx(ctx, tx, req.MediaAssets); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "更新媒体资产失败: " + err.Error()})
			return
		}
	}

	// 2. 全量覆写标签表
	if err := gallery_repo.UpsertTagsTx(ctx, tx, req.Tags); err != nil {
		fmt.Println(err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新标签失败: " + err.Error()})
		return
	}

	// 3. 获取本次推送涉及的媒体 ID，全量覆写媒体-标签关联
	mediaIDs := make([]uuid.UUID, len(req.MediaAssets))
	for i, asset := range req.MediaAssets {
		mediaIDs[i] = asset.ID
	}

	if err := gallery_repo.UpsertMediaTagLinksTx(ctx, tx, mediaIDs, req.MediaTagLinks); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新标签关联失败: " + err.Error()})
		return
	}

	// 提交事务
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "提交事务失败: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, model.PushResponse{
		Success: true,
		Message: "数据同步成功",
	})
}
