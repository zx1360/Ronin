package ai_repo

import (
	"database/sql"
	"fmt"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// 去重人工判定：被标记为"非重复"的媒体不再参与近重复分组。

// ListDuplicateIgnoreIDs 返回全部被标记为"非重复"的媒体 ID（按标记时间倒序）。
func ListDuplicateIgnoreIDs() ([]uuid.UUID, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx,
		`SELECT media_id FROM ai_duplicate_ignores ORDER BY created_at DESC`)
	if err != nil {
		return nil, fmt.Errorf("查询非重复标记失败: %w", err)
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// LoadDuplicateIgnores 返回被忽略媒体的集合（分组计算用）。
func LoadDuplicateIgnores() (map[uuid.UUID]struct{}, error) {
	ids, err := ListDuplicateIgnoreIDs()
	if err != nil {
		return nil, err
	}
	set := make(map[uuid.UUID]struct{}, len(ids))
	for _, id := range ids {
		set[id] = struct{}{}
	}
	return set, nil
}

// IgnoreDuplicates 追加"非重复"标记（幂等），返回实际新增条数。
func IgnoreDuplicates(ids []uuid.UUID) (int64, error) {
	if len(ids) == 0 {
		return 0, nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	var inserted int64
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		inserted = 0
		now := model.Now()
		for _, id := range ids {
			res, err := tx.ExecContext(ctx, `
				INSERT INTO ai_duplicate_ignores (media_id, created_at) VALUES (?, ?)
				ON CONFLICT (media_id) DO NOTHING`, id, now)
			if err != nil {
				return fmt.Errorf("标记非重复失败: %w", err)
			}
			n, err := res.RowsAffected()
			if err != nil {
				return err
			}
			inserted += n
		}
		return nil
	})
	if err != nil {
		return 0, err
	}
	return inserted, nil
}

// UnignoreDuplicates 取消"非重复"标记，返回恢复条数。
func UnignoreDuplicates(ids []uuid.UUID) (int64, error) {
	if len(ids) == 0 {
		return 0, nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	res, err := db.W().ExecContext(ctx,
		`DELETE FROM ai_duplicate_ignores WHERE media_id IN (`+placeholders(len(ids))+`)`,
		anyArgs(ids)...)
	if err != nil {
		return 0, fmt.Errorf("取消非重复标记失败: %w", err)
	}
	return res.RowsAffected()
}
