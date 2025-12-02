package main

import (
	"fmt"

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

	// 2. 扫描漫画目录
	fmt.Printf("🔍 开始扫描漫画目录: %s\n", comicRoot)
	comicBooks, totalChapterCount, totalImageCount, err := comics.ScanComicDir(comicRoot)
	if err != nil {
		fmt.Printf("❌ 扫描漫画目录失败: %v\n", err)
		return
	}
	bookCount := len(comicBooks)
	fmt.Printf("✅ 扫描完成：共 %d 本漫画，%d 个章节，%d 张图片\n", bookCount, totalChapterCount, totalImageCount)

	// 3. 清空旧数据（如需保留历史数据，注释此行）
	if err := dbStorage.ClearOldData(); err != nil {
		fmt.Printf("❌ 清空旧数据失败: %v\n", err)
		return
	}

	// 4. 插入数据到数据库
	if err := dbStorage.InsertComicData(comicBooks); err != nil {
		fmt.Printf("❌ 插入漫画数据失败: %v\n", err)
		return
	}

	// 5. 更新汇总信息
	if err := dbStorage.UpdateSummary(bookCount, totalChapterCount, totalImageCount); err != nil {
		fmt.Printf("❌ 更新汇总信息失败: %v\n", err)
		return
	}

	fmt.Println("🎉 所有漫画元数据已成功存入数据库！")
}
