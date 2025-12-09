package comics

import (
	"context"
	"fmt"
	"time"

	"gizmos/internal/service/db"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ClearOldData 清空所有旧数据
func ClearOldData() error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return clearOldData(ctx, db.GetPool())
}
func clearOldData(ctx context.Context, pool *pgxpool.Pool) error {
	query := `
	TRUNCATE TABLE comic_summary;
	TRUNCATE TABLE comic_images;
	TRUNCATE TABLE comic_chapters cascade;
	TRUNCATE TABLE comic_books cascade;
	`
	_, err := pool.Exec(ctx, query)
	if err != nil {
		return fmt.Errorf("清空旧数据失败: %w", err)
	}
	return nil
}

// ========== 新增：查询已存在的章节（漫画名+章节目录名组合） ==========
// GetExistingChapters查询已存在的章节
func GetExistingChapters() (map[string]struct{}, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getExistingChapters(ctx, db.GetPool())
}
func getExistingChapters(ctx context.Context, pool *pgxpool.Pool) (map[string]struct{}, error) {
	existing := make(map[string]struct{})
	query := `
		select b.title, c.dir_name
		from comics.comic_books b
		join comics.comic_chapters c
		on b.id=c.comic_id
	`
	rows, err := pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("GetExistingChapters查询失败: %w", err)
	}
	for rows.Next() {
		var comicTitle, chapterDirName string
		rows.Scan(&comicTitle, &chapterDirName)
		key := fmt.Sprintf("%s|%s", comicTitle, chapterDirName)
		existing[key] = struct{}{}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("GetExistingChapters查询失败: %w", err)
	}
	return existing, nil
}

// InsertComicData插入数据时跳过已存在的章节
func InsertComicData(comicBooks []*ComicBook, existingChapters map[string]struct{}) (int, int, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return insertComicData(ctx, db.GetPool(), comicBooks, existingChapters)
}
func insertComicData(ctx context.Context, pool *pgxpool.Pool, comicBooks []*ComicBook, existingChapters map[string]struct{}) (int, int, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return 0, 0, fmt.Errorf("开启事务失败: %w", err)
	}
	// 未成功提交(panic或业务错误), 事务回滚
	var txErr error
	defer func() {
		if r := recover(); r != nil {
			_ = tx.Rollback(ctx)
			txErr = fmt.Errorf("panic: %v", r)
		} else if txErr != nil {
			_ = tx.Rollback(ctx)
		}
	}()

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
				if _, err := tx.Exec(ctx, `
					INSERT INTO comics.comic_books (id, title, chapter_count, image_count, cover_image)
					VALUES ($1, $2, $3, $4, $5)
				`, comic.ID, comic.Title, comic.ChapterCount, comic.ImageCount, comic.CoverImage); err != nil {
					return 0, 0, wrapError(fmt.Sprintf("插入漫画 [%s]", comic.Title), err)
				}
				comicInserted = true
				println(fmt.Sprintf("ℹ️  漫画 [%s] 主表插入成功", comic.Title))
			}

			// 插入章节表
			if _, err := tx.Exec(ctx, `
				INSERT INTO comics.comic_chapters (id, comic_id, dir_name, chapter_index, image_count)
				VALUES ($1, $2, $3, $4, $5)
			`, chapter.ID, chapter.ComicID, chapter.DirName, chapter.ChapterIndex, chapter.ImageCount); err != nil {
				return 0, 0, wrapError(fmt.Sprintf("插入章节 [%s/%s]", comic.Title, chapter.DirName), err)
			}

			// 插入图片表
			for _, image := range chapter.Images {
				if _, err := tx.Exec(ctx, `
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

	if ctx.Err() != nil {
		txErr = fmt.Errorf("上下文超时: %w", ctx.Err())
		return 0, 0, txErr
	}
	// 提交事务
	if err := tx.Commit(ctx); err != nil {
		txErr = wrapError("提交事务失败", err)
		return 0, 0, txErr
	}

	println(fmt.Sprintf("ℹ️  漫画数据插入完成，新增章节数：%d，新增图片数：%d", insertedChapterCount, insertedImageCount))
	return insertedChapterCount, insertedImageCount, nil
}

// UpdateSummary支持增量更新汇总信息
func UpdateSummary(totalBookCount, totalChapterCount, totalImageCount int) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return updateSummary(ctx, db.GetPool(), totalBookCount, totalChapterCount, totalImageCount)
}
func updateSummary(ctx context.Context, pool *pgxpool.Pool, totalBookCount, totalChapterCount, totalImageCount int) error {
	_, err := pool.Exec(ctx, `
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

// GetCurrentSummary查询当前汇总统计信息
func GetCurrentSummary() (int, int, int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getCurrentSummary(ctx, db.GetPool())
}
func getCurrentSummary(ctx context.Context, pool *pgxpool.Pool) (int, int, int, error) {
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

	err := pool.QueryRow(ctx, query).Scan(&bookCount, &totalChapterCount, &totalImageCount)
	if err != nil {
		// 如果汇总记录不存在，返回0（首次执行场景）
		if err == pgx.ErrNoRows {
			return 0, 0, 0, nil
		}
		return 0, 0, 0, wrapError("查询当前汇总信息失败", err)
	}

	return bookCount, totalChapterCount, totalImageCount, nil
}
