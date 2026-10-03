// Package comic_handler 提供 Android 端"漫画"模块的接口（书库浏览 + 在线章节下载）。
//
// 数据来自 comix 侧由爬虫维护的 `comic_*` 表；管理字段更新也写回同一批表。
package comic_handler

import (
	"fmt"
	"net/http"
	"sort"

	"github.com/gin-gonic/gin"

	"monarch/internal/model"
	"monarch/internal/repository/comic_repo"
)

// FetchAllComicInfos 获取全部漫画列表。
func FetchAllComicInfos(c *gin.Context) {
	comicInfos, err := comic_repo.GetAllComicInfos()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, comicInfos)
}

// FetchChaptersWithComicId 获取指定漫画的章节列表。
func FetchChaptersWithComicId(c *gin.Context) {
	chapters, err := comic_repo.GetChaptersWithComicId(c.Param("comic-id"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, chapters)
}

// FetchImagesWithChapterId 获取指定章节的图片清单（在线阅读用）。
func FetchImagesWithChapterId(c *gin.Context) {
	chapterInfo, err := comic_repo.GetImagesWithChapterId(c.Param("chapter-id"))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("FetchChapterInfo出错: %v", err)})
		return
	}
	c.JSON(http.StatusOK, chapterInfo)
}

// DownloadComic 返回整部漫画的章节+图片清单（客户端据此离线下载）。
func DownloadComic(c *gin.Context) {
	chapterMap, imageMap, err := comic_repo.GetComicAllChaptersAndImages(c.Param("comic-id"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	manifest := make([]model.ChapterInfo, 0, len(chapterMap))
	for _, chapter := range chapterMap {
		manifest = append(manifest, model.ChapterInfo{
			ID:           chapter.ID,
			ComicID:      chapter.ComicID,
			DirName:      chapter.DirName,
			ChapterIndex: chapter.ChapterIndex,
			ImageCount:   chapter.ImageCount,
			Images:       imageMap[chapter.ID],
		})
	}
	sort.Slice(manifest, func(i, j int) bool {
		return manifest[i].ChapterIndex < manifest[j].ChapterIndex
	})

	c.JSON(http.StatusOK, manifest)
}

// UpdateComic 更新漫画元数据（is_public / readed / cover_image）。
func UpdateComic(c *gin.Context) {
	var req model.UpdateComicRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式无效: " + err.Error()})
		return
	}
	if err := comic_repo.UpdateComicMeta(c.Param("comic-id"), req); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
