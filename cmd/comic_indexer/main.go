package main

import (
	"fmt"
	"strings"

	"gizmos/internal/comics"
	"gizmos/internal/service/config"
	"gizmos/internal/service/db"
)

// 配置项（全局唯一配置点）
const (
	comicRoot = "D:\\products\\Go\\monarch\\static\\comics"
)

func main() {
	db.Init(config.DbConf)
	defer db.Close()

	// TODO: 就算是增量更新, 全目录扫描还是好笨重, 再加一个"漫画级"跳过吧.
	// 2. 扫描漫画目录（获取所有漫画/章节/图片信息，包含已存在的）
	fmt.Printf("🔍 开始扫描漫画目录: %s\n", comicRoot)
	comicBooks, _, _, err := comics.ScanComicDir(comicRoot)
	if err != nil {
		fmt.Printf("❌ 扫描漫画目录失败: %v\n", err)
		return
	}
	totalScannedBooks := len(comicBooks)
	fmt.Printf("✅ 扫描完成：共扫描到 %d 本漫画\n", totalScannedBooks)

	// 3. 增量更新核心逻辑
	existingChapters, err := comics.GetExistingChapters()
	if err != nil {
		fmt.Printf("❌ 查询已存在章节失败: %v\n", err)
		return
	}
	fmt.Printf("ℹ️  数据库中已存在 %d 个章节\n", len(existingChapters))

	// 3.2 查询当前汇总统计（用于增量更新汇总信息）
	existingBookCount, existingChapterCount, existingImageCount, err := comics.GetCurrentSummary()
	if err != nil {
		fmt.Printf("❌ 查询当前汇总信息失败: %v\n", err)
		return
	}
	fmt.Printf("ℹ️  当前数据库统计：漫画数=%d，章节数=%d，图片数=%d\n",
		existingBookCount, existingChapterCount, existingImageCount)

	// 3.3 批量插入新增数据（跳过已存在章节）
	newChapterCount, newImageCount, err := comics.InsertComicData(comicBooks, existingChapters)
	if err != nil {
		fmt.Printf("❌ 插入漫画数据失败: %v\n", err)
		return
	}

	// 3.4 计算新增漫画数（扫描到的漫画数 - 已存在的漫画数）
	// 注：已存在的漫画数 = 已存在的章节对应的唯一漫画数（通过existingChapters提取）
	existingComicSet := make(map[string]struct{})
	for key := range existingChapters {
		comicTitle := strings.Split(key, "|")[0]
		existingComicSet[comicTitle] = struct{}{}
	}
	existingComicCount := len(existingComicSet)
	newBookCount := totalScannedBooks - existingComicCount

	// 4. 更新汇总信息（增量更新）
	totalChapterCount, titalImageCount := existingChapterCount+newChapterCount, existingImageCount+newImageCount
	if err := comics.UpdateSummary(
		totalScannedBooks, totalChapterCount, titalImageCount,
	); err != nil {
		fmt.Printf("❌ 更新汇总信息失败: %v\n", err)
		return
	}

	fmt.Println("🎉 增量更新完成！")
	fmt.Printf("📊 本次更新统计：新增漫画数=%d，新增章节数=%d，新增图片数=%d\n",
		newBookCount, newChapterCount, newImageCount)
}
