package comic_repo

import (
	"context"
	"fmt"
	"monarch/internal/model"
	"monarch/internal/service/db"
	_ "monarch/internal/service/db"

	"github.com/jackc/pgx/v5/pgxpool"
)

///	repo.go分两层函数:
// 	第一层供外部调用, 仅接收业务参数.
//	第二层核心函数私有, 同时接受ctx, pool等参数.
// 	(可同时附带另一个可带上下文的版本)支持自定义 ctx+pool（多数据源/长超时场景）

// 读取漫画总元数据
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
func GetChapterInfo(chapterId string) (*model.ChapterInfo, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getChapterInfo(ctx, db.GetPool(), chapterId)
}
func getChapterInfo(ctx context.Context, pool *pgxpool.Pool, chapterId string) (*model.ChapterInfo, error) {
	var chapterInfo model.ChapterInfo
	// 获取章节总览信息
	query := `select id, comic_id, dir_name, chapter_index from comics.comic_chapters where id=$1`
	err := pool.QueryRow(ctx, query, chapterId).Scan(&chapterInfo.Id, &chapterInfo.ComicId, &chapterInfo.DirName, &chapterInfo.ChapterIndex)
	if err != nil {
		return nil, fmt.Errorf("查询章节信息失败: %w", err)
	}
	// 获取该章节下所有图片的信息
	var images []map[string]interface{}
	query = `select image_path, width, height from comics.comic_images where chapter_id=$1 order by sort_num asc;`
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
	chapterInfo.Images = images
	chapterInfo.ImageCount = len(images)
	return &chapterInfo, nil
}
