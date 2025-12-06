package main

import (
	"fmt"
	"strings"

	"gizmos/internal/comics"
)

// 配置项（全局唯一配置点）
const (
	comicRoot = "D:\\products\\Go\\monarch\\static\\comics"
)

func main() {
	// 1. 初始化数据库存储
	dbStorage, err := comics.NewStorage()
	if err != nil {
		fmt.Printf("❌ 初始化存储失败: %v\n", err)
		return
	}
	defer dbStorage.Close()
	fmt.Println("✅ 数据库连接成功")

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
	// 3.1 查询已存在的章节（用于跳过重复）
	existingChapters, err := dbStorage.GetExistingChapters()
	if err != nil {
		fmt.Printf("❌ 查询已存在章节失败: %v\n", err)
		return
	}
	fmt.Printf("ℹ️  数据库中已存在 %d 个章节\n", len(existingChapters))

	// 3.2 查询当前汇总统计（用于增量更新汇总信息）
	existingBookCount, existingChapterCount, existingImageCount, err := dbStorage.GetCurrentSummary()
	if err != nil {
		fmt.Printf("❌ 查询当前汇总信息失败: %v\n", err)
		return
	}
	fmt.Printf("ℹ️  当前数据库统计：漫画数=%d，章节数=%d，图片数=%d\n",
		existingBookCount, existingChapterCount, existingImageCount)

	// 3.3 批量插入新增数据（跳过已存在章节）
	newChapterCount, newImageCount, err := dbStorage.InsertComicData(comicBooks, existingChapters)
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
	if newBookCount < 0 {
		newBookCount = 0 // 避免扫描到的漫画数少于已存在的情况（如手动删除了部分漫画）
	}

	// 4. 更新汇总信息（增量更新）
	if err := dbStorage.UpdateSummary(
		existingBookCount, existingChapterCount, existingImageCount,
		newBookCount, newChapterCount, newImageCount,
	); err != nil {
		fmt.Printf("❌ 更新汇总信息失败: %v\n", err)
		return
	}

	fmt.Println("🎉 增量更新完成！")
	fmt.Printf("📊 本次更新统计：新增漫画数=%d，新增章节数=%d，新增图片数=%d\n",
		newBookCount, newChapterCount, newImageCount)
}
