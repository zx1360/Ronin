// Package comic_repo 提供 Android 端"漫画"模块的只读查询与管理字段写入。
//
// 数据对象为 comix schema 中由爬虫维护的表/视图；本包不做爬虫操作。
package comic_repo

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// withPool 以默认超时的上下文执行查询，并传入全局连接池。
func withPool[T any](fn func(ctx context.Context, pool *pgxpool.Pool) (T, error)) (T, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return fn(ctx, db.GetPool())
}

// GetComicMetaData 读取漫画总计数元数据（实时聚合）。
func GetComicMetaData() (*model.ComicTotalMetaData, error) {
	return withPool(func(ctx context.Context, pool *pgxpool.Pool) (*model.ComicTotalMetaData, error) {
		var metadata model.ComicTotalMetaData
		err := pool.QueryRow(ctx, `
			SELECT
				(SELECT COUNT(*) FROM comix.comic_books),
				(SELECT COUNT(*) FROM comix.comic_chapters),
				(SELECT COUNT(*) FROM comix.comic_images)
		`).Scan(&metadata.BookCount, &metadata.TotalChapterCount, &metadata.TotalImageCount)
		if err != nil {
			return nil, fmt.Errorf("查询漫画总元数据失败: %w", err)
		}
		metadata.UpdatedAt = time.Now()
		return &metadata, nil
	})
}

// GetAllComicInfos 获取所有漫画的总览信息（章节数/图片数实时聚合）。
func GetAllComicInfos() ([]model.ComicInfo, error) {
	return withPool(func(ctx context.Context, pool *pgxpool.Pool) ([]model.ComicInfo, error) {
		rows, err := pool.Query(ctx, `
			SELECT
				b.id, b.title, b.cover_image, b.is_public, b.readed,
				COUNT(DISTINCT ch.id) AS chapter_count,
				COUNT(img.id)         AS image_count
			FROM comix.comic_books b
			LEFT JOIN comix.comic_chapters ch ON ch.comic_id = b.id
			LEFT JOIN comix.comic_images img ON img.chapter_id = ch.id
			GROUP BY b.id, b.title, b.cover_image, b.is_public, b.readed
			ORDER BY b.title
		`)
		if err != nil {
			return nil, fmt.Errorf("查询漫画元数据失败: %w", err)
		}
		defer rows.Close()

		var infos []model.ComicInfo
		for rows.Next() {
			var info model.ComicInfo
			if err := rows.Scan(&info.ID, &info.Title, &info.CoverImage,
				&info.IsPublic, &info.Readed,
				&info.ChapterCount, &info.ImageCount); err != nil {
				return nil, fmt.Errorf("扫描漫画数据失败: %w", err)
			}
			infos = append(infos, info)
		}
		if err := rows.Err(); err != nil {
			return nil, fmt.Errorf("迭代结果集失败: %w", err)
		}
		return infos, nil
	})
}

// GetChaptersWithComicId 获取指定漫画的章节列表（含每章图片数）。
func GetChaptersWithComicId(comicId string) ([]model.ChapterInfo, error) {
	return withPool(func(ctx context.Context, pool *pgxpool.Pool) ([]model.ChapterInfo, error) {
		rows, err := pool.Query(ctx, `
			SELECT ch.id, ch.comic_id, ch.dir_name, ch.chapter_index, COUNT(ci.id)
			FROM comix.comic_chapters ch
			LEFT JOIN comix.comic_images ci ON ci.chapter_id = ch.id
			WHERE ch.comic_id = $1
			GROUP BY ch.id, ch.comic_id, ch.dir_name, ch.chapter_index
			ORDER BY ch.chapter_index ASC
		`, comicId)
		if err != nil {
			return nil, fmt.Errorf("查询漫画下的章节信息失败: %w", err)
		}
		defer rows.Close()

		var chapters []model.ChapterInfo
		for rows.Next() {
			var chapter model.ChapterInfo
			if err := rows.Scan(&chapter.ID, &chapter.ComicID, &chapter.DirName,
				&chapter.ChapterIndex, &chapter.ImageCount); err != nil {
				return nil, fmt.Errorf("扫描章节数据失败: %w", err)
			}
			chapters = append(chapters, chapter)
		}
		if err := rows.Err(); err != nil {
			return nil, fmt.Errorf("迭代结果集失败: %w", err)
		}
		return chapters, nil
	})
}

// GetImagesWithChapterId 获取指定章节下的图片清单。
func GetImagesWithChapterId(chapterId string) ([]model.ImageInfo, error) {
	return withPool(func(ctx context.Context, pool *pgxpool.Pool) ([]model.ImageInfo, error) {
		rows, err := pool.Query(ctx,
			`SELECT image_path, width, height FROM comix.comic_images
			 WHERE chapter_id = $1 ORDER BY sort_num ASC`, chapterId)
		if err != nil {
			return nil, fmt.Errorf("查询章节下的图片信息失败: %w", err)
		}
		defer rows.Close()

		var images []model.ImageInfo
		for rows.Next() {
			var img model.ImageInfo
			if err := rows.Scan(&img.Path, &img.Width, &img.Height); err != nil {
				return nil, fmt.Errorf("扫描图片数据失败: %w", err)
			}
			images = append(images, img)
		}
		if err := rows.Err(); err != nil {
			return nil, fmt.Errorf("迭代结果集失败: %w", err)
		}
		return images, nil
	})
}

// GetComicAllChaptersAndImages 获取整部漫画的章节与图片（按章节号、图片序号升序）。
func GetComicAllChaptersAndImages(comicId string) (map[string]model.ChapterInfo, map[string][]model.ImageInfo, error) {
	type result struct {
		chapters map[string]model.ChapterInfo
		images   map[string][]model.ImageInfo
	}
	out, err := withPool(func(ctx context.Context, pool *pgxpool.Pool) (*result, error) {
		rows, err := pool.Query(ctx, `
			SELECT c.id, c.comic_id, c.dir_name, c.chapter_index, i.image_path, i.width, i.height
			FROM comix.comic_chapters c
			LEFT JOIN comix.comic_images i ON c.id = i.chapter_id
			WHERE c.comic_id = $1
			ORDER BY c.chapter_index ASC, i.sort_num ASC
		`, comicId)
		if err != nil {
			return nil, fmt.Errorf("关联查询章节和图片失败: %w", err)
		}
		defer rows.Close()

		res := &result{
			chapters: make(map[string]model.ChapterInfo),
			images:   make(map[string][]model.ImageInfo),
		}
		for rows.Next() {
			var (
				chapterId    string
				comicId      string
				dirName      string
				chapterIndex int
				imagePath    pgtype.Text
				width        pgtype.Int4
				height       pgtype.Int4
			)
			if err := rows.Scan(&chapterId, &comicId, &dirName, &chapterIndex,
				&imagePath, &width, &height); err != nil {
				return nil, fmt.Errorf("扫描章节图片数据失败: %w", err)
			}

			if _, exists := res.chapters[chapterId]; !exists {
				res.chapters[chapterId] = model.ChapterInfo{
					ID:           chapterId,
					ComicID:      comicId,
					DirName:      dirName,
					ChapterIndex: chapterIndex,
				}
			}
			if imagePath.Valid {
				res.images[chapterId] = append(res.images[chapterId], model.ImageInfo{
					Path:   imagePath.String,
					Width:  width.Int32,
					Height: height.Int32,
				})
			}
		}
		if err := rows.Err(); err != nil {
			return nil, fmt.Errorf("迭代章节图片结果集失败: %w", err)
		}

		for chapterId, chapter := range res.chapters {
			chapter.ImageCount = len(res.images[chapterId])
			res.chapters[chapterId] = chapter
		}
		return res, nil
	})
	if err != nil {
		return nil, nil, err
	}
	return out.chapters, out.images, nil
}

// UpdateComicMeta 更新漫画的 is_public / readed / cover_image（缺省字段表示不修改）。
func UpdateComicMeta(comicId string, req model.UpdateComicRequest) error {
	_, err := withPool(func(ctx context.Context, pool *pgxpool.Pool) (struct{}, error) {
		sets := []string{}
		args := []any{}
		add := func(column string, value any) {
			args = append(args, value)
			sets = append(sets, fmt.Sprintf("%s=$%d", column, len(args)))
		}
		if req.IsPublic != nil {
			add("is_public", *req.IsPublic)
		}
		if req.Readed != nil {
			add("readed", *req.Readed)
		}
		if req.CoverImage != nil {
			add("cover_image", *req.CoverImage)
		}
		if len(sets) == 0 {
			return struct{}{}, nil
		}

		args = append(args, comicId)
		query := fmt.Sprintf("UPDATE comix.comic_books SET %s WHERE id=$%d",
			strings.Join(sets, ", "), len(args))
		if _, err := pool.Exec(ctx, query, args...); err != nil {
			return struct{}{}, fmt.Errorf("更新漫画元数据失败: %w", err)
		}
		return struct{}{}, nil
	})
	return err
}

// DeleteComic 删除漫画及级联数据，返回标题与存储相对路径(rel_dir)供调用方清理文件。
//
// 两者都需要：legacy 资源的目录以标题命名（comics/{title}），爬虫登记的资源以主键
// 命名（comics/{comic_id}）；只用标题删目录会残留整本漫画文件。
func DeleteComic(comicId string) (title string, relDir string, err error) {
	type deleted struct{ title, relDir string }
	out, err := withPool(func(ctx context.Context, pool *pgxpool.Pool) (*deleted, error) {
		// rel_dir 为纯列，视图不暴露；用 id::text 与入参（text）比较以走 idx_comic_id_text
		var result deleted
		if err := pool.QueryRow(ctx,
			`SELECT title, rel_dir FROM comix.comic WHERE id::text = $1`, comicId,
		).Scan(&result.title, &result.relDir); err != nil {
			return nil, fmt.Errorf("查询漫画标题失败: %w", err)
		}

		// comic_images → comic_chapters → comic_books 均为 CASCADE 外键，删主表即可
		if _, err := pool.Exec(ctx, `DELETE FROM comix.comic_books WHERE id=$1`, comicId); err != nil {
			return nil, fmt.Errorf("删除漫画失败: %w", err)
		}
		return &result, nil
	})
	if err != nil {
		return "", "", err
	}
	return out.title, filepath.ToSlash(out.relDir), nil
}

// SyncReadedStatus 批量标记已读，并返回每本漫画的服务器章节总数（供客户端判断增量）。
func SyncReadedStatus(readedIds []string) (*model.SyncReadedResponse, error) {
	return withPool(func(ctx context.Context, pool *pgxpool.Pool) (*model.SyncReadedResponse, error) {
		resp := &model.SyncReadedResponse{NewChapters: make(map[string]int)}

		if len(readedIds) > 0 {
			tag, err := pool.Exec(ctx,
				`UPDATE comix.comic_books SET readed = TRUE WHERE id = ANY($1)`, readedIds)
			if err != nil {
				return nil, fmt.Errorf("批量更新已读状态失败: %w", err)
			}
			resp.UpdatedCount = int(tag.RowsAffected())
		}

		rows, err := pool.Query(ctx, `
			SELECT b.id, COUNT(ch.id)
			FROM comix.comic_books b
			LEFT JOIN comix.comic_chapters ch ON ch.comic_id = b.id
			GROUP BY b.id
		`)
		if err != nil {
			return nil, fmt.Errorf("查询漫画章节计数失败: %w", err)
		}
		defer rows.Close()

		for rows.Next() {
			var comicId string
			var count int
			if err := rows.Scan(&comicId, &count); err != nil {
				return nil, fmt.Errorf("扫描章节计数失败: %w", err)
			}
			resp.NewChapters[comicId] = count
		}
		if err := rows.Err(); err != nil {
			return nil, fmt.Errorf("迭代章节计数结果失败: %w", err)
		}
		return resp, nil
	})
}
