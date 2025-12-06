package comic_handler

import (
	"fmt"
	"monarch/internal/repository/comic_repo"
	"monarch/internal/service/db"

	"github.com/gin-gonic/gin"
)

// ----漫画数据----
// 获取漫画总信息
func FetchComicMetadata(c *gin.Context) {
	ctx, _ := db.GetDefailtCtx()
	metadata, _ := comic_repo.GetComicMetaData(ctx, db.GetPool())
	c.JSON(200, metadata)
}

// 获取所有漫画信息
func FetchAllComicInfos(c *gin.Context) {
	ctx, _ := db.GetDefailtCtx()
	comicInfos, _ := comic_repo.GetAllComicInfos(ctx, db.GetPool())
	c.JSON(200, comicInfos)
}

func FetchChaptersWithComicId(c *gin.Context) {
	comicId := c.Param("comic-id")
	ctx, _ := db.GetDefailtCtx()
	comicInfos, _ := comic_repo.GetChaptersWithComicId(ctx, db.GetPool(), comicId)
	c.JSON(200, comicInfos)
}

// 在线阅读comic/chapter
func FetchChapterInfo(c *gin.Context) {
	chapterId := c.Param("chapter-id")
	ctx, _ := db.GetDefailtCtx()
	chapterInfo, err := comic_repo.GetChapterInfo(ctx, db.GetPool(), chapterId)
	if err != nil {
		fmt.Errorf("FetchChapterInfo出错: %w", err)
	}
	c.JSON(200, chapterInfo)
}
