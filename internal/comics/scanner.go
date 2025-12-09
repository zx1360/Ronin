package comics

/// 目录扫描包

import (
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
)

const (
	supportImageExts = ".jpg,.jpeg,.png,.gif"
	maxConcurrency   = 32
)

// ScanComicDir 扫描漫画根目录，返回漫画列表及统计信息
// TODO: 多一个选项: 是否删除数据库中已不存在的漫画/章节/图片记录
// TODO: 设置raw目录用以专门检测新增, 而comics目录用以全盘确认/删除已不存在的记录等.
func ScanComicDir(root string) ([]*ComicBook, int, int, error) {
	var comicBooks []*ComicBook
	totalChapterCount := 0
	totalImageCount := 0

	comicDirs, err := os.ReadDir(root)
	if err != nil {
		return nil, 0, 0, wrapError("读取根目录失败", err)
	}

	for _, comicDir := range comicDirs {
		if !comicDir.IsDir() {
			continue
		}

		comic := NewComicBook(comicDir.Name())
		comicPath := filepath.Join(root, comic.Title)
		println("📚 处理漫画:", comic.Title)

		chapterDirs, err := os.ReadDir(comicPath)
		if err != nil {
			println("⚠️  读取漫画目录", comicPath, "失败，跳过:", err)
			continue
		}

		sortedChapterDirs := sortChapterDirs(chapterDirs)
		comicTotalImages := 0

		for idx, chapterDir := range sortedChapterDirs {
			if !chapterDir.IsDir() {
				continue
			}

			dirName := chapterDir.Name()
			chapterIndex := extractPrefixNumber(dirName)
			chapter := NewComicChapter(comic.ID, dirName, chapterIndex)
			chapterPath := filepath.Join(comicPath, dirName)

			imageFiles, err := os.ReadDir(chapterPath)
			if err != nil {
				println("⚠️  读取章节目录", chapterPath, "失败，跳过:", err)
				continue
			}

			sortedImageFiles := filterAndSortImages(imageFiles)
			if len(sortedImageFiles) == 0 {
				println("⚠️  章节目录", dirName, "无有效图片，跳过")
				continue
			}

			// 并发读取图片宽高
			images := readImageMetadata(chapter.ID, chapterPath, sortedImageFiles)
			chapter.Images = images
			chapter.ImageCount = len(images)

			// 设置封面图（第一个章节的第一张图）
			if idx == 0 && len(images) > 0 {
				comic.CoverImage = images[0].ImagePath
			}

			comic.Chapters = append(comic.Chapters, *chapter)
			comic.ChapterCount++
			comicTotalImages += chapter.ImageCount
			totalImageCount += chapter.ImageCount
		}

		if comic.ChapterCount == 0 {
			println("⚠️  漫画", comic.Title, "无有效章节，跳过")
			continue
		}

		comic.ImageCount = comicTotalImages
		comicBooks = append(comicBooks, comic)
		totalChapterCount += comic.ChapterCount
	}

	return comicBooks, totalChapterCount, totalImageCount, nil
}

// 并发读取图片元数据（宽高、路径等）
func readImageMetadata(chapterID, chapterPath string, imageFiles []os.DirEntry) []ComicImage {
	var (
		images    []ComicImage
		wg        sync.WaitGroup
		semaphore = make(chan struct{}, maxConcurrency)
		mu        sync.Mutex
	)

	imageCount := len(imageFiles)
	wg.Add(imageCount)

	for imgIdx, imgFile := range imageFiles {
		go func() {
			defer wg.Done()
			// 用带缓冲的通道实现固定上限的并发控制.
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			imgFullPath := filepath.Join(chapterPath, imgFile.Name())
			// 提取相对路径（基于 static 目录）
			relPath := strings.ReplaceAll(imgFullPath[strings.Index(imgFullPath, `static\`)+len(`static\`):], "\\", "/")
			width, height := getImageDimensionsSafe(imgFullPath)

			mu.Lock()
			images = append(images, *NewComicImage(
				chapterID, relPath, imgIdx+1, width, height,
			))
			mu.Unlock()
		}()
	}

	wg.Wait()

	// 按排序号恢复顺序
	sort.Slice(images, func(i, j int) bool {
		return images[i].SortNum < images[j].SortNum
	})

	return images
}

// 安全获取图片宽高（失败返回0,0）
// TODO: 可优化效率, 只读文件头.	(有坑)
func getImageDimensionsSafe(filePath string) (int, int) {
	file, err := os.Open(filePath)
	if err != nil {
		return 0, 0
	}
	defer file.Close()

	cfg, _, err := image.DecodeConfig(file)
	if err != nil {
		return 0, 0
	}

	return cfg.Width, cfg.Height
}

// 排序章节目录（按目录名前缀数字排序）
func sortChapterDirs(dirs []os.DirEntry) []os.DirEntry {
	sorted := make([]os.DirEntry, len(dirs))
	copy(sorted, dirs)

	sort.Slice(sorted, func(i, j int) bool {
		return extractPrefixNumber(sorted[i].Name()) < extractPrefixNumber(sorted[j].Name())
	})

	return sorted
}

// 过滤有效图片并按文件名前缀排序
func filterAndSortImages(files []os.DirEntry) []os.DirEntry {
	var imageFiles []os.DirEntry
	extSet := make(map[string]bool)
	for _, ext := range strings.Split(supportImageExts, ",") {
		extSet[strings.ToLower(ext)] = true
	}

	// 过滤有效图片文件
	for _, file := range files {
		if file.IsDir() {
			continue
		}
		ext := strings.ToLower(filepath.Ext(file.Name()))
		if extSet[ext] {
			imageFiles = append(imageFiles, file)
		}
	}

	// 按文件名前缀数字排序
	sort.Slice(imageFiles, func(i, j int) bool {
		nameI := strings.TrimSuffix(imageFiles[i].Name(), filepath.Ext(imageFiles[i].Name()))
		nameJ := strings.TrimSuffix(imageFiles[j].Name(), filepath.Ext(imageFiles[j].Name()))
		return extractPrefixNumber(nameI) < extractPrefixNumber(nameJ)
	})

	return imageFiles
}

// 提取字符串前缀数字（用于排序）
func extractPrefixNumber(s string) int {
	var numStr string
	for _, c := range s {
		if c >= '0' && c <= '9' {
			numStr += string(c)
		} else {
			break
		}
	}
	if numStr == "" {
		return 999999 // 无数字前缀的目录排最后
	}
	num, _ := strconv.Atoi(numStr)
	return num
}

// 错误包装（统一错误格式）
func wrapError(msg string, err error) error {
	return fmt.Errorf("%s: %w", msg, err)
}
