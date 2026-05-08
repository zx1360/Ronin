// Package repository 负责数据库操作
package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"gizmos/internal/gallery/model"
	"gizmos/internal/service/db"
)

// Repository 数据库操作仓库
type Repository struct{}

// NewRepository 创建新的仓库实例
func NewRepository() *Repository {
	return &Repository{}
}

// HashExists 检查哈希是否已存在
func (r *Repository) HashExists(ctx context.Context, hash []byte) (bool, error) {
	var exists bool
	err := db.Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM gallery.media_assets WHERE hash = $1)`,
		hash,
	).Scan(&exists)
	return exists, err
}

// InsertMediaAsset 插入媒体资产记录
func (r *Repository) InsertMediaAsset(ctx context.Context, asset *model.MediaAsset) error {
	_, err := db.Pool.Exec(ctx, `
		INSERT INTO gallery.media_assets (
			id, captured_at, file_path, thumb_path, preview_path, 
			hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`,
		asset.ID,
		asset.CapturedAt,
		asset.FilePath,
		asset.ThumbPath,
		asset.PreviewPath,
		asset.Hash,
		asset.SizeBytes,
		asset.MimeType,
		asset.IsDeleted,
		asset.SyncCount,
		asset.GroupID,
		asset.EditParams,
	)
	return err
}

// BatchInsertMediaAssets 批量插入媒体资产
func (r *Repository) BatchInsertMediaAssets(ctx context.Context, assets []*model.MediaAsset) error {
	if len(assets) == 0 {
		return nil
	}

	batch := &pgx.Batch{}
	for _, asset := range assets {
		batch.Queue(`
			INSERT INTO gallery.media_assets (
				id, captured_at, file_path, thumb_path, preview_path, 
				hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
			ON CONFLICT (hash) DO NOTHING
		`,
			asset.ID,
			asset.CapturedAt,
			asset.FilePath,
			asset.ThumbPath,
			asset.PreviewPath,
			asset.Hash,
			asset.SizeBytes,
			asset.MimeType,
			asset.IsDeleted,
			asset.SyncCount,
			asset.GroupID,
			asset.EditParams,
		)
	}

	br := db.Pool.SendBatch(ctx, batch)
	defer br.Close()

	for range assets {
		if _, err := br.Exec(); err != nil {
			return fmt.Errorf("批量插入失败: %w", err)
		}
	}

	return nil
}

// GetDeletedAssets 获取标记为删除的媒体资产
func (r *Repository) GetDeletedAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	rows, err := db.Pool.Query(ctx, `
		SELECT id, created_at, updated_at, captured_at, file_path, thumb_path, 
			   preview_path, hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params
		FROM gallery.media_assets 
		WHERE is_deleted = true
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assets []*model.MediaAsset
	for rows.Next() {
		asset := &model.MediaAsset{}
		err := rows.Scan(
			&asset.ID,
			&asset.CreatedAt,
			&asset.UpdatedAt,
			&asset.CapturedAt,
			&asset.FilePath,
			&asset.ThumbPath,
			&asset.PreviewPath,
			&asset.Hash,
			&asset.SizeBytes,
			&asset.MimeType,
			&asset.IsDeleted,
			&asset.SyncCount,
			&asset.GroupID,
			&asset.EditParams,
		)
		if err != nil {
			return nil, err
		}
		assets = append(assets, asset)
	}

	return assets, rows.Err()
}

// GetGroupedAssets 获取被捆绑到指定主文件的所有资产
func (r *Repository) GetGroupedAssets(ctx context.Context, groupID uuid.UUID) ([]*model.MediaAsset, error) {
	rows, err := db.Pool.Query(ctx, `
		SELECT id, created_at, updated_at, captured_at, file_path, thumb_path, 
			   preview_path, hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params
		FROM gallery.media_assets 
		WHERE group_id = $1
	`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assets []*model.MediaAsset
	for rows.Next() {
		asset := &model.MediaAsset{}
		err := rows.Scan(
			&asset.ID,
			&asset.CreatedAt,
			&asset.UpdatedAt,
			&asset.CapturedAt,
			&asset.FilePath,
			&asset.ThumbPath,
			&asset.PreviewPath,
			&asset.Hash,
			&asset.SizeBytes,
			&asset.MimeType,
			&asset.IsDeleted,
			&asset.SyncCount,
			&asset.GroupID,
			&asset.EditParams,
		)
		if err != nil {
			return nil, err
		}
		assets = append(assets, asset)
	}

	return assets, rows.Err()
}

// DeleteAssetRecord 物理删除数据库记录
func (r *Repository) DeleteAssetRecord(ctx context.Context, id uuid.UUID) error {
	_, err := db.Pool.Exec(ctx, `DELETE FROM gallery.media_assets WHERE id = $1`, id)
	return err
}

// BatchDeleteAssetRecords 批量删除数据库记录
func (r *Repository) BatchDeleteAssetRecords(ctx context.Context, ids []uuid.UUID) error {
	if len(ids) == 0 {
		return nil
	}

	_, err := db.Pool.Exec(ctx, `DELETE FROM gallery.media_assets WHERE id = ANY($1)`, ids)
	return err
}

// GetAssetByID 根据 ID 获取媒体资产
func (r *Repository) GetAssetByID(ctx context.Context, id uuid.UUID) (*model.MediaAsset, error) {
	asset := &model.MediaAsset{}
	err := db.Pool.QueryRow(ctx, `
		SELECT id, created_at, updated_at, captured_at, file_path, thumb_path, 
			   preview_path, hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params
		FROM gallery.media_assets 
		WHERE id = $1
	`, id).Scan(
		&asset.ID,
		&asset.CreatedAt,
		&asset.UpdatedAt,
		&asset.CapturedAt,
		&asset.FilePath,
		&asset.ThumbPath,
		&asset.PreviewPath,
		&asset.Hash,
		&asset.SizeBytes,
		&asset.MimeType,
		&asset.IsDeleted,
		&asset.SyncCount,
		&asset.GroupID,
		&asset.EditParams,
	)
	if err != nil {
		return nil, err
	}
	return asset, nil
}

// CountAssets 统计媒体资产数量
func (r *Repository) CountAssets(ctx context.Context) (total int64, deleted int64, err error) {
	err = db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM gallery.media_assets`).Scan(&total)
	if err != nil {
		return
	}
	err = db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM gallery.media_assets WHERE is_deleted = true`).Scan(&deleted)
	return
}

// GetAllAssets 获取所有媒体资产（包含 is_deleted=true 记录）
func (r *Repository) GetAllAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	rows, err := db.Pool.Query(ctx, `
		SELECT id, created_at, updated_at, captured_at, file_path, thumb_path,
		       preview_path, hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params
		FROM gallery.media_assets
		ORDER BY file_path, id
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assets []*model.MediaAsset
	for rows.Next() {
		asset := &model.MediaAsset{}
		err := rows.Scan(
			&asset.ID,
			&asset.CreatedAt,
			&asset.UpdatedAt,
			&asset.CapturedAt,
			&asset.FilePath,
			&asset.ThumbPath,
			&asset.PreviewPath,
			&asset.Hash,
			&asset.SizeBytes,
			&asset.MimeType,
			&asset.IsDeleted,
			&asset.SyncCount,
			&asset.GroupID,
			&asset.EditParams,
		)
		if err != nil {
			return nil, err
		}
		assets = append(assets, asset)
	}

	return assets, rows.Err()
}

// GetActiveAssets 获取未删除的媒体资产
func (r *Repository) GetActiveAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	rows, err := db.Pool.Query(ctx, `
		SELECT id, created_at, updated_at, captured_at, file_path, thumb_path,
		       preview_path, hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params
		FROM gallery.media_assets
		WHERE is_deleted = false
		ORDER BY file_path, id
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assets []*model.MediaAsset
	for rows.Next() {
		asset := &model.MediaAsset{}
		err := rows.Scan(
			&asset.ID,
			&asset.CreatedAt,
			&asset.UpdatedAt,
			&asset.CapturedAt,
			&asset.FilePath,
			&asset.ThumbPath,
			&asset.PreviewPath,
			&asset.Hash,
			&asset.SizeBytes,
			&asset.MimeType,
			&asset.IsDeleted,
			&asset.SyncCount,
			&asset.GroupID,
			&asset.EditParams,
		)
		if err != nil {
			return nil, err
		}
		assets = append(assets, asset)
	}

	return assets, rows.Err()
}

// UpdateMediaAssetFull 显式更新媒体资产所有字段
func (r *Repository) UpdateMediaAssetFull(ctx context.Context, asset *model.MediaAsset) error {
	_, err := db.Pool.Exec(ctx, `
		UPDATE gallery.media_assets SET
			created_at   = $1,
			updated_at   = $2,
			captured_at  = $3,
			file_path    = $4,
			thumb_path   = $5,
			preview_path = $6,
			hash         = $7,
			size_bytes   = $8,
			mime_type    = $9,
			is_deleted   = $10,
			sync_count   = $11,
			group_id     = $12,
			edit_params  = $13
		WHERE id = $14
	`,
		asset.CreatedAt,
		asset.UpdatedAt,
		asset.CapturedAt,
		asset.FilePath,
		asset.ThumbPath,
		asset.PreviewPath,
		asset.Hash,
		asset.SizeBytes,
		asset.MimeType,
		asset.IsDeleted,
		asset.SyncCount,
		asset.GroupID,
		asset.EditParams,
		asset.ID,
	)
	return err
}

// GetEditedAssets 获取所有有编辑参数且未删除的媒体资产
func (r *Repository) GetEditedAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	rows, err := db.Pool.Query(ctx, `
		SELECT id, created_at, updated_at, captured_at, file_path, thumb_path,
		       preview_path, hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params
		FROM gallery.media_assets
		WHERE edit_params IS NOT NULL AND is_deleted = false
		ORDER BY file_path, id
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assets []*model.MediaAsset
	for rows.Next() {
		asset := &model.MediaAsset{}
		err := rows.Scan(
			&asset.ID,
			&asset.CreatedAt,
			&asset.UpdatedAt,
			&asset.CapturedAt,
			&asset.FilePath,
			&asset.ThumbPath,
			&asset.PreviewPath,
			&asset.Hash,
			&asset.SizeBytes,
			&asset.MimeType,
			&asset.IsDeleted,
			&asset.SyncCount,
			&asset.GroupID,
			&asset.EditParams,
		)
		if err != nil {
			return nil, err
		}
		assets = append(assets, asset)
	}

	return assets, rows.Err()
}

// UpdateAssetAfterEdit 编辑后更新资产：更新 file_path/thumb_path/preview_path/hash/size_bytes/mime_type 并清除 edit_params
func (r *Repository) UpdateAssetAfterEdit(ctx context.Context, asset *model.MediaAsset) error {
	_, err := db.Pool.Exec(ctx, `
		UPDATE gallery.media_assets SET
			updated_at   = $1,
			file_path    = $2,
			thumb_path   = $3,
			preview_path = $4,
			hash         = $5,
			size_bytes   = $6,
			mime_type    = $7,
			edit_params  = NULL
		WHERE id = $8
	`,
		asset.UpdatedAt,
		asset.FilePath,
		asset.ThumbPath,
		asset.PreviewPath,
		asset.Hash,
		asset.SizeBytes,
		asset.MimeType,
		asset.ID,
	)
	return err
}
