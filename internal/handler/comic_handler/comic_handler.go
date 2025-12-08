package comic_handler

import (
	"fmt"
	"monarch/internal/repository/comic_repo"

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
	comicInfos, _ := comic_repo.GetChaptersWithComicId(comicId)
	c.JSON(200, comicInfos)
}

// 在线阅读, 获取某章节的详细信息(包括图片)
func FetchChapterInfo(c *gin.Context) {
	chapterId := c.Param("chapter-id")
	chapterInfo, err := comic_repo.GetChapterInfo(chapterId)
	if err != nil {
		c.JSON(404, gin.H{
			"message": fmt.Errorf("FetchChapterInfo出错: %w", err),
		})
	}
	c.JSON(200, chapterInfo)
}

// 下载整部漫画
func DownloadComic(c *gin.Context) {
	// comicId := c.Param("comic-id")

}
