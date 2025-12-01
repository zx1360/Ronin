package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v4/pgxpool"
	_ "github.com/lib/pq"
)

// ==================== 配置项（请根据实际环境修改）====================
const (
	// PostgreSQL 连接信息（替换为你的数据库配置）
	pgConnStr = "host=localhost port=5432 user=postgres password=K9$pQ3!zX7&rT2*wV5 dbname=monarch sslmode=disable"
	// 漫画根目录（Windows 示例："D:\\comics"，Linux/Mac 示例："/comics"）
	comicRoot = "D:\\products\\Go\\monarch\\static\\comics"
	// 支持的图片格式（可添加 png、jpeg 等）
	supportImageExts = ".jpg,.jpeg,.png,.gif"
)

// ==================== 数据库模型定义（完整嵌套结构）====================
type ComicImage struct {
	ID        string
	ChapterID string
	ImagePath string
	SortNum   int
	CreatedAt time.Time
}

type ComicChapter struct {
	ID         string
	ComicID    string
	Title      string
	DirName    string
	ImageCount int
	Images     []ComicImage
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type ComicBook struct {
	ID           string
	Title        string
	ChapterCount int
	Chapters     []ComicChapter
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

type ComicSummary struct {
	ID                string
	Title             string
	BookCount         int
	TotalChapterCount int
	TotalImageCount   int
	UpdatedAt         time.Time
}

// ==================== 主函数（程序入口）====================
func main() {
	// 1. 初始化数据库连接池
	pool, err := pgxpool.Connect(context.Background(), pgConnStr)
	if err != nil {
		fmt.Printf("❌ 数据库连接失败: %v\n", err)
		return
	}
	defer pool.Close()

	// 测试数据库连接
	if err := pool.Ping(context.Background()); err != nil {
		fmt.Printf("❌ 数据库 Ping 失败: %v\n", err)
		return
	}
	fmt.Println("✅ 数据库连接成功")

	// 2. 扫描漫画目录，收集元数据
	fmt.Printf("🔍 开始扫描漫画目录: %s\n", comicRoot)
	comicBooks, totalChapterCount, totalImageCount, err := scanComicDir(comicRoot)
	if err != nil {
		fmt.Printf("❌ 扫描漫画目录失败: %v\n", err)
		return
	}
	bookCount := len(comicBooks)
	fmt.Printf("✅ 扫描完成：共 %d 本漫画，%d 个章节，%d 张图片\n", bookCount, totalChapterCount, totalImageCount)

	// 3. 清空旧数据（如需保留历史数据，注释此行）
	if err := clearOldData(pool); err != nil {
		fmt.Printf("❌ 清空旧数据失败: %v\n", err)
		return
	}

	// 4. 批量插入数据到数据库
	if err := insertComicData(pool, comicBooks); err != nil {
		fmt.Printf("❌ 插入漫画数据失败: %v\n", err)
		return
	}

	// 5. 更新汇总信息
	if err := updateComicSummary(pool, bookCount, totalChapterCount, totalImageCount); err != nil {
		fmt.Printf("❌ 更新汇总信息失败: %v\n", err)
		return
	}

	fmt.Println("🎉 所有漫画元数据已成功存入数据库！")
}

// ==================== 目录扫描相关函数 ====================
// scanComicDir 扫描漫画根目录，递归收集所有漫画、章节、图片信息
func scanComicDir(root string) ([]ComicBook, int, int, error) {
	var comicBooks []ComicBook
	totalChapterCount := 0
	totalImageCount := 0

	// 读取根目录下的所有漫画目录（一级目录 = 漫画名）
	comicDirs, err := os.ReadDir(root)
	if err != nil {
		return nil, 0, 0, fmt.Errorf("读取根目录失败: %w", err)
	}

	// 遍历每本漫画目录
	for _, comicDir := range comicDirs {
		if !comicDir.IsDir() {
			continue // 跳过非目录文件
		}

		comicTitle := comicDir.Name()
		comicID := uuid.NewString()
		comicPath := filepath.Join(root, comicTitle)
		fmt.Printf("📚 处理漫画: %s\n", comicTitle)

		// 读取漫画目录下的章节目录（二级目录 = 章节，格式：001_章节名）
		chapterDirs, err := os.ReadDir(comicPath)
		if err != nil {
			fmt.Printf("⚠️  读取漫画目录 %s 失败，跳过: %v\n", comicPath, err)
			continue
		}

		// 章节目录排序（按前缀数字升序）
		sortedChapterDirs := sortChapterDirs(chapterDirs)
		var chapters []ComicChapter
		chapterCount := 0

		// 遍历每个章节
		for _, chapterDir := range sortedChapterDirs {
			if !chapterDir.IsDir() {
				continue // 跳过非目录文件
			}

			chapterDirName := chapterDir.Name()
			chapterTitle := parseChapterTitle(chapterDirName)
			chapterID := uuid.NewString()
			chapterPath := filepath.Join(comicPath, chapterDirName)

			// 读取章节下的图片文件
			imageFiles, err := os.ReadDir(chapterPath)
			if err != nil {
				fmt.Printf("⚠️  读取章节目录 %s 失败，跳过: %v\n", chapterPath, err)
				continue
			}

			// 筛选支持的图片格式并排序
			sortedImageFiles := filterAndSortImages(imageFiles)
			if len(sortedImageFiles) == 0 {
				fmt.Printf("⚠️  章节目录 %s 无有效图片，跳过\n", chapterDirName)
				continue
			}

			// 收集图片信息
			var images []ComicImage
			imageCount := len(sortedImageFiles)
			for idx, imgFile := range sortedImageFiles {
				imgPath := strings.Split(filepath.Join(chapterPath, imgFile.Name()), "static\\")[1] // 存储相对路径
				images = append(images, ComicImage{
					ID:        uuid.NewString(),
					ChapterID: chapterID,
					ImagePath: imgPath,
					SortNum:   idx + 1, // 排序号（1开始）
					CreatedAt: time.Now(),
				})
			}

			// 添加章节信息
			chapters = append(chapters, ComicChapter{
				ID:         chapterID,
				ComicID:    comicID,
				Title:      chapterTitle,
				DirName:    chapterDirName,
				ImageCount: imageCount,
				Images:     images,
				CreatedAt:  time.Now(),
				UpdatedAt:  time.Now(),
			})

			chapterCount++
			totalImageCount += imageCount
			fmt.Printf("  ├─ 章节: %s (图片数: %d)\n", chapterTitle, imageCount)
		}

		// 跳过无有效章节的漫画
		if chapterCount == 0 {
			fmt.Printf("⚠️  漫画 %s 无有效章节，跳过\n", comicTitle)
			continue
		}

		// 添加漫画信息
		comicBooks = append(comicBooks, ComicBook{
			ID:           comicID,
			Title:        comicTitle,
			ChapterCount: chapterCount,
			Chapters:     chapters,
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		})
		totalChapterCount += chapterCount
	}

	return comicBooks, totalChapterCount, totalImageCount, nil
}

// sortChapterDirs 章节目录排序（按目录名前缀数字升序，如 001_xxx < 002_xxx）
func sortChapterDirs(dirs []os.DirEntry) []os.DirEntry {
	sorted := make([]os.DirEntry, len(dirs))
	copy(sorted, dirs)

	sort.Slice(sorted, func(i, j int) bool {
		numI := extractPrefixNumber(sorted[i].Name())
		numJ := extractPrefixNumber(sorted[j].Name())
		return numI < numJ
	})

	return sorted
}

// filterAndSortImages 筛选支持的图片格式，并按文件名数字排序
func filterAndSortImages(files []os.DirEntry) []os.DirEntry {
	var imageFiles []os.DirEntry
	extSet := make(map[string]bool)
	for _, ext := range strings.Split(supportImageExts, ",") {
		extSet[strings.ToLower(ext)] = true
	}

	// 筛选支持的图片文件
	for _, file := range files {
		if file.IsDir() {
			continue
		}
		ext := strings.ToLower(filepath.Ext(file.Name()))
		if extSet[ext] {
			imageFiles = append(imageFiles, file)
		}
	}

	// 按文件名数字排序（如 1.jpg < 2.jpg < 10.jpg）
	sort.Slice(imageFiles, func(i, j int) bool {
		nameI := strings.TrimSuffix(imageFiles[i].Name(), filepath.Ext(imageFiles[i].Name()))
		nameJ := strings.TrimSuffix(imageFiles[j].Name(), filepath.Ext(imageFiles[j].Name()))
		numI := extractPrefixNumber(nameI)
		numJ := extractPrefixNumber(nameJ)
		return numI < numJ
	})

	return imageFiles
}

// extractPrefixNumber 提取字符串前缀的数字（无数字返回 999999，确保排在后面）
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
	num, _ := strconv.Atoi(numStr)
	return num
}

// parseChapterTitle 从章节目录名解析章节标题（如 "001_预告" -> "预告"）
func parseChapterTitle(dirName string) string {
	parts := strings.SplitN(dirName, "_", 2)
	if len(parts) == 2 && parts[1] != "" {
		return parts[1]
	}
	return dirName // 无下划线时直接使用目录名
}

// ==================== 数据库操作相关函数 ====================
// clearOldData 清空旧数据（级联删除，漫画主表删除后章节和图片自动删除）
func clearOldData(pool *pgxpool.Pool) error {
	ctx := context.Background()

	// 删除汇总表
	_, err := pool.Exec(ctx, "DELETE FROM comics.comic_summary")
	if err != nil {
		return fmt.Errorf("删除汇总表失败: %w", err)
	}

	// 删除漫画主表（级联删除章节和图片）
	_, err = pool.Exec(ctx, "DELETE FROM comics.comic_books")
	if err != nil {
		return fmt.Errorf("删除漫画主表失败: %w", err)
	}

	fmt.Println("ℹ️  旧数据清空完成")
	return nil
}

// insertComicData 批量插入漫画、章节、图片数据（事务保证一致性）
func insertComicData(pool *pgxpool.Pool, comicBooks []ComicBook) error {
	ctx := context.Background()

	// 开启事务
	tx, err := pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx) // 异常回滚

	// 遍历插入每本漫画
	for _, comic := range comicBooks {
		// 插入漫画主表
		_, err := tx.Exec(ctx, `
			INSERT INTO comics.comic_books (id, title, chapter_count, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5)
		`, comic.ID, comic.Title, comic.ChapterCount, comic.CreatedAt, comic.UpdatedAt)
		if err != nil {
			return fmt.Errorf("插入漫画 [%s] 失败: %w", comic.Title, err)
		}

		// 插入该漫画的所有章节
		for _, chapter := range comic.Chapters {
			_, err := tx.Exec(ctx, `
				INSERT INTO comics.comic_chapters (id, comic_id, title, dir_name, image_count, created_at, updated_at)
				VALUES ($1, $2, $3, $4, $5, $6, $7)
			`, chapter.ID, chapter.ComicID, chapter.Title, chapter.DirName, chapter.ImageCount, chapter.CreatedAt, chapter.UpdatedAt)
			if err != nil {
				return fmt.Errorf("插入章节 [%s] 失败: %w", chapter.Title, err)
			}

			// 插入该章节的所有图片
			for _, image := range chapter.Images {
				_, err := tx.Exec(ctx, `
					INSERT INTO comics.comic_images (id, chapter_id, image_path, sort_num, created_at)
					VALUES ($1, $2, $3, $4, $5)
				`, image.ID, image.ChapterID, image.ImagePath, image.SortNum, image.CreatedAt)
				if err != nil {
					return fmt.Errorf("插入图片 [%s] 失败: %w", image.ImagePath, err)
				}
			}
		}
	}

	// 提交事务
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("提交事务失败: %w", err)
	}

	fmt.Println("ℹ️  漫画数据插入完成")
	return nil
}

// updateComicSummary 更新汇总表（存在则更新，不存在则插入）
func updateComicSummary(pool *pgxpool.Pool, bookCount, totalChapterCount, totalImageCount int) error {
	ctx := context.Background()

	_, err := pool.Exec(ctx, `
		INSERT INTO comics.comic_summary (id, title, book_count, total_chapter_count, total_image_count, updated_at)
		VALUES ('comic_total_index', '我的所有漫画', $1, $2, $3, $4)
		ON CONFLICT (id) DO UPDATE
		SET book_count = $1, total_chapter_count = $2, total_image_count = $3, updated_at = $4
	`, bookCount, totalChapterCount, totalImageCount, time.Now())

	if err != nil {
		return fmt.Errorf("插入汇总信息失败: %w", err)
	}

	fmt.Println("ℹ️  汇总信息更新完成")
	return nil
}
