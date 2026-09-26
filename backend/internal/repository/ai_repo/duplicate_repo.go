package ai_repo

import (
	"github.com/google/uuid"

	"monarch/internal/service/db"
)

// 去重人工判定：被标记为"非重复"的媒体不再参与近重复分组。

// ListDuplicateIgnoreIDs 返回全部被标记为"非重复"的媒体 ID（按标记时间倒序）。
func ListDuplicateIgnoreIDs() ([]uuid.UUID, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx,
		`SELECT media_id FROM ai.duplicate_ignores ORDER BY created_at DESC`)
	if err != nil {
		return nil, err
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

	tag, err := db.GetPool().Exec(ctx, `
		INSERT INTO ai.duplicate_ignores (media_id)
		SELECT unnest($1::uuid[])
		ON CONFLICT (media_id) DO NOTHING`, ids)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// UnignoreDuplicates 取消"非重复"标记，返回恢复条数。
func UnignoreDuplicates(ids []uuid.UUID) (int64, error) {
	if len(ids) == 0 {
		return 0, nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tag, err := db.GetPool().Exec(ctx,
		`DELETE FROM ai.duplicate_ignores WHERE media_id = ANY($1)`, ids)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
