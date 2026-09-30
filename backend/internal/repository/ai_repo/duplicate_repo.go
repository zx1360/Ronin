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

	rows, err := db.Read().QueryContext(ctx,
		`SELECT media_id FROM duplicate_ignores ORDER BY created_at DESC`)
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

	values := make([]string, 0, len(ids))
	args := make([]any, 0, len(ids))
	for _, id := range ids {
		values = append(values, "(?)")
		args = append(args, id)
	}
	res, err := db.Exec(ctx,
		`INSERT INTO duplicate_ignores (media_id) VALUES `+joinValues(values)+
			` ON CONFLICT (media_id) DO NOTHING`, args...)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	return n, nil
}

// UnignoreDuplicates 取消"非重复"标记，返回恢复条数。
func UnignoreDuplicates(ids []uuid.UUID) (int64, error) {
	if len(ids) == 0 {
		return 0, nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	res, err := db.Exec(ctx,
		`DELETE FROM duplicate_ignores WHERE media_id IN (`+placeholders(len(ids))+`)`,
		uuidArgs(ids)...)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	return n, nil
}
