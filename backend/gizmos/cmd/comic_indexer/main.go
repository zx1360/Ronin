package main

import (
	"flag"
	"fmt"

	"gizmos/internal/comics/indexer"
	"gizmos/internal/service/config"
	"gizmos/internal/service/db"
)

// 配置项（全局唯一配置点）
const (
	defaultComicRoot = "D:\\products\\Ronin\\backend\\static\\comics"
)

func main() {
	mode := flag.String("mode", "refresh", "运行模式: chapter-incremental | comic-incremental | full-reindex | refresh")
	comicRoot := flag.String("root", defaultComicRoot, "漫画根目录")
	flag.Parse()

	db.Init(config.DbConf)
	defer db.Close()

	fmt.Printf("漫画索引任务启动: mode=%s root=%s\n", *mode, *comicRoot)

	var err error
	switch *mode {
	case "chapter-incremental":
		err = indexer.IndexIncrementalByChapter(*comicRoot)
	case "comic-incremental":
		err = indexer.IndexIncrementalByComic(*comicRoot)
	case "full-reindex":
		err = indexer.IndexFullReindex(*comicRoot)
	case "refresh":
		err = indexer.IndexRefresh(*comicRoot)
	default:
		err = fmt.Errorf("未知 mode: %s (可选: chapter-incremental, comic-incremental, full-reindex, refresh)", *mode)
	}

	if err != nil {
		fmt.Printf("运行失败: %v\n", err)
		return
	}
	fmt.Println("运行完成")
}
