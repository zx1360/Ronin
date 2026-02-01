package gallery_repo

import (
	"errors"
	"fmt"
	"monarch/internal/model"
	"monarch/internal/service/db"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// FetchMediaAssets 分页获取未删除的媒体资产
func FetchMediaAssets(limit int, offset int) ([]model.MediaAsset, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		SELECT 
			id, created_at, updated_at, captured_at, file_path, 
			thumb_path, preview_path, hash, size_bytes, mime_type, 
			is_deleted, sync_count, group_id
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
			is_deleted, sync_count, group_id
		FROM gallery.media_assets
		WHERE id = $1
	`

	var asset model.MediaAsset
	err := db.GetPool().QueryRow(ctx, query, id).Scan(
		&asset.ID, &asset.CreatedAt, &asset.UpdatedAt, &asset.CapturedAt,
		&asset.FilePath, &asset.ThumbPath, &asset.PreviewPath,
		&asset.Hash, &asset.SizeBytes, &asset.MimeType,
		&asset.IsDeleted, &asset.SyncCount, &asset.GroupID,
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

// UpdateMediaAssets 更新媒体资产（除了 file_path 字段）
func UpdateMediaAssets(assets []model.MediaAsset) error {
	if len(assets) == 0 {
		return nil
	}

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	updateQuery := `
		UPDATE gallery.media_assets
		SET is_deleted = $1, group_id = $2
		WHERE id = $3
	`

	for _, asset := range assets {
		_, err := tx.Exec(ctx, updateQuery, asset.IsDeleted, asset.GroupID, asset.ID)
		if err != nil {
			return fmt.Errorf("更新媒体资产失败: %w", err)
		}
	}

	err = tx.Commit(ctx)
	if err != nil {
		return fmt.Errorf("提交事务失败: %w", err)
	}

	return nil
}

// UpsertTags 全量覆写标签表（删除原有标签，重新插入新标签）
func UpsertTags(tags []model.Tag) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	// 删除所有标签
	_, err = tx.Exec(ctx, `DELETE FROM gallery.tags`)
	if err != nil {
		return fmt.Errorf("删除旧标签失败: %w", err)
	}

	// 插入新标签
	insertQuery := `
		INSERT INTO gallery.tags (id, name, parent_id, full_path, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	for _, tag := range tags {
		_, err := tx.Exec(ctx, insertQuery, tag.ID, tag.Name, tag.ParentID, tag.FullPath, tag.CreatedAt, tag.UpdatedAt)
		if err != nil {
			return fmt.Errorf("插入标签失败: %w", err)
		}
	}

	err = tx.Commit(ctx)
	if err != nil {
		return fmt.Errorf("提交事务失败: %w", err)
	}

	return nil
}

// UpsertMediaTagLinks 全量覆写媒体-标签关联（仅限指定的媒体 ID）
func UpsertMediaTagLinks(mediaIDs []uuid.UUID, links []model.MediaTagLink) error {
	if len(mediaIDs) == 0 {
		return nil
	}

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	// 删除指定媒体 ID 的所有标签关联
	deleteQuery := `DELETE FROM  gallery.media_tag_links WHERE media_id = ANY($1)`
	_, err = tx.Exec(ctx, deleteQuery, mediaIDs)
	if err != nil {
		return fmt.Errorf("删除旧的媒体标签关联失败: %w", err)
	}

	// 插入新的关联记录
	if len(links) > 0 {
		insertQuery := `
			INSERT INTO  gallery.media_tag_links (media_id, tag_id)
			VALUES ($1, $2)
		`

		for _, link := range links {
			_, err := tx.Exec(ctx, insertQuery, link.MediaID, link.TagID)
			if err != nil {
				return fmt.Errorf("插入媒体标签关联失败: %w", err)
			}
		}
	}

	err = tx.Commit(ctx)
	if err != nil {
		return fmt.Errorf("提交事务失败: %w", err)
	}

	return nil
}

// IncrementSyncCount 将指定媒体资产的 sync_count 增加 1
func IncrementSyncCount(mediaIDs []uuid.UUID) error {
	if len(mediaIDs) == 0 {
		return nil
	}

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		UPDATE gallery.media_assets
		SET sync_count = sync_count + 1, updated_at = CURRENT_TIMESTAMP
		WHERE id = ANY($1)
	`

	_, err := db.GetPool().Exec(ctx, query, mediaIDs)
	if err != nil {
		return fmt.Errorf("增加同步计数失败: %w", err)
	}

	return nil
}
