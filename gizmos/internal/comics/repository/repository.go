package repository

// 数据持久化与查询

import (
	"context"
	"fmt"
	"time"

	"gizmos/internal/comics/model"
	"gizmos/internal/service/db"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ClearOldData 清空所有数据（全量重建用）
func ClearOldData() error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return clearOldData(ctx, db.GetPool())
}
func clearOldData(ctx context.Context, pool *pgxpool.Pool) error {
	query := `
    TRUNCATE TABLE comics.comic_summary;
    TRUNCATE TABLE comics.comic_images;
    TRUNCATE TABLE comics.comic_chapters cascade;
    TRUNCATE TABLE comics.comic_books cascade;
    `
	_, err := pool.Exec(ctx, query)
	if err != nil {
		return fmt.Errorf("清空旧数据失败: %w", err)
	}
	return nil
}

// GetExistingChapters 返回“漫画名|章节目录名”的集合（章节级增量用）
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
        join comics.comic_chapters c on b.id=c.comic_id
    `
	rows, err := pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("GetExistingChapters查询失败: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var title, dn string
		_ = rows.Scan(&title, &dn)
		existing[fmt.Sprintf("%s|%s", title, dn)] = struct{}{}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("GetExistingChapters查询失败: %w", err)
	}
	return existing, nil
}

// GetAllComicTitles 从数据库读取所有漫画标题
func GetAllComicTitles() (map[string]string, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	pool := db.GetPool()
	rows, err := pool.Query(ctx, `select id, title from comics.comic_books`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make(map[string]string)
	for rows.Next() {
		var id, title string
		_ = rows.Scan(&id, &title)
		out[title] = id
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

// InsertComicData 插入漫画数据（跳过已存在章节）
func InsertComicData(comicBooks []*model.ComicBook, existingChapters map[string]struct{}) (int, int, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return insertComicData(ctx, db.GetPool(), comicBooks, existingChapters)
}
func insertComicData(ctx context.Context, pool *pgxpool.Pool, comicBooks []*model.ComicBook, existingChapters map[string]struct{}) (int, int, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return 0, 0, fmt.Errorf("开启事务失败: %w", err)
	}
	var txErr error
	defer func() {
		if r := recover(); r != nil {
			_ = tx.Rollback(ctx)
			txErr = fmt.Errorf("panic: %v", r)
		} else if txErr != nil {
			_ = tx.Rollback(ctx)
		}
	}()

	insertedChapter := 0
	insertedImage := 0

	for _, comic := range comicBooks {
		comicInserted := false
		for _, chapter := range comic.Chapters {
			key := fmt.Sprintf("%s|%s", comic.Title, chapter.DirName)
			if _, exists := existingChapters[key]; exists {
				continue
			}

			if !comicInserted {
				if _, err := tx.Exec(ctx, `
                    INSERT INTO comics.comic_books (id, title, chapter_count, image_count, cover_image)
                    VALUES ($1, $2, $3, $4, $5)
                `, comic.ID, comic.Title, comic.ChapterCount, comic.ImageCount, comic.CoverImage); err != nil {
					return 0, 0, wrapErr(fmt.Errorf("插入漫画[%s]失败: %w", comic.Title, err))
				}
				comicInserted = true
				println(fmt.Sprintf("ℹ️  漫画 [%s] 主表插入成功", comic.Title))
			}

			if _, err := tx.Exec(ctx, `
                INSERT INTO comics.comic_chapters (id, comic_id, dir_name, chapter_index, image_count)
                VALUES ($1, $2, $3, $4, $5)
            `, chapter.ID, chapter.ComicID, chapter.DirName, chapter.ChapterIndex, chapter.ImageCount); err != nil {
				return 0, 0, wrapErr(fmt.Errorf("插入章节[%s/%s]失败: %w", comic.Title, chapter.DirName, err))
			}

			for _, image := range chapter.Images {
				if _, err := tx.Exec(ctx, `
                    INSERT INTO comics.comic_images (id, chapter_id, image_path, sort_num, width, height)
                    VALUES ($1, $2, $3, $4, $5, $6)
                `, image.ID, image.ChapterID, image.ImagePath, image.SortNum, image.Width, image.Height); err != nil {
					return 0, 0, wrapErr(fmt.Errorf("插入图片[%s]失败: %w", image.ImagePath, err))
				}
			}

			insertedChapter++
			insertedImage += chapter.ImageCount
		}
	}

	if ctx.Err() != nil {
		txErr = fmt.Errorf("上下文超时: %w", ctx.Err())
		return 0, 0, txErr
	}
	if err := tx.Commit(ctx); err != nil {
		txErr = wrapErr(fmt.Errorf("提交事务失败: %w", err))
		return 0, 0, txErr
	}
	println(fmt.Sprintf("ℹ️  漫画数据插入完成，新增章节数：%d，新增图片数：%d", insertedChapter, insertedImage))
	return insertedChapter, insertedImage, nil
}

// InsertAllComics 不跳过，直接插入给定漫画数据
func InsertAllComics(comicBooks []*model.ComicBook) (int, int, error) {
	empty := make(map[string]struct{})
	return InsertComicData(comicBooks, empty)
}

// UpdateSummary 写入/更新汇总
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
		return wrapErr(fmt.Errorf("插入汇总信息失败: %w", err))
	}
	println(fmt.Sprintf("ℹ️  汇总信息更新完成：总漫画数=%d，总章节数=%d，总图片数=%d", totalBookCount, totalChapterCount, totalImageCount))
	return nil
}

// GetCurrentSummary 读取当前汇总（若无返回 0 值）
func GetCurrentSummary() (int, int, int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getCurrentSummary(ctx, db.GetPool())
}
func getCurrentSummary(ctx context.Context, pool *pgxpool.Pool) (int, int, int, error) {
	var bookCount, totalChapterCount, totalImageCount int
	err := pool.QueryRow(ctx, `
        SELECT book_count, total_chapter_count, total_image_count
        FROM comics.comic_summary WHERE id = 'comic_total_index'`).Scan(&bookCount, &totalChapterCount, &totalImageCount)
	if err != nil {
		if err == pgx.ErrNoRows {
			return 0, 0, 0, nil
		}
		return 0, 0, 0, wrapErr(fmt.Errorf("查询当前汇总信息失败: %w", err))
	}
	return bookCount, totalChapterCount, totalImageCount, nil
}

// AggregateCountsFromDB 直接从库中汇总（刷新后更稳妥）
func AggregateCountsFromDB() (int, int, int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	pool := db.GetPool()
	var bookCount int
	if err := pool.QueryRow(ctx, `select count(1) from comics.comic_books`).Scan(&bookCount); err != nil {
		return 0, 0, 0, err
	}
	var chapterSum int
	if err := pool.QueryRow(ctx, `select coalesce(sum(chapter_count),0) from comics.comic_books`).Scan(&chapterSum); err != nil {
		return 0, 0, 0, err
	}
	var imageSum int
	if err := pool.QueryRow(ctx, `select coalesce(sum(image_count),0) from comics.comic_books`).Scan(&imageSum); err != nil {
		return 0, 0, 0, err
	}
	return bookCount, chapterSum, imageSum, nil
}

// --- 刷新更新相关 ---

// GetChaptersByTitle 返回某漫画的章节: dir_name -> (chapter_id, image_count)
func GetChaptersByTitle(title string) (map[string]struct {
	ID         string
	ImageCount int
}, string, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	pool := db.GetPool()

	var comicID string
	err := pool.QueryRow(ctx, `select id from comics.comic_books where title=$1`, title).Scan(&comicID)
	if err != nil {
		return nil, "", err
	}

	rows, err := pool.Query(ctx, `select id, dir_name, image_count from comics.comic_chapters where comic_id=$1`, comicID)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()
	out := make(map[string]struct {
		ID         string
		ImageCount int
	})
	for rows.Next() {
		var id, dir string
		var cnt int
		_ = rows.Scan(&id, &dir, &cnt)
		out[dir] = struct {
			ID         string
			ImageCount int
		}{ID: id, ImageCount: cnt}
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}
	return out, comicID, nil
}

// DeleteComicsByTitles 硬删除整本漫画（级联删章节与图片）
func DeleteComicsByTitles(titles []string) error {
	if len(titles) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	pool := db.GetPool()
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	var txErr error
	defer func() {
		if txErr != nil {
			_ = tx.Rollback(ctx)
		} else {
			_ = tx.Commit(ctx)
		}
	}()
	for _, t := range titles {
		if _, err := tx.Exec(ctx, `delete from comics.comic_books where title=$1`, t); err != nil {
			txErr = err
			return txErr
		}
	}
	return nil
}

// DeleteChapterByID 删除章节（级联删图片）
func DeleteChapterByID(chapterID string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	_, err := db.GetPool().Exec(ctx, `delete from comics.comic_chapters where id=$1`, chapterID)
	return err
}

// ReplaceChapterImages 用新列表替换章节图片，并更新计数
func ReplaceChapterImages(chapterID string, images []model.ComicImage) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	pool := db.GetPool()
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	var txErr error
	defer func() {
		if txErr != nil {
			_ = tx.Rollback(ctx)
		} else {
			_ = tx.Commit(ctx)
		}
	}()

	if _, err := tx.Exec(ctx, `delete from comics.comic_images where chapter_id=$1`, chapterID); err != nil {
		txErr = err
		return txErr
	}
	for _, img := range images {
		if _, err := tx.Exec(ctx, `
            insert into comics.comic_images (id, chapter_id, image_path, sort_num, width, height)
            values ($1,$2,$3,$4,$5,$6)
        `, img.ID, chapterID, img.ImagePath, img.SortNum, img.Width, img.Height); err != nil {
			txErr = err
			return txErr
		}
	}
	if _, err := tx.Exec(ctx, `update comics.comic_chapters set image_count=$1 where id=$2`, len(images), chapterID); err != nil {
		txErr = err
		return txErr
	}
	return nil
}

// InsertChapterWithImages 插入新章节与图片
func InsertChapterWithImages(comicID string, chapter model.ComicChapter) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	pool := db.GetPool()
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	var txErr error
	defer func() {
		if txErr != nil {
			_ = tx.Rollback(ctx)
		} else {
			_ = tx.Commit(ctx)
		}
	}()

	if _, err := tx.Exec(ctx, `
        insert into comics.comic_chapters (id, comic_id, dir_name, chapter_index, image_count)
        values ($1,$2,$3,$4,$5)
    `, chapter.ID, comicID, chapter.DirName, chapter.ChapterIndex, chapter.ImageCount); err != nil {
		txErr = err
		return txErr
	}

	for _, img := range chapter.Images {
		if _, err := tx.Exec(ctx, `
            insert into comics.comic_images (id, chapter_id, image_path, sort_num, width, height)
            values ($1,$2,$3,$4,$5,$6)
        `, img.ID, chapter.ID, img.ImagePath, img.SortNum, img.Width, img.Height); err != nil {
			txErr = err
			return txErr
		}
	}
	return nil
}

// UpdateBookAggregates 更新漫画聚合字段
func UpdateBookAggregates(comicID string, chapterCount, imageCount int, coverImage string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	_, err := db.GetPool().Exec(ctx, `
        update comics.comic_books set chapter_count=$1, image_count=$2, cover_image=$3 where id=$4
    `, chapterCount, imageCount, coverImage, comicID)
	return err
}

func wrapErr(err error) error { return err }
