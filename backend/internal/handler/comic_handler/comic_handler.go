// Package comic_handler 提供 Android 端"漫画"模块的接口（legacy 书库 + 在线章节）。
//
// 数据来自 comix schema 中由爬虫维护的视图；管理字段更新仍写回数据库。
package comic_handler

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"sort"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/repository/comic_repo"
)

// FetchComicMetadata 获取漫画汇总元数据。
func FetchComicMetadata(c *gin.Context) {
	metadata, err := comic_repo.GetComicMetaData()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, metadata)
}

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

// DeleteComic 删除漫画：先删数据库记录，再清理文件系统资源。
//
// 文件布局有两套，都要覆盖（目录不存在时 RemoveAll 返回 nil，无需预判）：
// legacy 资源为 {STATIC_DIR}/comics/{title}，爬虫资源为 {STATIC_DIR}/{rel_dir}。
func DeleteComic(c *gin.Context) {
	title, relDir, err := comic_repo.DeleteComic(c.Param("comic-id"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	targets := make([]string, 0, 2)
	if relDir != "" {
		targets = append(targets, filepath.Join(config.AppConf.StaticDir, filepath.FromSlash(relDir)))
	}
	if title != "" {
		targets = append(targets, filepath.Join(config.AppConf.StaticDir, "comics", title))
	}

	var failed []string
	for _, dir := range targets {
		if err := os.RemoveAll(dir); err != nil {
			failed = append(failed, fmt.Sprintf("%s: %v", dir, err))
		}
	}
	if len(failed) > 0 {
		// 文件清理失败不阻塞响应，但要如实告知客户端
		c.JSON(http.StatusOK, gin.H{
			"status":  "partial",
			"message": fmt.Sprintf("数据库记录已删除，但文件清理失败: %v", failed),
			"deleted": title,
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ok", "deleted": title})
}

// SyncReadedStatus 同步已读状态，并返回各漫画的服务器章节总数（供客户端判断增量）。
func SyncReadedStatus(c *gin.Context) {
	var req model.SyncReadedRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体格式无效: " + err.Error()})
		return
	}
	resp, err := comic_repo.SyncReadedStatus(req.ReadedIds)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, resp)
}
