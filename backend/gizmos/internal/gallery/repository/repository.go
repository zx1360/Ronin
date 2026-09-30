// Package repository 负责数据库操作
package repository

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/google/uuid"

	"gizmos/internal/dbutil"
	"gizmos/internal/gallery/model"
	"gizmos/internal/service/db"
)

// Repository 数据库操作仓库
type Repository struct{}

// NewRepository 创建新的仓库实例
func NewRepository() *Repository {
	return &Repository{}
}

// assetColumns 媒体资产的读取列清单（顺序与 scanAsset 一致）。
const assetColumns = `id, created_at, updated_at, captured_at, file_path, thumb_path,
	preview_path, hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params`

// HashExists 检查哈希是否已存在
func (r *Repository) HashExists(ctx context.Context, hash []byte) (bool, error) {
	var exists bool
	err := db.Read().QueryRowContext(ctx,
		`SELECT EXISTS(SELECT 1 FROM media_assets WHERE hash = ?)`,
		hash,
	).Scan(&exists)
	return exists, err
}

// BatchInsertMediaAssets 批量插入媒体资产（单事务提交，调用方已按 batch 分段）。
func (r *Repository) BatchInsertMediaAssets(ctx context.Context, assets []*model.MediaAsset) error {
	if len(assets) == 0 {
		return nil
	}

	tx, err := db.Write().BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback() //nolint:errcheck // 提交后为无操作

	stmt, err := tx.PrepareContext(ctx, `
		INSERT INTO media_assets (
			id, captured_at, file_path, thumb_path, preview_path,
			hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (hash) DO NOTHING`)
	if err != nil {
		return fmt.Errorf("准备批量插入失败: %w", err)
	}
	defer stmt.Close()

	for _, asset := range assets {
		if _, err := stmt.ExecContext(ctx,
			asset.ID,
			dbutil.TS(asset.CapturedAt),
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
		); err != nil {
			return fmt.Errorf("批量插入失败: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("提交批量插入失败: %w", err)
	}
	return nil
}

// scanAssets 按 assetColumns 顺序扫描结果集（时间列存本地时间文本）。
func scanAssets(rows *sql.Rows) ([]*model.MediaAsset, error) {
	var assets []*model.MediaAsset
	for rows.Next() {
		asset := &model.MediaAsset{}
		var createdAt, updatedAt, capturedAt string
		err := rows.Scan(
			&asset.ID,
			&createdAt,
			&updatedAt,
			&capturedAt,
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
		asset.CreatedAt = dbutil.Time(createdAt)
		asset.UpdatedAt = dbutil.Time(updatedAt)
		asset.CapturedAt = dbutil.Time(capturedAt)
		assets = append(assets, asset)
	}
	return assets, rows.Err()
}

// queryAssets 执行查询并扫描结果。
func queryAssets(ctx context.Context, query string, args ...any) ([]*model.MediaAsset, error) {
	rows, err := db.Read().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanAssets(rows)
}

// GetDeletedAssets 获取标记为删除的媒体资产
func (r *Repository) GetDeletedAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	return queryAssets(ctx, `SELECT `+assetColumns+` FROM media_assets WHERE is_deleted = 1`)
}

// GetGroupedAssets 获取被捆绑到指定主文件的所有资产
func (r *Repository) GetGroupedAssets(ctx context.Context, groupID uuid.UUID) ([]*model.MediaAsset, error) {
	return queryAssets(ctx, `SELECT `+assetColumns+` FROM media_assets WHERE group_id = ?`, groupID)
}

// DeleteAssetRecord 物理删除数据库记录
func (r *Repository) DeleteAssetRecord(ctx context.Context, id uuid.UUID) error {
	_, err := db.Write().ExecContext(ctx, `DELETE FROM media_assets WHERE id = ?`, id)
	return err
}

// BatchDeleteAssetRecords 批量删除数据库记录
func (r *Repository) BatchDeleteAssetRecords(ctx context.Context, ids []uuid.UUID) error {
	if len(ids) == 0 {
		return nil
	}
	_, err := db.Write().ExecContext(ctx,
		`DELETE FROM media_assets WHERE id IN (`+dbutil.Placeholders(len(ids))+`)`,
		uuidArgs(ids)...)
	return err
}

// GetAllAssets 获取所有媒体资产（包含 is_deleted=1 记录）
func (r *Repository) GetAllAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	return queryAssets(ctx, `SELECT `+assetColumns+` FROM media_assets ORDER BY file_path, id`)
}

// GetActiveAssets 获取未删除的媒体资产
func (r *Repository) GetActiveAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	return queryAssets(ctx, `SELECT `+assetColumns+` FROM media_assets WHERE is_deleted = 0 ORDER BY file_path, id`)
}

// UpdateMediaAssetFull 显式更新媒体资产所有字段
func (r *Repository) UpdateMediaAssetFull(ctx context.Context, asset *model.MediaAsset) error {
	_, err := db.Write().ExecContext(ctx, `
		UPDATE media_assets SET
			created_at   = ?,
			updated_at   = ?,
			captured_at  = ?,
			file_path    = ?,
			thumb_path   = ?,
			preview_path = ?,
			hash         = ?,
			size_bytes   = ?,
			mime_type    = ?,
			is_deleted   = ?,
			sync_count   = ?,
			group_id     = ?,
			edit_params  = ?
		WHERE id = ?
	`,
		dbutil.TS(asset.CreatedAt),
		dbutil.TS(asset.UpdatedAt),
		dbutil.TS(asset.CapturedAt),
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
	return queryAssets(ctx, `SELECT `+assetColumns+
		` FROM media_assets WHERE edit_params IS NOT NULL AND is_deleted = 0 ORDER BY file_path, id`)
}

// UpdateAssetAfterEdit 编辑后更新资产：更新 file_path/thumb_path/preview_path/hash/size_bytes/mime_type 并清除 edit_params
func (r *Repository) UpdateAssetAfterEdit(ctx context.Context, asset *model.MediaAsset) error {
	_, err := db.Write().ExecContext(ctx, `
		UPDATE media_assets SET
			updated_at   = ?,
			file_path    = ?,
			thumb_path   = ?,
			preview_path = ?,
			hash         = ?,
			size_bytes   = ?,
			mime_type    = ?,
			edit_params  = NULL
		WHERE id = ?
	`,
		dbutil.TS(asset.UpdatedAt),
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

// ClearEditParams 仅清除指定资产的 edit_params（用于"无操作编辑"场景，不触碰任何文件）
func (r *Repository) ClearEditParams(ctx context.Context, id uuid.UUID) error {
	_, err := db.Write().ExecContext(ctx, `
		UPDATE media_assets SET
			updated_at  = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'),
			edit_params = NULL
		WHERE id = ?
	`, id)
	return err
}

// uuidArgs 把 UUID 列表转为 SQL 参数。
func uuidArgs(ids []uuid.UUID) []any {
	args := make([]any, len(ids))
	for i, id := range ids {
		args[i] = id
	}
	return args
}
