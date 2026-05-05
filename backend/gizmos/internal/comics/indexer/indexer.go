package indexer

// 编排四种运行模式：
// - 章节级增量：扫描全盘，按章节跳过已存在章节
// - 漫画级增量：先列漫画名，已有整本则跳过，仅扫描新漫画
// - 全量重建：清空后全量扫描与写入
// - 刷新更新：对齐磁盘与数据库，支持新增与硬删除

import (
	"fmt"
	"strings"

	"gizmos/internal/comics/model"
	"gizmos/internal/comics/repository"
	"gizmos/internal/comics/scanner"
)

// IndexIncrementalByChapter 章节级增量
func IndexIncrementalByChapter(root string) error {
	fmt.Printf("🔍 开始扫描(章节级增量)：%s\n", root)
	comicBooks, totalScannedBooks_ch, totalScannedBooks_img, err := scanner.ScanFull(root)
	if err != nil {
		return fmt.Errorf("扫描失败: %w", err)
	}
	totalScannedBooks := len(comicBooks)
	fmt.Printf("✅ 扫描完成：共扫描到 %d 本漫画\n", totalScannedBooks)

	existingChapters, err := repository.GetExistingChapters()
	if err != nil {
		return fmt.Errorf("查询已存在章节失败: %w", err)
	}
	fmt.Printf("ℹ️  数据库中已存在 %d 个章节\n", len(existingChapters))

	newChapterCount, newImageCount, err := repository.InsertComicData(comicBooks, existingChapters)
	if err != nil {
		return fmt.Errorf("插入漫画数据失败: %w", err)
	}

	_ = totalScannedBooks_ch
	_ = totalScannedBooks_img

	existingComicSet := make(map[string]struct{})
	for key := range existingChapters {
		comicTitle := strings.Split(key, "|")[0]
		existingComicSet[comicTitle] = struct{}{}
	}
	existingComicCount := len(existingComicSet)
	newBookCount := totalScannedBooks - existingComicCount

	fmt.Printf("🎉 增量(章节)完成！📊 新增漫画=%d，新增章节=%d，新增图片=%d\n", newBookCount, newChapterCount, newImageCount)
	return nil
}

// IndexIncrementalByComic 漫画级增量（已有整本跳过）
func IndexIncrementalByComic(root string) error {
	fmt.Printf("🔍 开始扫描(漫画级增量)：%s\n", root)

	titlesOnDisk, err := scanner.ListComicTitles(root)
	if err != nil {
		return err
	}
	existing, err := repository.GetAllComicTitles()
	if err != nil {
		return err
	}

	var newTitles []string
	for _, t := range titlesOnDisk {
		if _, ok := existing[t]; !ok {
			newTitles = append(newTitles, t)
		}
	}
	if len(newTitles) == 0 {
		fmt.Println("ℹ️  没有新漫画需要新增")
		return nil
	}

	newBooks, _, _, err := scanner.ScanComicsByTitles(root, newTitles)
	if err != nil {
		return err
	}

	if _, _, err := repository.InsertAllComics(newBooks); err != nil {
		return err
	}

	fmt.Printf("🎉 增量(漫画)完成！📊 新增漫画=%d\n", len(newTitles))
	return nil
}

// IndexFullReindex 全量重建索引
func IndexFullReindex(root string) error {
	fmt.Printf("🧹 清空旧数据并全量重建：%s\n", root)
	if err := repository.ClearOldData(); err != nil {
		return err
	}
	books, chapters, images, err := scanner.ScanFull(root)
	if err != nil {
		return err
	}
	if _, _, err := repository.InsertAllComics(books); err != nil {
		return err
	}
	fmt.Printf("🎉 全量重建完成！📊 漫画=%d，章节=%d，图片=%d\n", len(books), chapters, images)
	return nil
}

// IndexRefresh 刷新更新（新增与硬删除，章节与图片同步）
func IndexRefresh(root string) error {
	fmt.Printf("🔁 刷新对齐文件系统：%s\n", root)

	titlesOnDisk, err := scanner.ListComicTitles(root)
	if err != nil {
		return err
	}
	existing, err := repository.GetAllComicTitles()
	if err != nil {
		return err
	}

	diskSet := make(map[string]struct{}, len(titlesOnDisk))
	for _, t := range titlesOnDisk {
		diskSet[t] = struct{}{}
	}

	var toDelete []string
	var toInsert []string
	for t := range existing {
		if _, ok := diskSet[t]; !ok {
			toDelete = append(toDelete, t)
		}
	}
	for _, t := range titlesOnDisk {
		if _, ok := existing[t]; !ok {
			toInsert = append(toInsert, t)
		}
	}

	if err := repository.DeleteComicsByTitles(toDelete); err != nil {
		return err
	}

	if len(toInsert) > 0 {
		newBooks, _, _, err := scanner.ScanComicsByTitles(root, toInsert)
		if err != nil {
			return err
		}
		if _, _, err := repository.InsertAllComics(newBooks); err != nil {
			return err
		}
	}

	for t := range existing {
		if _, ok := diskSet[t]; !ok {
			continue
		}
		book, err := scanner.ScanChaptersForComic(root, t)
		if err != nil {
			return err
		}
		if book == nil {
			continue
		}
		chapterMapDB, comicID, err := repository.GetChaptersByTitle(t)
		if err != nil {
			return err
		}

		diskChapters := make(map[string]model.ComicChapter)
		for _, ch := range book.Chapters {
			diskChapters[ch.DirName] = ch
		}

		for dir, meta := range chapterMapDB {
			if _, ok := diskChapters[dir]; !ok {
				if err := repository.DeleteChapterByID(meta.ID); err != nil {
					return err
				}
			}
		}
		for dir, ch := range diskChapters {
			if meta, ok := chapterMapDB[dir]; ok {
				if err := repository.ReplaceChapterImages(meta.ID, ch.Images); err != nil {
					return err
				}
			} else {
				if err := repository.InsertChapterWithImages(comicID, ch); err != nil {
					return err
				}
			}
		}
	}

	fmt.Println("🎉 刷新更新完成！")
	return nil
}
