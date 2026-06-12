package comic_handler

import (
	"fmt"
	"monarch/internal/model"
	"monarch/internal/repository/comic_repo"
	"os"
	"path/filepath"
	"sort"

	"github.com/gin-gonic/gin"
)

// ----漫画数据----
// 获取漫画总信息
// @Summary 获取漫画汇总元数据
// @Tags comic
// @Produce json
// @Success 200 {object} model.ComicTotalMetaData
// @Router /api/comic/meta-info [get]
func FetchComicMetadata(c *gin.Context) {
	metadata, err := comic_repo.GetComicMetaData()
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, metadata)
}

// 获取所有漫画信息
// @Summary 获取全部漫画列表
// @Tags comic
// @Produce json
// @Success 200 {array} model.ComicInfo
// @Router /api/comic/comic-info [get]
func FetchAllComicInfos(c *gin.Context) {
	comicInfos, err := comic_repo.GetAllComicInfos()
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, comicInfos)
}

// 获取某漫画的所有章节信息
// @Summary 获取指定漫画的章节列表
// @Tags comic
// @Produce json
// @Param comic-id path string true "漫画ID"
// @Success 200 {array} model.ChapterInfo
// @Router /api/comic/comic-info/{comic-id} [get]
func FetchChaptersWithComicId(c *gin.Context) {
	comicId := c.Param("comic-id")
	chapters, err := comic_repo.GetChaptersWithComicId(comicId)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, chapters)
}

// 在线阅读, 获取某章节的详细信息(包括图片)
// @Summary 获取指定章节详情（含图片）
// @Tags comic
// @Produce json
// @Param chapter-id path string true "章节ID"
// @Success 200 {object} model.ChapterInfo
// @Failure 404 {object} map[string]string
// @Router /api/comic/chapter-info/{chapter-id} [get]
func FetchImagesWithChapterId(c *gin.Context) {
	chapterId := c.Param("chapter-id")
	chapterInfo, err := comic_repo.GetImagesWithChapterId(chapterId)
	if err != nil {
		c.JSON(404, gin.H{
			"message": fmt.Sprintf("FetchChapterInfo出错: %v", err),
		})
		return
	}
	c.JSON(200, chapterInfo)
}

// 下载整部漫画
// @Summary 下载整部漫画清单
// @Tags comic
// @Produce json
// @Param comic-id path string true "漫画ID"
// @Success 200 {array} model.ChapterInfo
// @Router /api/comic/download/{comic-id} [get]
func DownloadComic(c *gin.Context) {
	comicId := c.Param("comic-id")
	chapterMap, imageMap, err := comic_repo.GetComicAllChaptersAndImages(comicId)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	manifest := make([]model.ChapterInfo, 0, len(chapterMap))
	for _, chapter := range chapterMap {
		manifest = append(manifest, model.ChapterInfo{
			Id:           chapter.Id,
			ComicId:      chapter.ComicId,
			DirName:      chapter.DirName,
			ChapterIndex: chapter.ChapterIndex,
			ImageCount:   chapter.ImageCount,
			Images:       imageMap[chapter.Id],
		})
	}
	sort.Slice(manifest, func(i, j int) bool {
		return manifest[i].ChapterIndex < manifest[j].ChapterIndex
	})

	c.JSON(200, manifest)
}

// ---- 新增: 漫画管理接口 ----

// UpdateComic 更新漫画元数据 (is_public/readed/cover_image)
// @Summary 更新漫画元数据
// @Tags comic
// @Accept json
// @Produce json
// @Param comic-id path string true "漫画ID"
// @Param body body model.UpdateComicRequest true "更新字段"
// @Success 200 {object} map[string]string
// @Router /api/comic/comic-info/{comic-id} [put]
func UpdateComic(c *gin.Context) {
	comicId := c.Param("comic-id")
	var req model.UpdateComicRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"error": "请求体格式无效: " + err.Error()})
		return
	}

	if err := comic_repo.UpdateComicMeta(comicId, req); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, gin.H{"status": "ok"})
}

// DeleteComic 删除漫画（级联删除数据库记录 + 文件系统资源）
// @Summary 删除漫画
// @Tags comic
// @Produce json
// @Param comic-id path string true "漫画ID"
// @Success 200 {object} map[string]string
// @Router /api/comic/comic-info/{comic-id} [delete]
func DeleteComic(c *gin.Context) {
	comicId := c.Param("comic-id")

	// 先获取标题用于删除文件
	title, err := comic_repo.DeleteComic(comicId)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	// 删除文件系统中的漫画资源目录
	comicDir := filepath.Join("static", "comics", title)
	if err := os.RemoveAll(comicDir); err != nil {
		// 文件删除失败不阻塞响应，但记录
		c.JSON(200, gin.H{
			"status":  "partial",
			"message": fmt.Sprintf("数据库记录已删除，但文件清理失败: %v", err),
		})
		return
	}

	c.JSON(200, gin.H{"status": "ok", "deleted": title})
}

// SyncReadedStatus 同步已读状态并返回各漫画服务器章节总数
// @Summary 同步已读状态
// @Tags comic
// @Accept json
// @Produce json
// @Param body body model.SyncReadedRequest true "已读漫画ID列表"
// @Success 200 {object} model.SyncReadedResponse
// @Router /api/comic/sync-readed [post]
func SyncReadedStatus(c *gin.Context) {
	var req model.SyncReadedRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"error": "请求体格式无效: " + err.Error()})
		return
	}

	resp, err := comic_repo.SyncReadedStatus(req.ReadedIds)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, resp)
}
