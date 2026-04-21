package comic_handler

import (
	"fmt"
	"monarch/internal/model"
	"monarch/internal/repository/comic_repo"
	"sort"

	"github.com/gin-gonic/gin"
)

// ----漫画数据----
// 获取漫画总信息
// @Summary 获取漫画汇总元数据
// @Tags comic
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} model.ComicTotalMetaData
// @Router /api/comic/meta-info [get]
func FetchComicMetadata(c *gin.Context) {
	metadata, _ := comic_repo.GetComicMetaData()
	c.JSON(200, metadata)
}

// 获取所有漫画信息
// @Summary 获取全部漫画列表
// @Tags comic
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {array} model.ComicInfo
// @Router /api/comic/comic-info [get]
func FetchAllComicInfos(c *gin.Context) {
	comicInfos, _ := comic_repo.GetAllComicInfos()
	c.JSON(200, comicInfos)
}

// 获取某漫画的所有章节信息
// @Summary 获取指定漫画的章节列表
// @Tags comic
// @Produce json
// @Security ApiKeyAuth
// @Param comic-id path string true "漫画ID"
// @Success 200 {array} model.ChapterInfo
// @Router /api/comic/comic-info/{comic-id} [get]
func FetchChaptersWithComicId(c *gin.Context) {
	comicId := c.Param("comic-id")
	chapters, _ := comic_repo.GetChaptersWithComicId(comicId)
	c.JSON(200, chapters)
}

// 在线阅读, 获取某章节的详细信息(包括图片)
// @Summary 获取指定章节详情（含图片）
// @Tags comic
// @Produce json
// @Security ApiKeyAuth
// @Param chapter-id path string true "章节ID"
// @Success 200 {object} model.ChapterInfo
// @Failure 404 {object} map[string]string
// @Router /api/comic/chapter-info/{chapter-id} [get]
func FetchImagesWithChapterId(c *gin.Context) {
	chapterId := c.Param("chapter-id")
	chapterInfo, err := comic_repo.GetImagesWithChapterId(chapterId)
	if err != nil {
		c.JSON(404, gin.H{
			"message": fmt.Errorf("FetchChapterInfo出错: %w", err),
		})
	}
	c.JSON(200, chapterInfo)
}

// 下载整部漫画
// @Summary 下载整部漫画清单
// @Tags comic
// @Produce json
// @Security ApiKeyAuth
// @Param comic-id path string true "漫画ID"
// @Success 200 {array} model.ChapterInfo
// @Router /api/comic/download/{comic-id} [get]
func DownloadComic(c *gin.Context) {
	comicId := c.Param("comic-id")
	chapterMap, imageMap, _ := comic_repo.GetComicAllChaptersAndImages(comicId)
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
