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
func FetchComicMetadata(c *gin.Context) {
	metadata, _ := comic_repo.GetComicMetaData()
	c.JSON(200, metadata)
}

// 获取所有漫画信息
func FetchAllComicInfos(c *gin.Context) {
	comicInfos, _ := comic_repo.GetAllComicInfos()
	c.JSON(200, comicInfos)
}

// 获取某漫画的所有章节信息
func FetchChaptersWithComicId(c *gin.Context) {
	comicId := c.Param("comic-id")
	chapters, _ := comic_repo.GetChaptersWithComicId(comicId)
	c.JSON(200, chapters)
}

// 在线阅读, 获取某章节的详细信息(包括图片)
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
