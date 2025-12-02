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

// InsertComicData 批量插入漫画数据（事务安全）
func (s *Storage) InsertComicData(comicBooks []*ComicBook) error {
	tx, err := s.db.Begin()
	if err != nil {
		return wrapError("开启事务失败", err)
	}
	defer tx.Rollback()

	for _, comic := range comicBooks {
		// 插入漫画主表
		if _, err := tx.Exec(`
			INSERT INTO comics.comic_books (id, title, chapter_count, image_count, cover_image)
			VALUES ($1, $2, $3, $4, $5)
		`, comic.ID, comic.Title, comic.ChapterCount, comic.ImageCount, comic.CoverImage); err != nil {
			return wrapError(fmt.Sprintf("插入漫画 [%s]", comic.Title), err)
		}

		// 插入章节表
		for _, chapter := range comic.Chapters {
			if _, err := tx.Exec(`
				INSERT INTO comics.comic_chapters (id, comic_id, dir_name, chapter_index, image_count)
				VALUES ($1, $2, $3, $4, $5)
			`, chapter.ID, chapter.ComicID, chapter.DirName, chapter.ChapterIndex, chapter.ImageCount); err != nil {
				return wrapError(fmt.Sprintf("插入章节 [%s]", chapter.DirName), err)
			}

			// 插入图片表
			for _, image := range chapter.Images {
				if _, err := tx.Exec(`
					INSERT INTO comics.comic_images (id, chapter_id, image_path, sort_num, width, height)
					VALUES ($1, $2, $3, $4, $5, $6)
				`, image.ID, image.ChapterID, image.ImagePath, image.SortNum, image.Width, image.Height); err != nil {
					return wrapError(fmt.Sprintf("插入图片 [%s]", image.ImagePath), err)
				}
			}
		}
	}

	if err := tx.Commit(); err != nil {
		return wrapError("提交事务失败", err)
	}

	println("ℹ️  漫画数据插入完成")
	return nil
}

// UpdateSummary 更新汇总信息
func (s *Storage) UpdateSummary(bookCount, totalChapterCount, totalImageCount int) error {
	_, err := s.db.Exec(`
		INSERT INTO comics.comic_summary (id, title, book_count, total_chapter_count, total_image_count, updated_at)
		VALUES ('comic_total_index', '漫画信息元数据', $1, $2, $3, $4)
		ON CONFLICT (id) DO UPDATE
		SET book_count = $1, total_chapter_count = $2, total_image_count = $3, updated_at = $4
	`, bookCount, totalChapterCount, totalImageCount, time.Now())
	if err != nil {
		return wrapError("插入汇总信息失败", err)
	}
	println("ℹ️  汇总信息更新完成")
	return nil
}
