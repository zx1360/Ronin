// Package repository 负责数据库操作
package repository

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"gizmos/internal/gallery/model"
	"gizmos/internal/service/db"
)

// Repository 数据库操作仓库
type Repository struct{}

// NewRepository 创建新的仓库实例
func NewRepository() *Repository {
	return &Repository{}
}

// assetColumns 是媒体资产的全部列，顺序与 scanAsset 一致。
const assetColumns = `id, created_at, updated_at, captured_at, file_path, thumb_path,
		       preview_path, hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params`

// sqlParamChunk 单条 SQL 的绑定参数分片上限，规避 SQLite 变量数上限。
const sqlParamChunk = 500

// timeLayout 与 monarch 侧一致：UTC、毫秒、定宽，字典序即时序。
const timeLayout = "2006-01-02T15:04:05.000Z"

// formatTime 把时间归一化为存储格式。
func formatTime(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.UTC().Format(timeLayout)
}

// parseTime 解析存储格式的时间文本（空值视为零值）。
func parseTime(s string) (time.Time, error) {
	if strings.TrimSpace(s) == "" {
		return time.Time{}, nil
	}
	t, err := time.Parse(timeLayout, s)
	if err != nil {
		return time.Time{}, fmt.Errorf("解析时间失败: %q", s)
	}
	return t.UTC(), nil
}

// writeTime 归一化写入时间：零值用当前时间兜底（created_at/updated_at 为 NOT NULL）。
func writeTime(t time.Time) string {
	if t.IsZero() {
		return formatTime(time.Now())
	}
	return formatTime(t)
}

// scanAsset 扫描一行媒体资产；时间列为 TEXT，按统一格式解析（不依赖 SQLite 亲和性）。
func scanAsset(rows *sql.Rows) (*model.MediaAsset, error) {
	var (
		asset                            model.MediaAsset
		createdAt, updatedAt, capturedAt string
	)
	if err := rows.Scan(
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
	); err != nil {
		return nil, err
	}

	var err error
	if asset.CreatedAt, err = parseTime(createdAt); err != nil {
		return nil, err
	}
	if asset.UpdatedAt, err = parseTime(updatedAt); err != nil {
		return nil, err
	}
	if asset.CapturedAt, err = parseTime(capturedAt); err != nil {
		return nil, err
	}
	return &asset, nil
}

// collectAssets 遍历结果集并扫描全部行。
func collectAssets(rows *sql.Rows) ([]*model.MediaAsset, error) {
	defer rows.Close()

	var assets []*model.MediaAsset
	for rows.Next() {
		asset, err := scanAsset(rows)
		if err != nil {
			return nil, err
		}
		assets = append(assets, asset)
	}
	return assets, rows.Err()
}

// HashExists 检查哈希是否已存在
func (r *Repository) HashExists(ctx context.Context, hash []byte) (bool, error) {
	var exists bool
	err := db.R().QueryRowContext(ctx,
		`SELECT EXISTS(SELECT 1 FROM gallery_media_assets WHERE hash = ?)`,
		hash,
	).Scan(&exists)
	return exists, err
}

// BatchInsertMediaAssets 批量插入媒体资产。
//
// 整批在单个事务内逐条执行：要么全部写入、要么整批回滚。
// created_at/updated_at 为 NOT NULL 且无默认值，未设置时补当前时间。
func (r *Repository) BatchInsertMediaAssets(ctx context.Context, assets []*model.MediaAsset) error {
	if len(assets) == 0 {
		return nil
	}

	const insertSQL = `
		INSERT INTO gallery_media_assets (
			id, captured_at, file_path, thumb_path, preview_path,
			hash, size_bytes, mime_type, is_deleted, sync_count, group_id, edit_params,
			created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (hash) DO NOTHING
	`

	return db.Tx(ctx, func(tx *sql.Tx) error {
		now := time.Now()
		for _, asset := range assets {
			createdAt := asset.CreatedAt
			if createdAt.IsZero() {
				createdAt = now
			}
			updatedAt := asset.UpdatedAt
			if updatedAt.IsZero() {
				updatedAt = createdAt
			}
			if _, err := tx.ExecContext(ctx, insertSQL,
				asset.ID,
				formatTime(asset.CapturedAt),
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
				formatTime(createdAt),
				formatTime(updatedAt),
			); err != nil {
				return fmt.Errorf("批量插入失败: %w", err)
			}
		}
		return nil
	})
}

// GetDeletedAssets 获取标记为删除的媒体资产
func (r *Repository) GetDeletedAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	rows, err := db.R().QueryContext(ctx, `
		SELECT `+assetColumns+`
		FROM gallery_media_assets
		WHERE is_deleted = 1
	`)
	if err != nil {
		return nil, err
	}
	return collectAssets(rows)
}

// GetGroupedAssets 获取被捆绑到指定主文件的所有资产
func (r *Repository) GetGroupedAssets(ctx context.Context, groupID uuid.UUID) ([]*model.MediaAsset, error) {
	rows, err := db.R().QueryContext(ctx, `
		SELECT `+assetColumns+`
		FROM gallery_media_assets
		WHERE group_id = ?
	`, groupID)
	if err != nil {
		return nil, err
	}
	return collectAssets(rows)
}

// DeleteAssetRecord 物理删除数据库记录
func (r *Repository) DeleteAssetRecord(ctx context.Context, id uuid.UUID) error {
	_, err := db.W().ExecContext(ctx, `DELETE FROM gallery_media_assets WHERE id = ?`, id)
	return err
}

// BatchDeleteAssetRecords 批量删除数据库记录。
//
// 按 sqlParamChunk 分片绑定（规避 SQLite 变量数上限），整体在单个事务内，全成功或全回滚。
func (r *Repository) BatchDeleteAssetRecords(ctx context.Context, ids []uuid.UUID) error {
	if len(ids) == 0 {
		return nil
	}

	return db.Tx(ctx, func(tx *sql.Tx) error {
		for start := 0; start < len(ids); start += sqlParamChunk {
			chunk := ids[start:min(start+sqlParamChunk, len(ids))]
			args := make([]any, len(chunk))
			marks := make([]string, len(chunk))
			for i, id := range chunk {
				args[i] = id
				marks[i] = "?"
			}
			if _, err := tx.ExecContext(ctx,
				`DELETE FROM gallery_media_assets WHERE id IN (`+strings.Join(marks, ", ")+`)`, args...); err != nil {
				return err
			}
		}
		return nil
	})
}

// GetAllAssets 获取所有媒体资产（包含 is_deleted=true 记录）
func (r *Repository) GetAllAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	rows, err := db.R().QueryContext(ctx, `
		SELECT `+assetColumns+`
		FROM gallery_media_assets
		ORDER BY file_path, id
	`)
	if err != nil {
		return nil, err
	}
	return collectAssets(rows)
}

// GetActiveAssets 获取未删除的媒体资产
func (r *Repository) GetActiveAssets(ctx context.Context) ([]*model.MediaAsset, error) {
	rows, err := db.R().QueryContext(ctx, `
		SELECT `+assetColumns+`
		FROM gallery_media_assets
		WHERE is_deleted = 0
		ORDER BY file_path, id
	`)
	if err != nil {
		return nil, err
	}
	return collectAssets(rows)
}

// UpdateMediaAssetFull 显式更新媒体资产所有字段
func (r *Repository) UpdateMediaAssetFull(ctx context.Context, asset *model.MediaAsset) error {
	_, err := db.W().ExecContext(ctx, `
		UPDATE gallery_media_assets SET
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
		writeTime(asset.CreatedAt),
		writeTime(asset.UpdatedAt),
		formatTime(asset.CapturedAt),
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
	rows, err := db.R().QueryContext(ctx, `
		SELECT `+assetColumns+`
		FROM gallery_media_assets
		WHERE edit_params IS NOT NULL AND is_deleted = 0
		ORDER BY file_path, id
	`)
	if err != nil {
		return nil, err
	}
	return collectAssets(rows)
}

// UpdateAssetAfterEdit 编辑后更新资产：更新 file_path/thumb_path/preview_path/hash/size_bytes/mime_type 并清除 edit_params
func (r *Repository) UpdateAssetAfterEdit(ctx context.Context, asset *model.MediaAsset) error {
	_, err := db.W().ExecContext(ctx, `
		UPDATE gallery_media_assets SET
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
		writeTime(asset.UpdatedAt),
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

// ClearEditParams 仅清除指定资产的 edit_params（用于"无操作编辑"场景，不触碰任何文件）。
//
// 触发器已移除，updated_at 必须显式写入；这里传 Go 侧当前时间（等价旧 NOW()）。
func (r *Repository) ClearEditParams(ctx context.Context, id uuid.UUID) error {
	_, err := db.W().ExecContext(ctx, `
		UPDATE gallery_media_assets SET
			updated_at  = ?,
			edit_params = NULL
		WHERE id = ?
	`, formatTime(time.Now()), id)
	return err
}
