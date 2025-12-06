package comics

import (
	"database/sql"
	"fmt"
	"time"

	"gizmos/internal/db"
)

// Storage 数据库操作封装
type Storage struct {
	db *sql.DB
}

// NewStorage 创建数据库存储实例
func NewStorage() (*Storage, error) {
	cfg := db.LoadConfigFromEnv()
	dbConn, err := db.NewPostgresDB(cfg)
	if err != nil {
		return nil, wrapError("数据库连接失败", err)
	}
	return &Storage{db: dbConn}, nil
}

// Close 关闭数据库连接
func (s *Storage) Close() error {
	return s.db.Close()
}

// ClearOldData 清空旧数据
func (s *Storage) ClearOldData() error {
	if _, err := s.db.Exec("DELETE FROM comics.comic_summary"); err != nil {
		return wrapError("删除汇总表失败", err)
	}
	if _, err := s.db.Exec("DELETE FROM comics.comic_books"); err != nil {
		return wrapError("删除漫画主表失败", err)
	}
	println("ℹ️  旧数据清空完成")
	return nil
}

// ========== 新增：查询已存在的章节（漫画名+章节目录名组合） ==========
func (s *Storage) GetExistingChapters() (map[string]struct{}, error) {
	// 存储格式："漫画名|章节目录名" → 空结构体（仅用于存在性判断）
	existing := make(map[string]struct{})

	query := `
		SELECT b.title, c.dir_name 
		FROM comics.comic_books b
		JOIN comics.comic_chapters c ON b.id = c.comic_id
	`

	rows, err := s.db.Query(query)
	if err != nil {
		return nil, wrapError("查询已存在章节失败", err)
	}
	defer rows.Close()

	for rows.Next() {
		var comicTitle, chapterDirName string
		if err := rows.Scan(&comicTitle, &chapterDirName); err != nil {
			return nil, wrapError("扫描已存在章节记录失败", err)
		}
		key := fmt.Sprintf("%s|%s", comicTitle, chapterDirName)
		existing[key] = struct{}{}
	}

	if err := rows.Err(); err != nil {
		return nil, wrapError("读取已存在章节结果失败", err)
	}

	return existing, nil
}

// ========== 修改：插入数据时跳过已存在的章节 ==========
func (s *Storage) InsertComicData(comicBooks []*ComicBook, existingChapters map[string]struct{}) (int, int, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return 0, 0, wrapError("开启事务失败", err)
	}
	defer tx.Rollback()

	insertedChapterCount := 0 // 新增章节数
	insertedImageCount := 0   // 新增图片数

	for _, comic := range comicBooks {
		comicInserted := false // 标记该漫画是否已插入（避免重复插入漫画主表）

		for _, chapter := range comic.Chapters {
			// 生成判断键：漫画名|章节目录名
			key := fmt.Sprintf("%s|%s", comic.Title, chapter.DirName)
			if _, exists := existingChapters[key]; exists {
				continue
			}

			// 如果漫画主表还未插入，先插入漫画主表
			if !comicInserted {
				if _, err := tx.Exec(`
					INSERT INTO comics.comic_books (id, title, chapter_count, image_count, cover_image)
					VALUES ($1, $2, $3, $4, $5)
				`, comic.ID, comic.Title, comic.ChapterCount, comic.ImageCount, comic.CoverImage); err != nil {
					return 0, 0, wrapError(fmt.Sprintf("插入漫画 [%s]", comic.Title), err)
				}
				comicInserted = true
				println(fmt.Sprintf("ℹ️  漫画 [%s] 主表插入成功", comic.Title))
			}

			// 插入章节表
			if _, err := tx.Exec(`
				INSERT INTO comics.comic_chapters (id, comic_id, dir_name, chapter_index, image_count)
				VALUES ($1, $2, $3, $4, $5)
			`, chapter.ID, chapter.ComicID, chapter.DirName, chapter.ChapterIndex, chapter.ImageCount); err != nil {
				return 0, 0, wrapError(fmt.Sprintf("插入章节 [%s/%s]", comic.Title, chapter.DirName), err)
			}

			// 插入图片表
			for _, image := range chapter.Images {
				if _, err := tx.Exec(`
					INSERT INTO comics.comic_images (id, chapter_id, image_path, sort_num, width, height)
					VALUES ($1, $2, $3, $4, $5, $6)
				`, image.ID, image.ChapterID, image.ImagePath, image.SortNum, image.Width, image.Height); err != nil {
					return 0, 0, wrapError(fmt.Sprintf("插入图片 [%s]", image.ImagePath), err)
				}
			}

			insertedChapterCount++
			insertedImageCount += chapter.ImageCount
		}
	}

	if err := tx.Commit(); err != nil {
		return 0, 0, wrapError("提交事务失败", err)
	}

	println(fmt.Sprintf("ℹ️  漫画数据插入完成，新增章节数：%d，新增图片数：%d", insertedChapterCount, insertedImageCount))
	return insertedChapterCount, insertedImageCount, nil
}

// ========== 修改：支持增量更新汇总信息 ==========
func (s *Storage) UpdateSummary(existingBookCount, existingChapterCount, existingImageCount int, newBookCount, newChapterCount, newImageCount int) error {
	// 计算总统计数 = 已有数量 + 新增数量
	totalBookCount := existingBookCount + newBookCount
	totalChapterCount := existingChapterCount + newChapterCount
	totalImageCount := existingImageCount + newImageCount

	_, err := s.db.Exec(`
		INSERT INTO comics.comic_summary (id, title, book_count, total_chapter_count, total_image_count, updated_at)
		VALUES ('comic_total_index', '漫画信息元数据', $1, $2, $3, $4)
		ON CONFLICT (id) DO UPDATE
		SET book_count = $1, total_chapter_count = $2, total_image_count = $3, updated_at = $4
	`, totalBookCount, totalChapterCount, totalImageCount, time.Now())
	if err != nil {
		return wrapError("插入汇总信息失败", err)
	}

	println(fmt.Sprintf("ℹ️  汇总信息更新完成：总漫画数=%d，总章节数=%d，总图片数=%d",
		totalBookCount, totalChapterCount, totalImageCount))
	return nil
}

// ========== 新增：查询当前汇总统计信息 ==========
func (s *Storage) GetCurrentSummary() (int, int, int, error) {
	var (
		bookCount         int
		totalChapterCount int
		totalImageCount   int
	)

	query := `
		SELECT book_count, total_chapter_count, total_image_count
		FROM comics.comic_summary
		WHERE id = 'comic_total_index'
	`

	err := s.db.QueryRow(query).Scan(&bookCount, &totalChapterCount, &totalImageCount)
	if err != nil {
		// 如果汇总记录不存在，返回0（首次执行场景）
		if err == sql.ErrNoRows {
			return 0, 0, 0, nil
		}
		return 0, 0, 0, wrapError("查询当前汇总信息失败", err)
	}

	return bookCount, totalChapterCount, totalImageCount, nil
}
