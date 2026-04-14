package scanner

// 目录扫描：按模式最小必要扫描

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

	"gizmos/internal/comics/model"
)

const (
	supportImageExts = ".jpg,.jpeg,.png,.gif"
	maxConcurrency   = 32
)

// ScanFull 扫描根目录（漫画->章节->图片）
func ScanFull(root string) ([]*model.ComicBook, int, int, error) {
	var comicBooks []*model.ComicBook
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

		comic := model.NewComicBook(comicDir.Name())
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
			chapter := model.NewComicChapter(comic.ID, dirName, chapterIndex)
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

			images := readImageMetadata(chapter.ID, chapterPath, sortedImageFiles)
			chapter.Images = images
			chapter.ImageCount = len(images)

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

// ListComicTitles 仅列出漫画目录名
func ListComicTitles(root string) ([]string, error) {
	dirs, err := os.ReadDir(root)
	if err != nil {
		return nil, wrapError("读取根目录失败", err)
	}
	var titles []string
	for _, d := range dirs {
		if d.IsDir() {
			titles = append(titles, d.Name())
		}
	}
	sort.Strings(titles)
	return titles, nil
}

// ScanComicsByTitles 扫描指定的漫画（深入章节与图片）
func ScanComicsByTitles(root string, titles []string) ([]*model.ComicBook, int, int, error) {
	if len(titles) == 0 {
		return []*model.ComicBook{}, 0, 0, nil
	}
	totalCh := 0
	totalImg := 0
	var out []*model.ComicBook
	for _, title := range titles {
		comic := model.NewComicBook(title)
		comicPath := filepath.Join(root, title)
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
			chapter := model.NewComicChapter(comic.ID, dirName, chapterIndex)
			chapterPath := filepath.Join(comicPath, dirName)
			imageFiles, err := os.ReadDir(chapterPath)
			if err != nil {
				println("⚠️  读取章节目录", chapterPath, "失败，跳过:", err)
				continue
			}
			sortedImageFiles := filterAndSortImages(imageFiles)
			if len(sortedImageFiles) == 0 {
				continue
			}
			images := readImageMetadata(chapter.ID, chapterPath, sortedImageFiles)
			chapter.Images = images
			chapter.ImageCount = len(images)
			if idx == 0 && len(images) > 0 {
				comic.CoverImage = images[0].ImagePath
			}
			comic.Chapters = append(comic.Chapters, *chapter)
			comic.ChapterCount++
			comicTotalImages += chapter.ImageCount
			totalImg += chapter.ImageCount
		}
		if comic.ChapterCount == 0 {
			continue
		}
		comic.ImageCount = comicTotalImages
		out = append(out, comic)
		totalCh += comic.ChapterCount
	}
	return out, totalCh, totalImg, nil
}

// ScanChaptersForComic 列出某漫画的章节与图片
func ScanChaptersForComic(root, title string) (*model.ComicBook, error) {
	res, _, _, err := ScanComicsByTitles(root, []string{title})
	if err != nil {
		return nil, err
	}
	if len(res) == 0 {
		return nil, nil
	}
	return res[0], nil
}

// --- helpers ---

func readImageMetadata(chapterID, chapterPath string, imageFiles []os.DirEntry) []model.ComicImage {
	var (
		images    []model.ComicImage
		wg        sync.WaitGroup
		semaphore = make(chan struct{}, maxConcurrency)
		mu        sync.Mutex
	)

	imageCount := len(imageFiles)
	wg.Add(imageCount)

	for imgIdx, imgFile := range imageFiles {
		go func(imgIdx int, imgFile os.DirEntry) {
			defer wg.Done()
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			imgFullPath := filepath.Join(chapterPath, imgFile.Name())
			relPath := toStaticRelative(imgFullPath)
			width, height := getImageDimensionsSafe(imgFullPath)

			mu.Lock()
			images = append(images, *model.NewComicImage(
				chapterID, relPath, imgIdx+1, width, height,
			))
			mu.Unlock()
		}(imgIdx, imgFile)
	}

	wg.Wait()
	sort.Slice(images, func(i, j int) bool { return images[i].SortNum < images[j].SortNum })
	return images
}

func toStaticRelative(full string) string {
	// 将路径裁剪到 static 目录下的相对路径，并统一为 "/"
	norm := strings.ReplaceAll(full, "\\", "/")
	idx := strings.Index(norm, "/static/")
	if idx >= 0 {
		return norm[idx+len("/static/"):]
	}
	// 兜底：返回文件名相对路径
	return filepath.Base(full)
}

func getImageDimensionsSafe(filePath string) (int, int) {
	f, err := os.Open(filePath)
	if err != nil {
		return 0, 0
	}
	defer f.Close()
	cfg, _, err := image.DecodeConfig(f)
	if err != nil {
		return 0, 0
	}
	return cfg.Width, cfg.Height
}

func sortChapterDirs(dirs []os.DirEntry) []os.DirEntry {
	sorted := make([]os.DirEntry, len(dirs))
	copy(sorted, dirs)
	sort.Slice(sorted, func(i, j int) bool {
		return extractPrefixNumber(sorted[i].Name()) < extractPrefixNumber(sorted[j].Name())
	})
	return sorted
}

func filterAndSortImages(files []os.DirEntry) []os.DirEntry {
	var imageFiles []os.DirEntry
	extSet := make(map[string]bool)
	for _, ext := range strings.Split(supportImageExts, ",") {
		extSet[strings.ToLower(ext)] = true
	}
	for _, file := range files {
		if file.IsDir() {
			continue
		}
		ext := strings.ToLower(filepath.Ext(file.Name()))
		if extSet[ext] {
			imageFiles = append(imageFiles, file)
		}
	}
	sort.Slice(imageFiles, func(i, j int) bool {
		nameI := strings.TrimSuffix(imageFiles[i].Name(), filepath.Ext(imageFiles[i].Name()))
		nameJ := strings.TrimSuffix(imageFiles[j].Name(), filepath.Ext(imageFiles[j].Name()))
		return extractPrefixNumber(nameI) < extractPrefixNumber(nameJ)
	})
	return imageFiles
}

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
		return 999999
	}
	n, _ := strconv.Atoi(numStr)
	return n
}

func wrapError(msg string, err error) error { return fmt.Errorf("%s: %w", msg, err) }
