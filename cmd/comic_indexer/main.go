package main

import (
	"fmt"

	"gizmos/internal/comics/indexer"
	"gizmos/internal/service/config"
	"gizmos/internal/service/db"
)

// 配置项（全局唯一配置点）
const (
	comicRoot = "D:\\products\\Go\\monarch\\static\\comics"
)

// 运行模式切换：按需手动切换调用
// 1) indexer.IndexIncrementalByChapter(comicRoot)
// 2) indexer.IndexIncrementalByComic(comicRoot)
// 3) indexer.IndexFullReindex(comicRoot)
// 4) indexer.IndexRefresh(comicRoot)
func main() {
	db.Init(config.DbConf)
	defer db.Close()

	// 手动切换不同模式：选择其一调用
	// 章节级增量（按章节跳过已存在章节）
	// err := indexer.IndexIncrementalByChapter(comicRoot)

	// 漫画级增量（已有整本漫画则整本跳过）
	// err := indexer.IndexIncrementalByComic(comicRoot)

	// 全量重建索引（清表后重建）
	// err := indexer.IndexFullReindex(comicRoot)

	// 刷新更新（对齐磁盘变化，支持新增与硬删除）
	err := indexer.IndexRefresh(comicRoot)

	if err != nil {
		fmt.Printf("❌ 运行失败: %v\n", err)
		return
	}
	fmt.Println("🎉 运行完成！")
}
