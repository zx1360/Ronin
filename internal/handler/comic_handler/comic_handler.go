package comic_handler

import (
	"monarch/internal/common"
	"monarch/internal/model"
	"monarch/internal/repository/comic_repo"
	"sort"

	"github.com/gin-gonic/gin"
)

// ----漫画数据----
// 获取漫画总信息
func FetchComicMetadata(c *gin.Context) {
	metadata, err := comic_repo.GetComicMetaData()
	if err != nil {
		common.InternalError(c, "获取漫画元数据失败", err)
		return
	}
	common.Success(c, metadata)
}

// 获取所有漫画信息
func FetchAllComicInfos(c *gin.Context) {
	comicInfos, err := comic_repo.GetAllComicInfos()
	if err != nil {
		common.InternalError(c, "获取漫画列表失败", err)
		return
	}
	common.Success(c, comicInfos)
}

// 获取某漫画的所有章节信息
func FetchChaptersWithComicId(c *gin.Context) {
	comicId := c.Param("comic-id")
	if comicId == "" {
		common.BadRequest(c, "缺少漫画ID参数")
		return
	}
	chapters, err := comic_repo.GetChaptersWithComicId(comicId)
	if err != nil {
		common.InternalError(c, "获取章节列表失败", err)
		return
	}
	common.Success(c, chapters)
}

// 在线阅读, 获取某章节的详细信息(包括图片)
func FetchImagesWithChapterId(c *gin.Context) {
	chapterId := c.Param("chapter-id")
	if chapterId == "" {
		common.BadRequest(c, "缺少章节ID参数")
		return
	}
	chapterInfo, err := comic_repo.GetImagesWithChapterId(chapterId)
	if err != nil {
		common.NotFound(c, "章节不存在或获取失败")
		return
	}
	common.Success(c, chapterInfo)
}

// 下载整部漫画
func DownloadComic(c *gin.Context) {
	comicId := c.Param("comic-id")
	if comicId == "" {
		common.BadRequest(c, "缺少漫画ID参数")
		return
	}
	chapterMap, imageMap, err := comic_repo.GetComicAllChaptersAndImages(comicId)
	if err != nil {
		common.InternalError(c, "获取漫画下载清单失败", err)
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

	common.Success(c, manifest)
}
