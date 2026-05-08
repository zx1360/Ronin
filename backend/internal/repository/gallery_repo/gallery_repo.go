package gallery_repo

import (
	"context"
	"errors"
	"fmt"
	"monarch/internal/model"
	"monarch/internal/service/db"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// FetchMediaAssets 分页获取未删除的媒体资产
func FetchMediaAssets(limit int, offset int) ([]model.MediaAsset, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		SELECT 
			id, created_at, updated_at, captured_at, file_path, 
			thumb_path, preview_path, hash, size_bytes, mime_type, 
			is_deleted, sync_count, group_id, COALESCE(message, ''), edit_params
		FROM gallery.media_assets
		WHERE is_deleted = false
		ORDER BY sync_count ASC, captured_at ASC
		LIMIT $1 OFFSET $2
	`

	rows, err := db.GetPool().Query(ctx, query, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("查询媒体资产失败: %w", err)
	}
	defer rows.Close()

	var assets []model.MediaAsset
	for rows.Next() {
		var asset model.MediaAsset
		err := rows.Scan(
			&asset.ID, &asset.CreatedAt, &asset.UpdatedAt, &asset.CapturedAt,
			&asset.FilePath, &asset.ThumbPath, &asset.PreviewPath,
			&asset.Hash, &asset.SizeBytes, &asset.MimeType,
			&asset.IsDeleted, &asset.SyncCount, &asset.GroupID,
			&asset.Message, &asset.EditParams,
		)
		if err != nil {
			return nil, fmt.Errorf("扫描媒体资产行失败: %w", err)
		}
		assets = append(assets, asset)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历媒体资产结果集失败: %w", err)
	}

	return assets, nil
}

// FetchMediaAssetByID 根据 ID 获取单个媒体资产
func FetchMediaAssetByID(id uuid.UUID) (*model.MediaAsset, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		SELECT 
			id, created_at, updated_at, captured_at, file_path, 
			thumb_path, preview_path, hash, size_bytes, mime_type, 
			is_deleted, sync_count, group_id, COALESCE(message, ''), edit_params
		FROM gallery.media_assets
		WHERE id = $1
	`

	var asset model.MediaAsset
	err := db.GetPool().QueryRow(ctx, query, id).Scan(
		&asset.ID, &asset.CreatedAt, &asset.UpdatedAt, &asset.CapturedAt,
		&asset.FilePath, &asset.ThumbPath, &asset.PreviewPath,
		&asset.Hash, &asset.SizeBytes, &asset.MimeType,
		&asset.IsDeleted, &asset.SyncCount, &asset.GroupID,
		&asset.Message, &asset.EditParams,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("查询媒体资产失败: %w", err)
	}

	return &asset, nil
}

// CountMediaAssets 获取未删除的媒体资产总数
func CountMediaAssets() (int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `SELECT COUNT(*) FROM gallery.media_assets WHERE is_deleted = false`

	var count int
	err := db.GetPool().QueryRow(ctx, query).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("统计媒体资产失败: %w", err)
	}

	return count, nil
}

// FetchAllTags 获取所有标签（包括树状结构）
func FetchAllTags() ([]model.Tag, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		SELECT id, created_at, updated_at, name, parent_id, full_path
		FROM gallery.tags
		ORDER BY full_path ASC
	`

	rows, err := db.GetPool().Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("查询标签失败: %w", err)
	}
	defer rows.Close()

	var tags []model.Tag
	for rows.Next() {
		var tag model.Tag
		err := rows.Scan(
			&tag.ID, &tag.CreatedAt, &tag.UpdatedAt, &tag.Name,
			&tag.ParentID, &tag.FullPath,
		)
		if err != nil {
			return nil, fmt.Errorf("扫描标签行失败: %w", err)
		}
		tags = append(tags, tag)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历标签结果集失败: %w", err)
	}

	return tags, nil
}

// FetchMediaTagLinks 获取指定媒体 ID 列表对应的所有标签关联
func FetchMediaTagLinks(mediaIDs []uuid.UUID) ([]model.MediaTagLink, error) {
	if len(mediaIDs) == 0 {
		return []model.MediaTagLink{}, nil
	}

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		SELECT media_id, tag_id
		FROM  gallery.media_tag_links
		WHERE media_id = ANY($1)
	`

	rows, err := db.GetPool().Query(ctx, query, mediaIDs)
	if err != nil {
		return nil, fmt.Errorf("查询媒体标签关联失败: %w", err)
	}
	defer rows.Close()

	var links []model.MediaTagLink
	for rows.Next() {
		var link model.MediaTagLink
		err := rows.Scan(&link.MediaID, &link.TagID)
		if err != nil {
			return nil, fmt.Errorf("扫描标签关联行失败: %w", err)
		}
		links = append(links, link)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历标签关联结果集失败: %w", err)
	}

	return links, nil
}

// UpdateMediaAssetsTx 在事务中更新媒体资产（除了 file_path 字段）
func UpdateMediaAssetsTx(ctx context.Context, tx pgx.Tx, assets []model.MediaAsset) error {
	if len(assets) == 0 {
		return nil
	}

	updateQuery := `
		UPDATE gallery.media_assets
		SET is_deleted = $1, group_id = $2, message = $3, edit_params = $4
		WHERE id = $5
	`

	for _, asset := range assets {
		_, err := tx.Exec(ctx, updateQuery, asset.IsDeleted, asset.GroupID, asset.Message, asset.EditParams, asset.ID)
		if err != nil {
			return fmt.Errorf("更新媒体资产失败: %w", err)
		}
	}

	return nil
}

// sortTagsByHierarchy 按层级排序标签，确保父标签在子标签之前
func sortTagsByHierarchy(tags []model.Tag) []model.Tag {
	if len(tags) == 0 {
		return tags
	}

	// 构建 ID -> Tag 映射
	tagMap := make(map[uuid.UUID]model.Tag)
	for _, tag := range tags {
		tagMap[tag.ID] = tag
	}

	// 结果切片
	sorted := make([]model.Tag, 0, len(tags))
	visited := make(map[uuid.UUID]bool)

	// 递归添加标签（先添加父标签）
	var addTag func(tag model.Tag)
	addTag = func(tag model.Tag) {
		if visited[tag.ID] {
			return
		}
		// 如果有父标签且父标签在本次传入的标签列表中，先添加父标签
		if tag.ParentID != nil {
			if parent, exists := tagMap[*tag.ParentID]; exists {
				addTag(parent)
			}
		}
		visited[tag.ID] = true
		sorted = append(sorted, tag)
	}

	for _, tag := range tags {
		addTag(tag)
	}

	return sorted
}

// UpsertTagsTx 在事务中全量覆写标签表
func UpsertTagsTx(ctx context.Context, tx pgx.Tx, tags []model.Tag) error {
	// 删除所有标签
	_, err := tx.Exec(ctx, `DELETE FROM gallery.tags`)
	if err != nil {
		return fmt.Errorf("删除旧标签失败: %w", err)
	}

	// 按层级排序，确保父标签先于子标签插入（满足外键约束）
	sortedTags := sortTagsByHierarchy(tags)

	// 插入新标签
	insertQuery := `
		INSERT INTO gallery.tags (id, name, parent_id, full_path, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	for _, tag := range sortedTags {
		// 将 FlexTime 转换为 time.Time
		createdAt := tag.CreatedAt.Time()
		updatedAt := tag.UpdatedAt.Time()
		_, err := tx.Exec(ctx, insertQuery, tag.ID, tag.Name, tag.ParentID, tag.FullPath, createdAt, updatedAt)
		if err != nil {
			return fmt.Errorf("插入标签失败: %w", err)
		}
	}

	return nil
}

// UpsertMediaTagLinksTx 在事务中全量覆写媒体-标签关联
func UpsertMediaTagLinksTx(ctx context.Context, tx pgx.Tx, mediaIDs []uuid.UUID, links []model.MediaTagLink) error {
	if len(mediaIDs) == 0 {
		return nil
	}

	// 删除指定媒体 ID 的所有标签关联
	deleteQuery := `DELETE FROM gallery.media_tag_links WHERE media_id = ANY($1)`
	_, err := tx.Exec(ctx, deleteQuery, mediaIDs)
	if err != nil {
		return fmt.Errorf("删除旧的媒体标签关联失败: %w", err)
	}

	// 插入新的关联记录
	if len(links) > 0 {
		insertQuery := `
			INSERT INTO gallery.media_tag_links (media_id, tag_id)
			VALUES ($1, $2)
		`

		for _, link := range links {
			_, err := tx.Exec(ctx, insertQuery, link.MediaID, link.TagID)
			if err != nil {
				return fmt.Errorf("插入媒体标签关联失败: %w", err)
			}
		}
	}

	return nil
}

// BeginTx 开始一个新事务，供外部使用
func BeginTx(ctx context.Context) (pgx.Tx, error) {
	return db.GetPool().Begin(ctx)
}

// GetPool 获取数据库连接池
func GetPool() *pgxpool.Pool {
	return db.GetPool()
}
