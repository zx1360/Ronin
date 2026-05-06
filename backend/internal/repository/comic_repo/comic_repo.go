package comic_repo

import (
	"context"
	"fmt"
	"monarch/internal/model"
	"monarch/internal/service/db"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

///	repo.go分两层函数:
// 	第一层供外部调用, 仅接收业务参数.
//	第二层核心函数私有, 同时接受ctx, pool等参数.
// 	(可同时附带另一个可带上下文的版本)支持自定义 ctx+pool（多数据源/长超时场景）

// 读取漫画总计数元数据（实时聚合，不再依赖已删除的 comic_summary 表）
func GetComicMetaData() (*model.ComicTotalMetaData, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getComicMetaData(ctx, db.GetPool())
}
func getComicMetaData(ctx context.Context, pool *pgxpool.Pool) (*model.ComicTotalMetaData, error) {
	var metadata model.ComicTotalMetaData
	query := `
		SELECT
			(SELECT COUNT(*) FROM comics.comic_books) as book_count,
			(SELECT COUNT(*) FROM comics.comic_chapters) as total_chapter_count,
			(SELECT COUNT(*) FROM comics.comic_images) as total_image_count
	`
	err := pool.QueryRow(ctx, query).Scan(&metadata.BookCount, &metadata.TotalChapterCount, &metadata.TotalImageCount)
	if err != nil {
		return nil, fmt.Errorf("查询漫画总元数据失败: %w", err)
	}
	metadata.UpdatedAt = time.Now()
	return &metadata, nil
}

// 获取所有漫画的总览信息（chapter_count/image_count 实时聚合）
func GetAllComicInfos() ([]model.ComicInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getAllComicInfos(ctx, db.GetPool())
}
func getAllComicInfos(ctx context.Context, pool *pgxpool.Pool) ([]model.ComicInfo, error) {
	query := `
		SELECT
			b.id, b.title, b.cover_image, b.is_public, b.readed, b.source,
			COUNT(DISTINCT ch.id) as chapter_count,
			COUNT(img.id) as image_count
		FROM comics.comic_books b
		LEFT JOIN comics.comic_chapters ch ON ch.comic_id = b.id
		LEFT JOIN comics.comic_images img ON img.chapter_id = ch.id
		GROUP BY b.id
		ORDER BY b.title
	`
	rows, err := pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("查询漫画元数据失败: %w", err)
	}
	defer rows.Close()
	var comicInfos []model.ComicInfo
	for rows.Next() {
		var comicInfo model.ComicInfo
		if err := rows.Scan(&comicInfo.Id, &comicInfo.Title, &comicInfo.CoverImage,
			&comicInfo.IsPublic, &comicInfo.Readed, &comicInfo.Source,
			&comicInfo.ChapterCount, &comicInfo.ImageCount); err != nil {
			return nil, fmt.Errorf("扫描漫画数据失败: %w", err)
		}
		comicInfos = append(comicInfos, comicInfo)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("迭代结果集失败: %w", err)
	}
	return comicInfos, nil
}

// 获取某章节(全局唯一章节id)及其下的图片信息
func GetChaptersWithComicId(comicId string) ([]model.ChapterInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getChaptersWithComicId(ctx, db.GetPool(), comicId)
}
func getChaptersWithComicId(ctx context.Context, pool *pgxpool.Pool, comicId string) ([]model.ChapterInfo, error) {
	var chapterInfos []model.ChapterInfo
	query := `
		SELECT ch.id, ch.comic_id, ch.dir_name, ch.chapter_index,
			COUNT(ci.id) as image_count
		FROM comics.comic_chapters ch
		LEFT JOIN comics.comic_images ci ON ci.chapter_id = ch.id
		WHERE ch.comic_id = $1
		GROUP BY ch.id, ch.comic_id, ch.dir_name, ch.chapter_index
		ORDER BY ch.chapter_index ASC
	`
	rows, err := pool.Query(ctx, query, comicId)
	if err != nil {
		return nil, fmt.Errorf("查询漫画下的章节信息失败: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var chapterInfo model.ChapterInfo
		if err := rows.Scan(&chapterInfo.Id, &chapterInfo.ComicId, &chapterInfo.DirName, &chapterInfo.ChapterIndex, &chapterInfo.ImageCount); err != nil {
			return nil, fmt.Errorf("扫描章节数据失败: %w", err)
		}
		chapterInfos = append(chapterInfos, chapterInfo)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("迭代结果集失败: %w", err)
	}
	return chapterInfos, nil
}

// 获取某章节(全局唯一章节id)及其下的图片信息
func GetImagesWithChapterId(chapterId string) ([]model.ImageInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getImagesWithChapterId(ctx, db.GetPool(), chapterId)
}
func getImagesWithChapterId(ctx context.Context, pool *pgxpool.Pool, chapterId string) ([]model.ImageInfo, error) {
	var images []model.ImageInfo
	query := `select image_path, width, height from comics.comic_images where chapter_id=$1 order by sort_num asc;`
	rows, err := pool.Query(ctx, query, chapterId)
	if err != nil {
		return nil, fmt.Errorf("查询章节下的图片信息失败: %w", err)
	}
	defer rows.Close()
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

// 漫画下载清单manifest获取, 获取某漫画的所有章节信息(带有所有图片信息)
func GetComicAllChaptersAndImages(comicId string) (map[string]model.ChapterInfo, map[string][]model.ImageInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getComicAllChaptersAndImages(ctx, db.GetPool(), comicId)
}
func getComicAllChaptersAndImages(ctx context.Context, pool *pgxpool.Pool, comicId string) (map[string]model.ChapterInfo, map[string][]model.ImageInfo, error) {
	query := `
        SELECT
            c.id as chapter_id, c.comic_id, c.dir_name, c.chapter_index,
            i.image_path, i.width, i.height
        FROM comics.comic_chapters c
        LEFT JOIN comics.comic_images i ON c.id = i.chapter_id
        WHERE c.comic_id = $1
        ORDER BY c.chapter_index ASC, i.sort_num ASC;
    `
	rows, err := pool.Query(ctx, query, comicId)
	if err != nil {
		return nil, nil, fmt.Errorf("关联查询章节和图片失败: %w", err)
	}
	defer rows.Close()

	chapterMap := make(map[string]model.ChapterInfo)
	imageMap := make(map[string][]model.ImageInfo)

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
		err := rows.Scan(
			&chapterId, &comicId, &dirName, &chapterIndex,
			&imagePath, &width, &height,
		)
		if err != nil {
			return nil, nil, fmt.Errorf("扫描章节图片数据失败: %w", err)
		}

		if _, exists := chapterMap[chapterId]; !exists {
			chapterMap[chapterId] = model.ChapterInfo{
				Id:           chapterId,
				ComicId:      comicId,
				DirName:      dirName,
				ChapterIndex: chapterIndex,
			}
		}

		if imagePath.Valid {
			img := model.ImageInfo{
				Path:   imagePath.String,
				Width:  width.Int32,
				Height: height.Int32,
			}
			imageMap[chapterId] = append(imageMap[chapterId], img)
		}
	}

	if err := rows.Err(); err != nil {
		return nil, nil, fmt.Errorf("迭代章节图片结果集失败: %w", err)
	}

	// 填充 image_count
	for chId, ch := range chapterMap {
		ch.ImageCount = len(imageMap[chId])
		chapterMap[chId] = ch
	}

	return chapterMap, imageMap, nil
}

// --- 新增 CRUD ---

// UpdateComicMeta 更新漫画的 is_public / readed / source / cover_image
func UpdateComicMeta(comicId string, req model.UpdateComicRequest) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return updateComicMeta(ctx, db.GetPool(), comicId, req)
}
func updateComicMeta(ctx context.Context, pool *pgxpool.Pool, comicId string, req model.UpdateComicRequest) error {
	// 动态构建 SET 子句
	setClauses := ""
	args := []interface{}{}
	argIdx := 1

	if req.IsPublic != nil {
		setClauses += fmt.Sprintf("is_public=$%d, ", argIdx)
		args = append(args, *req.IsPublic)
		argIdx++
	}
	if req.Readed != nil {
		setClauses += fmt.Sprintf("readed=$%d, ", argIdx)
		args = append(args, *req.Readed)
		argIdx++
	}
	if req.Source != nil {
		setClauses += fmt.Sprintf("source=$%d, ", argIdx)
		args = append(args, *req.Source)
		argIdx++
	}
	if req.CoverImage != nil {
		setClauses += fmt.Sprintf("cover_image=$%d, ", argIdx)
		args = append(args, *req.CoverImage)
		argIdx++
	}

	if len(args) == 0 {
		return nil
	}

	// 去掉末尾 ", "
	setClauses = setClauses[:len(setClauses)-2]
	args = append(args, comicId)
	query := fmt.Sprintf("UPDATE comics.comic_books SET %s WHERE id=$%d", setClauses, argIdx)

	_, err := pool.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("更新漫画元数据失败: %w", err)
	}
	return nil
}

// DeleteComic 删除漫画及级联数据，返回该漫画在文件系统中的目录名(title)用于后续清理
func DeleteComic(comicId string) (title string, err error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return deleteComic(ctx, db.GetPool(), comicId)
}
func deleteComic(ctx context.Context, pool *pgxpool.Pool, comicId string) (string, error) {
	// 先获取标题
	var title string
	if err := pool.QueryRow(ctx, `SELECT title FROM comics.comic_books WHERE id=$1`, comicId).Scan(&title); err != nil {
		return "", fmt.Errorf("查询漫画标题失败: %w", err)
	}

	// 级联删除: comic_images → comic_chapters → comic_books
	// 由于表有 CASCADE 外键约束，只需删除 comic_books 即可
	if _, err := pool.Exec(ctx, `DELETE FROM comics.comic_books WHERE id=$1`, comicId); err != nil {
		return "", fmt.Errorf("删除漫画失败: %w", err)
	}
	return title, nil
}

// SyncReadedStatus 批量更新 readed 状态并返回每本漫画服务器上的章节数（用于增量下载判断）
func SyncReadedStatus(readedIds []string) (*model.SyncReadedResponse, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return syncReadedStatus(ctx, db.GetPool(), readedIds)
}
func syncReadedStatus(ctx context.Context, pool *pgxpool.Pool, readedIds []string) (*model.SyncReadedResponse, error) {
	resp := &model.SyncReadedResponse{
		NewChapters: make(map[string]int),
	}

	// 1. 批量标记 readed = true（如果有需要标记的ID）
	if len(readedIds) > 0 {
		tag, err := pool.Exec(ctx, `UPDATE comics.comic_books SET readed = TRUE WHERE id = ANY($1)`, readedIds)
		if err != nil {
			return nil, fmt.Errorf("批量更新已读状态失败: %w", err)
		}
		resp.UpdatedCount = int(tag.RowsAffected())
	}

	// 2. 始终返回所有漫画的最新章节总数（供客户端对比增量）
	rows, err := pool.Query(ctx, `
		SELECT b.id, COUNT(ch.id)
		FROM comics.comic_books b
		LEFT JOIN comics.comic_chapters ch ON ch.comic_id = b.id
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
