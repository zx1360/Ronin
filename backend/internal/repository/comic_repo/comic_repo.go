// Package comic_repo 提供 Android 端"漫画"模块的只读查询与管理字段写入。
//
// 数据对象为 comix 爬虫维护的表（comix_*）与三个只读桥接视图（comix_comic_books /
// comix_comic_chapters / comix_comic_images）；本包不做爬虫操作。
//
// 视图只负责读；写操作一律落到真实表 comix_comic（视图没有 INSTEAD OF 触发器）。
package comic_repo

import (
	"database/sql"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// sqlParamChunk 单条 SQL 的绑定参数分片上限，规避 SQLite 变量数上限。
const sqlParamChunk = 500

// GetComicMetaData 读取漫画总计数元数据（实时聚合）。
func GetComicMetaData() (*model.ComicTotalMetaData, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	var metadata model.ComicTotalMetaData
	err := db.R().QueryRowContext(ctx, `
		SELECT
			(SELECT COUNT(*) FROM comix_comic_books),
			(SELECT COUNT(*) FROM comix_comic_chapters),
			(SELECT COUNT(*) FROM comix_comic_images)
	`).Scan(&metadata.BookCount, &metadata.TotalChapterCount, &metadata.TotalImageCount)
	if err != nil {
		return nil, fmt.Errorf("查询漫画总元数据失败: %w", err)
	}
	metadata.UpdatedAt = time.Now()
	return &metadata, nil
}

// GetAllComicInfos 获取所有漫画的总览信息（章节数/图片数实时聚合）。
func GetAllComicInfos() ([]model.ComicInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `
		SELECT
			b.id, b.title, b.cover_image, b.is_public, b.readed,
			COUNT(DISTINCT ch.id) AS chapter_count,
			COUNT(img.id)         AS image_count
		FROM comix_comic_books b
		LEFT JOIN comix_comic_chapters ch ON ch.comic_id = b.id
		LEFT JOIN comix_comic_images img ON img.chapter_id = ch.id
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
}

// GetChaptersWithComicId 获取指定漫画的章节列表（含每章图片数）。
func GetChaptersWithComicId(comicId string) ([]model.ChapterInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `
		SELECT ch.id, ch.comic_id, ch.dir_name, ch.chapter_index, COUNT(ci.id)
		FROM comix_comic_chapters ch
		LEFT JOIN comix_comic_images ci ON ci.chapter_id = ch.id
		WHERE ch.comic_id = ?
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
}

// GetImagesWithChapterId 获取指定章节下的图片清单。
func GetImagesWithChapterId(chapterId string) ([]model.ImageInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx,
		`SELECT image_path, width, height FROM comix_comic_images
		 WHERE chapter_id = ? ORDER BY sort_num ASC`, chapterId)
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
}

// GetComicAllChaptersAndImages 获取整部漫画的章节与图片（按章节号、图片序号升序）。
func GetComicAllChaptersAndImages(comicId string) (map[string]model.ChapterInfo, map[string][]model.ImageInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `
		SELECT c.id, c.comic_id, c.dir_name, c.chapter_index, i.image_path, i.width, i.height
		FROM comix_comic_chapters c
		LEFT JOIN comix_comic_images i ON c.id = i.chapter_id
		WHERE c.comic_id = ?
		ORDER BY c.chapter_index ASC, i.sort_num ASC
	`, comicId)
	if err != nil {
		return nil, nil, fmt.Errorf("关联查询章节和图片失败: %w", err)
	}
	defer rows.Close()

	chapters := make(map[string]model.ChapterInfo)
	images := make(map[string][]model.ImageInfo)
	for rows.Next() {
		var (
			chapterId    string
			comicId      string
			dirName      string
			chapterIndex int
			imagePath    sql.NullString
			width        sql.NullInt64
			height       sql.NullInt64
		)
		if err := rows.Scan(&chapterId, &comicId, &dirName, &chapterIndex,
			&imagePath, &width, &height); err != nil {
			return nil, nil, fmt.Errorf("扫描章节图片数据失败: %w", err)
		}

		if _, exists := chapters[chapterId]; !exists {
			chapters[chapterId] = model.ChapterInfo{
				ID:           chapterId,
				ComicID:      comicId,
				DirName:      dirName,
				ChapterIndex: chapterIndex,
			}
		}
		if imagePath.Valid {
			images[chapterId] = append(images[chapterId], model.ImageInfo{
				Path:   imagePath.String,
				Width:  int32(width.Int64),
				Height: int32(height.Int64),
			})
		}
	}
	if err := rows.Err(); err != nil {
		return nil, nil, fmt.Errorf("迭代章节图片结果集失败: %w", err)
	}

	for chapterId, chapter := range chapters {
		chapter.ImageCount = len(images[chapterId])
		chapters[chapterId] = chapter
	}
	return chapters, images, nil
}

// UpdateComicMeta 更新漫画的 is_public / readed（缺省字段表示不修改）。
//
// 直写真实表：桥接视图是只读的，没有 INSTEAD OF 触发器。
// comix_comic.id 为 INTEGER，而入参是 TEXT，故用 CAST 统一比较类型。
func UpdateComicMeta(comicId string, req model.UpdateComicRequest) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	sets := []string{}
	args := []any{}
	add := func(column string, value any) {
		args = append(args, value)
		sets = append(sets, column+"=?")
	}
	if req.IsPublic != nil {
		add("is_public", *req.IsPublic)
	}
	if req.Readed != nil {
		add("readed", *req.Readed)
	}
	if len(sets) == 0 {
		return nil
	}

	// 触发器已移除，updated_at 必须显式写入
	add("updated_at", model.Now())
	args = append(args, comicId)
	query := fmt.Sprintf("UPDATE comix_comic SET %s WHERE CAST(id AS TEXT) = ?",
		strings.Join(sets, ", "))
	if _, err := db.W().ExecContext(ctx, query, args...); err != nil {
		return fmt.Errorf("更新漫画元数据失败: %w", err)
	}
	return nil
}

// DeleteComic 删除漫画及级联数据，返回标题与存储相对路径(rel_dir)供调用方清理文件。
//
// 两者都需要：legacy 资源的目录以标题命名（comics/{title}），爬虫登记的资源以主键
// 命名（comics/{comic_id}）；只用标题删目录会残留整本漫画文件。
func DeleteComic(comicId string) (title string, relDir string, err error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	var result struct{ title, relDir string }
	// 读标题与删除在同一写事务内，避免读到已被外部删除的行；rel_dir 为真实列，视图不暴露
	err = db.Tx(ctx, func(tx *sql.Tx) error {
		if err := tx.QueryRowContext(ctx,
			`SELECT title, rel_dir FROM comix_comic WHERE CAST(id AS TEXT) = ?`, comicId,
		).Scan(&result.title, &result.relDir); err != nil {
			return fmt.Errorf("查询漫画标题失败: %w", err)
		}

		// comic_images → comic_chapters → comic_books 均为 CASCADE 外键，删主表即可
		if _, err := tx.ExecContext(ctx, `DELETE FROM comix_comic WHERE CAST(id AS TEXT) = ?`, comicId); err != nil {
			return fmt.Errorf("删除漫画失败: %w", err)
		}
		return nil
	})
	if err != nil {
		return "", "", err
	}
	return result.title, filepath.ToSlash(result.relDir), nil
}

// SyncReadedStatus 批量标记已读，并返回每本漫画的服务器章节总数（供客户端判断增量）。
func SyncReadedStatus(readedIds []string) (*model.SyncReadedResponse, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	resp := &model.SyncReadedResponse{NewChapters: make(map[string]int)}

	if len(readedIds) > 0 {
		// 分片更新，整体一个事务：全成功或全回滚
		err := db.Tx(ctx, func(tx *sql.Tx) error {
			for start := 0; start < len(readedIds); start += sqlParamChunk {
				chunk := readedIds[start:min(start+sqlParamChunk, len(readedIds))]
				marks := make([]string, len(chunk))
				args := make([]any, 0, len(chunk)+1)
				args = append(args, model.Now()) // 触发器已移除，updated_at 显式写入
				for i, id := range chunk {
					marks[i] = "?"
					args = append(args, id)
				}
				query := fmt.Sprintf(
					`UPDATE comix_comic SET readed = 1, updated_at = ? WHERE CAST(id AS TEXT) IN (%s)`,
					strings.Join(marks, ", "))
				tag, err := tx.ExecContext(ctx, query, args...)
				if err != nil {
					return fmt.Errorf("批量更新已读状态失败: %w", err)
				}
				affected, _ := tag.RowsAffected() // 计数不可用不影响写入结果
				resp.UpdatedCount += int(affected)
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}

	rows, err := db.R().QueryContext(ctx, `
		SELECT b.id, COUNT(ch.id)
		FROM comix_comic_books b
		LEFT JOIN comix_comic_chapters ch ON ch.comic_id = b.id
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
}
