package comic_repo

import (
	"context"
	"fmt"
	"monarch/internal/model"
	"monarch/internal/service/db"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

///	repo.go分两层函数:
// 	第一层供外部调用, 仅接收业务参数.
//	第二层核心函数私有, 同时接受ctx, pool等参数.
// 	(可同时附带另一个可带上下文的版本)支持自定义 ctx+pool（多数据源/长超时场景）

// 读取漫画总计数元数据
func GetComicMetaData() (*model.ComicTotalMetaData, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getComicMetaData(ctx, db.GetPool())
}
func getComicMetaData(ctx context.Context, pool *pgxpool.Pool) (*model.ComicTotalMetaData, error) {
	var metadata model.ComicTotalMetaData
	query := `select book_count, total_chapter_count, total_image_count, updated_at from comics.comic_summary where id='comic_total_metadata'`
	err := pool.QueryRow(ctx, query).Scan(&metadata.BookCount, &metadata.TotalChapterCount, &metadata.TotalImageCount, &metadata.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("查询漫画总元数据失败: %w", err)
	}
	return &metadata, nil
}

// 获取所有漫画的总览信息
func GetAllComicInfos() ([]model.ComicInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getAllComicInfos(ctx, db.GetPool())
}
func getAllComicInfos(ctx context.Context, pool *pgxpool.Pool) ([]model.ComicInfo, error) {
	// TODO: 加入limit, 客户端做分页.
	query := `select id, title, chapter_count, image_count, cover_image from comics.comic_books`
	rows, err := pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("查询漫画元数据失败: %w", err)
	}
	defer rows.Close() // 否则会泄露连接.
	var comicInfos []model.ComicInfo
	for rows.Next() {
		var comicInfo model.ComicInfo
		rows.Scan(&comicInfo.Id, &comicInfo.Title, &comicInfo.ChapterCount, &comicInfo.ImageCount, &comicInfo.CoverImage)
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
	// 获取该章节下所有图片的信息
	var chapterInfos []model.ChapterInfo
	query := `select id, comic_id, dir_name, chapter_index, image_count from comics.comic_chapters where comic_id=$1 order by chapter_index asc;`
	rows, err := pool.Query(ctx, query, comicId)
	if err != nil {
		return nil, fmt.Errorf("查询漫画下的章节信息失败: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var chapterInfo model.ChapterInfo
		rows.Scan(&chapterInfo.Id, &chapterInfo.ComicId, &chapterInfo.DirName, &chapterInfo.ChapterIndex, &chapterInfo.ImageCount)
		chapterInfos = append(chapterInfos, chapterInfo)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("迭代结果集失败: %w", err)
	}
	return chapterInfos, nil
}

// 获取某章节(全局唯一章节id)及其下的图片信息
func GetImagesWithChapterId(chapterId string) ([]map[string]interface{}, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getImagesWithChapterId(ctx, db.GetPool(), chapterId)
}
func getImagesWithChapterId(ctx context.Context, pool *pgxpool.Pool, chapterId string) ([]map[string]interface{}, error) {
	// 获取该章节下所有图片的信息
	var images []map[string]interface{}
	query := `select image_path, width, height from comics.comic_images where chapter_id=$1 order by sort_num asc;`
	rows, err := pool.Query(ctx, query, chapterId)
	if err != nil {
		return nil, fmt.Errorf("查询章节下的图片信息失败: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var (
			path   string
			width  int
			height int
		)
		rows.Scan(&path, &width, &height)
		image := map[string]interface{}{
			"path":   path,
			"width":  width,
			"height": height,
		}
		images = append(images, image)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("迭代结果集失败: %w", err)
	}
	return images, nil
}

// 漫画下载清单manifest获取, 获取某漫画的所有章节信息(带有所有图片信息)
func GetComicAllChaptersAndImages(comicId string) (map[string]model.ChapterInfo, map[string][]map[string]interface{}, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getComicAllChaptersAndImages(ctx, db.GetPool(), comicId)
}
func getComicAllChaptersAndImages(ctx context.Context, pool *pgxpool.Pool, comicId string) (map[string]model.ChapterInfo, map[string][]map[string]interface{}, error) {
	// 关联查询章节和图片（LEFT JOIN保证无图片的章节也能返回）
	query := `
        SELECT 
            c.id as chapter_id, c.comic_id, c.dir_name, c.chapter_index, c.image_count,
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

	// 内存中分组：chapterId -> 章节信息 / chapterId -> 图片列表
	// 最佳实践: 内存中分组操作使用map.
	chapterMap := make(map[string]model.ChapterInfo)
	imageMap := make(map[string][]map[string]interface{})

	for rows.Next() {
		var (
			chapterId    string
			comicId      string
			dirName      string
			chapterIndex int // 按实际字段类型调整
			imageCount   int
			imagePath    pgtype.Text
			width        pgtype.Int4
			height       pgtype.Int4
		)
		// 扫描行数据（注意字段顺序和查询语句一致）
		err := rows.Scan(
			&chapterId, &comicId, &dirName, &chapterIndex, &imageCount,
			&imagePath, &width, &height,
		)
		if err != nil {
			return nil, nil, fmt.Errorf("扫描章节图片数据失败: %w", err)
		}

		// 初始化章节信息（chapterId唯一）
		chapterMap[chapterId] = model.ChapterInfo{
			Id:           chapterId,
			ComicId:      comicId,
			DirName:      dirName,
			ChapterIndex: chapterIndex,
			ImageCount:   imageCount,
		}

		// 初始化图片列表（仅当图片字段非NULL时）
		if imagePath.Valid {
			image := map[string]interface{}{
				"path":   imagePath.String,
				"width":  width.Int32,
				"height": height.Int32,
			}
			imageMap[chapterId] = append(imageMap[chapterId], image)
		}
	}

	if err := rows.Err(); err != nil {
		return nil, nil, fmt.Errorf("迭代章节图片结果集失败: %w", err)
	}

	return chapterMap, imageMap, nil
}
