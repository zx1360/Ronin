// Package comic_repo 提供 Android 端"漫画"模块的只读查询与管理字段写入。
//
// 数据对象为 comix 侧由爬虫维护的表（comics / comic_chapters / comic_images）；
// 本包不做爬虫操作，投影与类型转换在 SQL 表达式与 Go 侧完成。
package comic_repo

import (
	"context"
	"database/sql"
	"fmt"
	"path/filepath"
	"strconv"
	"strings"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// withDB 以默认超时的上下文执行查询。
func withDB[T any](fn func(ctx context.Context, conn *sql.DB) (T, error)) (T, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return fn(ctx, db.Read())
}

// GetAllComicInfos 获取所有漫画的总览信息（章节数/图片数实时聚合）。
func GetAllComicInfos() ([]model.ComicInfo, error) {
	return withDB(func(ctx context.Context, conn *sql.DB) ([]model.ComicInfo, error) {
		rows, err := conn.QueryContext(ctx, `
			SELECT
				CAST(b.id AS TEXT), b.title, b.cover_image, b.is_public, b.readed,
				COUNT(DISTINCT ch.id) AS chapter_count,
				COUNT(img.id)         AS image_count
			FROM comics b
			LEFT JOIN comic_chapters ch ON ch.comic_id = b.id
			LEFT JOIN comic_images img ON img.chapter_id = ch.id
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
	id, err := parseComicID(comicId)
	if err != nil {
		return nil, err
	}
	return withDB(func(ctx context.Context, conn *sql.DB) ([]model.ChapterInfo, error) {
		rows, err := conn.QueryContext(ctx, `
			SELECT CAST(ch.id AS TEXT), CAST(ch.comic_id AS TEXT),
			       printf('%03d', ch.chapter_no) || '_' || ch.title AS dir_name,
			       ch.chapter_no, COUNT(ci.id)
			FROM comic_chapters ch
			LEFT JOIN comic_images ci ON ci.chapter_id = ch.id
			WHERE ch.comic_id = ?
			GROUP BY ch.id, ch.comic_id, ch.chapter_no, ch.title
			ORDER BY ch.chapter_no ASC
		`, id)
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
	id, err := parseComicID(chapterId)
	if err != nil {
		return nil, err
	}
	return withDB(func(ctx context.Context, conn *sql.DB) ([]model.ImageInfo, error) {
		rows, err := conn.QueryContext(ctx,
			`SELECT ch.rel_dir || '/' || img.file_name, img.width, img.height
			 FROM comic_images img
			 JOIN comic_chapters ch ON ch.id = img.chapter_id
			 WHERE img.chapter_id = ? ORDER BY img.sort_num ASC`, id)
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
	id, err := parseComicID(comicId)
	if err != nil {
		return nil, nil, err
	}
	type result struct {
		chapters map[string]model.ChapterInfo
		images   map[string][]model.ImageInfo
	}
	out, err := withDB(func(ctx context.Context, conn *sql.DB) (*result, error) {
		rows, err := conn.QueryContext(ctx, `
			SELECT CAST(c.id AS TEXT), CAST(c.comic_id AS TEXT), c.chapter_no, c.title,
			       i.file_name, i.width, i.height, c.rel_dir
			FROM comic_chapters c
			LEFT JOIN comic_images i ON c.id = i.chapter_id
			WHERE c.comic_id = ?
			ORDER BY c.chapter_no ASC, i.sort_num ASC
		`, id)
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
				chapterID     string
				comicID       string
				chapterNo     int
				chapterTitle  string
				fileName      sql.NullString
				width         sql.NullInt64
				height        sql.NullInt64
				chapterRelDir string
			)
			if err := rows.Scan(&chapterID, &comicID, &chapterNo, &chapterTitle,
				&fileName, &width, &height, &chapterRelDir); err != nil {
				return nil, fmt.Errorf("扫描章节图片数据失败: %w", err)
			}

			if _, exists := res.chapters[chapterID]; !exists {
				res.chapters[chapterID] = model.ChapterInfo{
					ID:           chapterID,
					ComicID:      comicID,
					DirName:      fmt.Sprintf("%03d_%s", chapterNo, chapterTitle),
					ChapterIndex: chapterNo,
				}
			}
			if fileName.Valid {
				res.images[chapterID] = append(res.images[chapterID], model.ImageInfo{
					Path:   filepath.ToSlash(chapterRelDir + "/" + fileName.String),
					Width:  int32(width.Int64),
					Height: int32(height.Int64),
				})
			}
		}
		if err := rows.Err(); err != nil {
			return nil, fmt.Errorf("迭代章节图片结果集失败: %w", err)
		}

		for chapterID, chapter := range res.chapters {
			chapter.ImageCount = len(res.images[chapterID])
			res.chapters[chapterID] = chapter
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
	id, err := parseComicID(comicId)
	if err != nil {
		return err
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	sets := []string{}
	args := []any{}
	if req.IsPublic != nil {
		sets = append(sets, "is_public = ?")
		args = append(args, *req.IsPublic)
	}
	if req.Readed != nil {
		sets = append(sets, "readed = ?")
		args = append(args, *req.Readed)
	}
	if req.CoverImage != nil {
		sets = append(sets, "cover_image = ?")
		args = append(args, *req.CoverImage)
	}
	if len(sets) == 0 {
		return nil
	}

	args = append(args, id)
	if _, err := db.Exec(ctx,
		"UPDATE comics SET "+strings.Join(sets, ", ")+" WHERE id = ?", args...); err != nil {
		return fmt.Errorf("更新漫画元数据失败: %w", err)
	}
	return nil
}

// parseComicID 把客户端传来的漫画/章节 ID（字符串）解析为整数主键。
func parseComicID(raw string) (int64, error) {
	id, err := strconv.ParseInt(strings.TrimSpace(raw), 10, 64)
	if err != nil {
		return 0, fmt.Errorf("漫画 ID 非法: %s", raw)
	}
	return id, nil
}
