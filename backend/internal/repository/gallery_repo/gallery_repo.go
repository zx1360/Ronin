package gallery_repo

import (
	"context"
	"errors"
	"fmt"
	"monarch/internal/model"
	"monarch/internal/service/db"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// FetchMediaAssets 分页获取未删除的媒体资产
func FetchMediaAssets(limit int, offset int) ([]model.MediaAsset, error) {
	return FetchMediaAssetsWithParams(model.BatchQueryParams{
		Limit:  limit,
		Offset: offset,
	})
}

// buildWhereClause 构建 WHERE 条件（供 FetchMediaAssetsWithParams 和 CountMediaAssetsWithParams 共用）
func buildWhereClause(params model.BatchQueryParams) (string, []interface{}) {
	conditions := []string{"is_deleted = false"}
	args := []interface{}{}
	argIdx := 1

	if params.MimeType != "" {
		if strings.Contains(params.MimeType, "/") {
			conditions = append(conditions, fmt.Sprintf("mime_type = $%d", argIdx))
			args = append(args, params.MimeType)
			argIdx++
		} else {
			conditions = append(conditions, fmt.Sprintf("mime_type LIKE $%d", argIdx))
			args = append(args, params.MimeType+"/%")
			argIdx++
		}
	}

	if params.Year > 0 {
		if params.Month > 0 {
			if params.Day > 0 {
				conditions = append(conditions,
					fmt.Sprintf("DATE(captured_at) = $%d", argIdx))
				args = append(args, fmt.Sprintf("%04d-%02d-%02d", params.Year, params.Month, params.Day))
				argIdx++
			} else {
				conditions = append(conditions,
					fmt.Sprintf("EXTRACT(YEAR FROM captured_at) = $%d AND EXTRACT(MONTH FROM captured_at) = $%d", argIdx, argIdx+1))
				args = append(args, params.Year, params.Month)
				argIdx += 2
			}
		} else {
			conditions = append(conditions,
				fmt.Sprintf("EXTRACT(YEAR FROM captured_at) = $%d", argIdx))
			args = append(args, params.Year)
			argIdx++
		}
	}

	return strings.Join(conditions, " AND "), args
}

// FetchMediaAssetsWithParams 根据查询参数获取媒体资产（支持筛选和排序）
func FetchMediaAssetsWithParams(params model.BatchQueryParams) ([]model.MediaAsset, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	whereClause, whereArgs := buildWhereClause(params)

	orderClause := buildOrderClause(params)

	argIdx := len(whereArgs) + 1
	query := fmt.Sprintf(`
		SELECT 
			id, created_at, updated_at, captured_at, file_path, 
			thumb_path, preview_path, hash, size_bytes, mime_type, 
			is_deleted, sync_count, group_id, COALESCE(message, ''), edit_params
		FROM gallery.media_assets
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, whereClause, orderClause, argIdx, argIdx+1)
	args := append(whereArgs, params.Limit, params.Offset)

	rows, err := db.GetPool().Query(ctx, query, args...)
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

	if assets == nil {
		assets = []model.MediaAsset{}
	}
	return assets, nil
}

// buildOrderClause 构建 ORDER BY 子句
func buildOrderClause(params model.BatchQueryParams) string {
	// 验证并映射排序字段
	allowedSortFields := map[string]string{
		"sync_count":  "sync_count",
		"captured_at": "captured_at",
		"size_bytes":  "size_bytes",
		"file_path":   "file_path",
	}

	// 默认排序
	primaryField := "sync_count"
	primaryOrder := "ASC"
	secondaryField := "captured_at"
	secondaryOrder := "ASC"

	if params.SortBy != "" {
		if dbField, ok := allowedSortFields[params.SortBy]; ok {
			primaryField = dbField
		}
	}
	if params.SortOrder != "" {
		orderUpper := strings.ToUpper(params.SortOrder)
		if orderUpper == "DESC" || orderUpper == "ASC" {
			primaryOrder = orderUpper
			secondaryOrder = orderUpper
		}
	}

	// 二次排序：在默认/主排序之后添加额外排序
	extraOrder := ""
	if params.SecondarySort != "" {
		if dbField, ok := allowedSortFields[params.SecondarySort]; ok {
			extraOrder = fmt.Sprintf(", %s %s", dbField, primaryOrder)
		}
	}

	return fmt.Sprintf("%s %s, %s %s%s",
		primaryField, primaryOrder, secondaryField, secondaryOrder, extraOrder)
}

// CountMediaAssetsWithParams 根据筛选条件统计媒体资产数量
func CountMediaAssetsWithParams(params model.BatchQueryParams) (int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	whereClause, whereArgs := buildWhereClause(params)

	query := fmt.Sprintf(
		"SELECT COUNT(*) FROM gallery.media_assets WHERE %s",
		whereClause,
	)

	var count int
	err := db.GetPool().QueryRow(ctx, query, whereArgs...).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("统计媒体资产失败: %w", err)
	}

	return count, nil
}

// FetchGalleryOverview 获取画廊总览统计数据
func FetchGalleryOverview() (*model.GalleryOverview, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	overview := &model.GalleryOverview{}

	// 1. 按类型统计媒体数量与总大小
	typeStatQuery := `
		SELECT 
			COUNT(*) as total,
			COALESCE(SUM(CASE WHEN mime_type LIKE 'image/%' THEN 1 ELSE 0 END), 0) as images,
			COALESCE(SUM(CASE WHEN mime_type LIKE 'video/%' THEN 1 ELSE 0 END), 0) as videos,
			COALESCE(SUM(size_bytes), 0) as total_size
		FROM gallery.media_assets
		WHERE is_deleted = false
	`
	err := db.GetPool().QueryRow(ctx, typeStatQuery).Scan(
		&overview.TotalMedia, &overview.ImageCount, &overview.VideoCount, &overview.TotalSize,
	)
	if err != nil {
		return nil, fmt.Errorf("查询媒体统计失败: %w", err)
	}

	if overview.TotalMedia > 0 {
		overview.ImageRatio = float64(overview.ImageCount) / float64(overview.TotalMedia)
		overview.VideoRatio = float64(overview.VideoCount) / float64(overview.TotalMedia)
	}

	// 2. 标签统计
	tagStatQuery := `
		SELECT 
			(SELECT COUNT(*) FROM gallery.tags) as total_tags,
			(SELECT COUNT(*) FROM gallery.tags WHERE parent_id IS NULL) as root_tags,
			(SELECT COUNT(*) FROM gallery.media_tag_links) as total_links
	`
	err = db.GetPool().QueryRow(ctx, tagStatQuery).Scan(
		&overview.TotalTags, &overview.RootTags, &overview.TotalLinks,
	)
	if err != nil {
		return nil, fmt.Errorf("查询标签统计失败: %w", err)
	}

	// 3. sync_count 统计
	syncStatQuery := `
		SELECT 
			COALESCE(MIN(sync_count), 0),
			COALESCE(MAX(sync_count), 0),
			COALESCE(AVG(sync_count), 0)
		FROM gallery.media_assets
		WHERE is_deleted = false
	`
	err = db.GetPool().QueryRow(ctx, syncStatQuery).Scan(
		&overview.SyncStats.MinSyncCount,
		&overview.SyncStats.MaxSyncCount,
		&overview.SyncStats.AvgSyncCount,
	)
	if err != nil {
		return nil, fmt.Errorf("查询同步统计失败: %w", err)
	}

	// 4. 按年份统计
	yearStatQuery := `
		SELECT EXTRACT(YEAR FROM captured_at)::int as year, COUNT(*) as cnt
		FROM gallery.media_assets
		WHERE is_deleted = false AND captured_at IS NOT NULL
		GROUP BY year
		ORDER BY year DESC
	`
	rows, err := db.GetPool().Query(ctx, yearStatQuery)
	if err != nil {
		return nil, fmt.Errorf("查询年份统计失败: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var item model.YearStatItem
		if err := rows.Scan(&item.Year, &item.MediaCount); err != nil {
			return nil, fmt.Errorf("扫描年份统计失败: %w", err)
		}
		overview.YearStats = append(overview.YearStats, item)
	}

	// 查询 min/max captured_at 年份
	yearRangeQuery := `
		SELECT 
			COALESCE(EXTRACT(YEAR FROM MIN(captured_at))::int, 0),
			COALESCE(EXTRACT(YEAR FROM MAX(captured_at))::int, 0)
		FROM gallery.media_assets
		WHERE is_deleted = false AND captured_at IS NOT NULL
	`
	if err := db.GetPool().QueryRow(ctx, yearRangeQuery).Scan(
		&overview.MinYear, &overview.MaxYear,
	); err != nil {
		// 非致命错误，MinYear/MaxYear 保持 0
	}

	return overview, nil
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

// FetchAllTags 获取所有标签（含收藏标记与直接关联的媒体数）
func FetchAllTags() ([]model.Tag, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		SELECT t.id, t.created_at, t.updated_at, t.name, t.parent_id, t.full_path, t.is_favorite,
			(SELECT COUNT(*) FROM gallery.media_tag_links l
				JOIN gallery.media_assets m ON m.id = l.media_id
				WHERE l.tag_id = t.id AND m.is_deleted = false) AS media_count
		FROM gallery.tags t
		ORDER BY t.full_path ASC
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
			&tag.ParentID, &tag.FullPath, &tag.IsFavorite, &tag.MediaCount,
		)
		if err != nil {
			return nil, fmt.Errorf("扫描标签行失败: %w", err)
		}
		tags = append(tags, tag)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历标签结果集失败: %w", err)
	}

	if tags == nil {
		tags = []model.Tag{}
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

	if links == nil {
		links = []model.MediaTagLink{}
	}
	return links, nil
}

// ============ 标签写操作（服务端权威） ============

// 标签/媒体操作的可识别错误（由 handler 映射为 400/404/409）
var (
	ErrTagNotFound       = errors.New("标签不存在")
	ErrTagNameConflict   = errors.New("同级已存在同名标签")
	ErrTagParentNotFound = errors.New("父标签不存在")
	ErrTagCycle          = errors.New("不能将标签移动到其子孙节点下")
	ErrTagEmptyName      = errors.New("标签名不能为空")
	ErrMediaNotFound     = errors.New("媒体不存在")
	ErrMediaSelfGroup    = errors.New("媒体不能捆绑到自身")
)

// TagPatch 标签更新意图（nil 字段表示不修改）
type TagPatch struct {
	Name       *string
	ParentID   *uuid.UUID // 目标父标签
	MoveToRoot bool       // 移动到根级（与 ParentID 互斥）
	IsFavorite *bool
}

// FetchTagByID 获取单个标签
func FetchTagByID(id uuid.UUID) (*model.Tag, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	var tag model.Tag
	err := db.GetPool().QueryRow(ctx, `
		SELECT id, created_at, updated_at, name, parent_id, full_path, is_favorite
		FROM gallery.tags WHERE id = $1`, id).Scan(
		&tag.ID, &tag.CreatedAt, &tag.UpdatedAt, &tag.Name,
		&tag.ParentID, &tag.FullPath, &tag.IsFavorite,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("查询标签失败: %w", err)
	}
	return &tag, nil
}

// FetchDescendantTagIDs 递归获取指定标签的所有子孙 ID（不含自身）
func FetchDescendantTagIDs(id uuid.UUID) ([]uuid.UUID, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `
		WITH RECURSIVE sub AS (
			SELECT id FROM gallery.tags WHERE parent_id = $1
			UNION ALL
			SELECT t.id FROM gallery.tags t JOIN sub ON t.parent_id = sub.id
		) SELECT id FROM sub`, id)
	if err != nil {
		return nil, fmt.Errorf("查询子孙标签失败: %w", err)
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var childID uuid.UUID
		if err := rows.Scan(&childID); err != nil {
			return nil, fmt.Errorf("扫描子孙标签失败: %w", err)
		}
		ids = append(ids, childID)
	}
	return ids, rows.Err()
}

// CreateTag 创建标签（full_path 由数据库触发器维护）
func CreateTag(name string, parentID *uuid.UUID) (*model.Tag, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, ErrTagEmptyName
	}

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	if err := ensureParentExist(ctx, tx, parentID); err != nil {
		return nil, err
	}
	if err := ensureSiblingNameFree(ctx, tx, name, parentID, nil); err != nil {
		return nil, err
	}

	id := uuid.New()
	if _, err := tx.Exec(ctx,
		`INSERT INTO gallery.tags (id, name, parent_id) VALUES ($1, $2, $3)`,
		id, name, parentID); err != nil {
		return nil, classifyTagWriteError(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("提交事务失败: %w", err)
	}
	return FetchTagByID(id)
}

// UpdateTag 按 [TagPatch] 更新标签（改名/移动/收藏）
func UpdateTag(id uuid.UUID, patch TagPatch) (*model.Tag, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	var currentName string
	var currentParent *uuid.UUID
	err = tx.QueryRow(ctx,
		`SELECT name, parent_id FROM gallery.tags WHERE id = $1 FOR UPDATE`, id).
		Scan(&currentName, &currentParent)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrTagNotFound
		}
		return nil, fmt.Errorf("查询标签失败: %w", err)
	}

	sets := []string{}
	args := []interface{}{}
	argIdx := 1
	add := func(expr string, value interface{}) {
		sets = append(sets, fmt.Sprintf(expr, argIdx))
		args = append(args, value)
		argIdx++
	}

	effectiveName := currentName
	if patch.Name != nil {
		effectiveName = strings.TrimSpace(*patch.Name)
		if effectiveName == "" {
			return nil, ErrTagEmptyName
		}
		add("name = $%d", effectiveName)
	}

	effectiveParent := currentParent
	if patch.MoveToRoot || patch.ParentID != nil {
		effectiveParent = nil
		if patch.ParentID != nil {
			if *patch.ParentID == id {
				return nil, ErrTagCycle
			}
			descendants, err := FetchDescendantTagIDs(id)
			if err != nil {
				return nil, err
			}
			for _, descendant := range descendants {
				if descendant == *patch.ParentID {
					return nil, ErrTagCycle
				}
			}
			effectiveParent = patch.ParentID
		}
		if err := ensureParentExist(ctx, tx, effectiveParent); err != nil {
			return nil, err
		}
		add("parent_id = $%d", effectiveParent)
	}

	// (name, parent_id) 唯一性：数据库 UNIQUE 约束不覆盖 parent_id IS NULL，这里显式校验
	if patch.Name != nil || patch.MoveToRoot || patch.ParentID != nil {
		if err := ensureSiblingNameFree(ctx, tx, effectiveName, effectiveParent, &id); err != nil {
			return nil, err
		}
	}

	if patch.IsFavorite != nil {
		add("is_favorite = $%d", *patch.IsFavorite)
	}

	if len(sets) > 0 {
		args = append(args, id)
		query := fmt.Sprintf(`UPDATE gallery.tags SET %s WHERE id = $%d`,
			strings.Join(sets, ", "), argIdx)
		if _, err := tx.Exec(ctx, query, args...); err != nil {
			return nil, classifyTagWriteError(err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("提交事务失败: %w", err)
	}
	return FetchTagByID(id)
}

// ensureParentExist 校验父标签存在
func ensureParentExist(ctx context.Context, tx pgx.Tx, parentID *uuid.UUID) error {
	if parentID == nil {
		return nil
	}
	var exists bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM gallery.tags WHERE id = $1)`, *parentID).Scan(&exists); err != nil {
		return fmt.Errorf("校验父标签失败: %w", err)
	}
	if !exists {
		return ErrTagParentNotFound
	}
	return nil
}

// ensureSiblingNameFree 校验同级同名（NULL 父级也参与比较）
func ensureSiblingNameFree(ctx context.Context, tx pgx.Tx, name string, parentID *uuid.UUID, excludeID *uuid.UUID) error {
	var exists bool
	err := tx.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM gallery.tags
			WHERE name = $1
				AND parent_id IS NOT DISTINCT FROM $2
				AND ($3::uuid IS NULL OR id <> $3)
		)`, name, parentID, excludeID).Scan(&exists)
	if err != nil {
		return fmt.Errorf("校验同级同名失败: %w", err)
	}
	if exists {
		return ErrTagNameConflict
	}
	return nil
}

// DeleteTag 删除标签，返回被删除的全部 ID（含级联删除的子孙）
func DeleteTag(id uuid.UUID) ([]uuid.UUID, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	var exists bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM gallery.tags WHERE id = $1)`, id).Scan(&exists); err != nil {
		return nil, fmt.Errorf("查询标签失败: %w", err)
	}
	if !exists {
		return nil, ErrTagNotFound
	}

	rows, err := tx.Query(ctx, `
		WITH RECURSIVE sub AS (
			SELECT id FROM gallery.tags WHERE parent_id = $1
			UNION ALL
			SELECT t.id FROM gallery.tags t JOIN sub ON t.parent_id = sub.id
		) SELECT id FROM sub`, id)
	if err != nil {
		return nil, fmt.Errorf("查询子孙标签失败: %w", err)
	}
	deleted := []uuid.UUID{}
	for rows.Next() {
		var childID uuid.UUID
		if err := rows.Scan(&childID); err != nil {
			rows.Close()
			return nil, fmt.Errorf("扫描子孙标签失败: %w", err)
		}
		deleted = append(deleted, childID)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历子孙标签失败: %w", err)
	}

	// 子标签与标签关联由外键 ON DELETE CASCADE 清理
	if _, err := tx.Exec(ctx, `DELETE FROM gallery.tags WHERE id = $1`, id); err != nil {
		return nil, fmt.Errorf("删除标签失败: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("提交事务失败: %w", err)
	}

	return append(deleted, id), nil
}

// classifyTagWriteError 把数据库约束错误归一化为可识别的业务错误
func classifyTagWriteError(err error) error {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch pgErr.Code {
		case "23505": // unique_violation
			return ErrTagNameConflict
		case "23503": // foreign_key_violation
			return ErrTagParentNotFound
		}
	}
	return fmt.Errorf("写入标签失败: %w", err)
}

// ============ 媒体-标签关联写操作 ============

// ReplaceMediaTags 全量替换单个媒体的标签集合
func ReplaceMediaTags(mediaID uuid.UUID, tagIDs []uuid.UUID) ([]uuid.UUID, error) {
	unique := uniqueUUIDs(tagIDs)

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	if err := ensureMediaExist(ctx, tx, []uuid.UUID{mediaID}); err != nil {
		return nil, err
	}
	if err := ensureTagsExist(ctx, tx, unique); err != nil {
		return nil, err
	}

	if _, err := tx.Exec(ctx,
		`DELETE FROM gallery.media_tag_links WHERE media_id = $1`, mediaID); err != nil {
		return nil, fmt.Errorf("清除旧标签关联失败: %w", err)
	}
	if len(unique) > 0 {
		if _, err := tx.Exec(ctx, `
			INSERT INTO gallery.media_tag_links (media_id, tag_id)
			SELECT $1, unnest($2::uuid[])
			ON CONFLICT DO NOTHING`, mediaID, unique); err != nil {
			return nil, fmt.Errorf("写入标签关联失败: %w", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("提交事务失败: %w", err)
	}
	return unique, nil
}

// AddRemoveMediaTags 批量为多个媒体增删标签，返回受影响的关联行数
func AddRemoveMediaTags(mediaIDs, addTagIDs, removeTagIDs []uuid.UUID) (int64, error) {
	mediaIDs = uniqueUUIDs(mediaIDs)
	addTagIDs = uniqueUUIDs(addTagIDs)
	removeTagIDs = uniqueUUIDs(removeTagIDs)
	if len(mediaIDs) == 0 || (len(addTagIDs) == 0 && len(removeTagIDs) == 0) {
		return 0, nil
	}

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	if err := ensureMediaExist(ctx, tx, mediaIDs); err != nil {
		return 0, err
	}
	if err := ensureTagsExist(ctx, tx, addTagIDs); err != nil {
		return 0, err
	}

	var affected int64
	if len(removeTagIDs) > 0 {
		tag, err := tx.Exec(ctx, `
			DELETE FROM gallery.media_tag_links
			WHERE media_id = ANY($1) AND tag_id = ANY($2)`, mediaIDs, removeTagIDs)
		if err != nil {
			return 0, fmt.Errorf("移除标签关联失败: %w", err)
		}
		affected += tag.RowsAffected()
	}
	if len(addTagIDs) > 0 {
		tag, err := tx.Exec(ctx, `
			INSERT INTO gallery.media_tag_links (media_id, tag_id)
			SELECT m.id, t.id FROM unnest($1::uuid[]) AS m(id) CROSS JOIN unnest($2::uuid[]) AS t(id)
			ON CONFLICT DO NOTHING`, mediaIDs, addTagIDs)
		if err != nil {
			return 0, fmt.Errorf("添加标签关联失败: %w", err)
		}
		affected += tag.RowsAffected()
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("提交事务失败: %w", err)
	}
	return affected, nil
}

// ensureMediaExist 校验媒体 ID 全部存在
func ensureMediaExist(ctx context.Context, tx pgx.Tx, ids []uuid.UUID) error {
	if len(ids) == 0 {
		return nil
	}
	var count int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(*) FROM gallery.media_assets WHERE id = ANY($1)`, ids).Scan(&count); err != nil {
		return fmt.Errorf("校验媒体失败: %w", err)
	}
	if count != len(ids) {
		return ErrMediaNotFound
	}
	return nil
}

// ensureTagsExist 校验标签 ID 全部存在
func ensureTagsExist(ctx context.Context, tx pgx.Tx, ids []uuid.UUID) error {
	if len(ids) == 0 {
		return nil
	}
	var count int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(*) FROM gallery.tags WHERE id = ANY($1)`, ids).Scan(&count); err != nil {
		return fmt.Errorf("校验标签失败: %w", err)
	}
	if count != len(ids) {
		return ErrTagNotFound
	}
	return nil
}

// uniqueUUIDs 去重（保持首次出现顺序）
func uniqueUUIDs(ids []uuid.UUID) []uuid.UUID {
	seen := make(map[uuid.UUID]bool, len(ids))
	result := make([]uuid.UUID, 0, len(ids))
	for _, id := range ids {
		if seen[id] {
			continue
		}
		seen[id] = true
		result = append(result, id)
	}
	return result
}

// ============ 媒体标注写操作 ============

// MediaPatch 媒体标注更新意图（nil/空字段表示不修改）
type MediaPatch struct {
	MediaIDs        []uuid.UUID
	IsDeleted       *bool
	Message         *string // 空串表示清空
	GroupID         *uuid.UUID
	ClearGroup      bool
	SetEditParams   *string // JSON 文本
	ClearEditParams bool
	MarkProcessed   bool // sync_count + 1
}

// expandWithGroupMembers 展开为"给定媒体 + 以它们为主文件的组成员"
func expandWithGroupMembers(ids []uuid.UUID) ([]uuid.UUID, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `
		SELECT id FROM gallery.media_assets
		WHERE id = ANY($1) OR group_id = ANY($1)`, ids)
	if err != nil {
		return nil, fmt.Errorf("展开捆绑组成员失败: %w", err)
	}
	defer rows.Close()

	expanded := []uuid.UUID{}
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("扫描媒体 ID 失败: %w", err)
		}
		expanded = append(expanded, id)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历媒体 ID 失败: %w", err)
	}
	return uniqueUUIDs(expanded), nil
}

// FetchMediaAssetsByIDs 按 ID 批量获取媒体（保持 captured_at 升序）
func FetchMediaAssetsByIDs(ids []uuid.UUID) ([]model.MediaAsset, error) {
	if len(ids) == 0 {
		return []model.MediaAsset{}, nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `
		SELECT id, created_at, updated_at, captured_at, file_path,
			thumb_path, preview_path, hash, size_bytes, mime_type,
			is_deleted, sync_count, group_id, COALESCE(message, ''), edit_params
		FROM gallery.media_assets
		WHERE id = ANY($1)
		ORDER BY captured_at ASC, id ASC`, ids)
	if err != nil {
		return nil, fmt.Errorf("查询媒体资产失败: %w", err)
	}
	defer rows.Close()
	return scanMediaAssets(rows)
}

// scanMediaAssets 扫描媒体资产结果集
func scanMediaAssets(rows pgx.Rows) ([]model.MediaAsset, error) {
	assets := []model.MediaAsset{}
	for rows.Next() {
		var asset model.MediaAsset
		if err := rows.Scan(
			&asset.ID, &asset.CreatedAt, &asset.UpdatedAt, &asset.CapturedAt,
			&asset.FilePath, &asset.ThumbPath, &asset.PreviewPath,
			&asset.Hash, &asset.SizeBytes, &asset.MimeType,
			&asset.IsDeleted, &asset.SyncCount, &asset.GroupID,
			&asset.Message, &asset.EditParams,
		); err != nil {
			return nil, fmt.Errorf("扫描媒体资产行失败: %w", err)
		}
		assets = append(assets, asset)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历媒体资产结果集失败: %w", err)
	}
	return assets, nil
}

// PatchMediaAssets 按 [MediaPatch] 批量更新媒体标注，返回更新后的行
func PatchMediaAssets(patch MediaPatch) ([]model.MediaAsset, error) {
	ids := uniqueUUIDs(patch.MediaIDs)
	if len(ids) == 0 {
		return []model.MediaAsset{}, nil
	}

	// 先校验目标媒体存在（否则后续展开组成员会掩盖"ID 不存在"的情况）
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	var existing int
	if err := db.GetPool().QueryRow(ctx,
		`SELECT COUNT(*) FROM gallery.media_assets WHERE id = ANY($1)`, ids).Scan(&existing); err != nil {
		return nil, fmt.Errorf("校验媒体失败: %w", err)
	}
	if existing != len(ids) {
		return nil, ErrMediaNotFound
	}

	sets := []string{}
	args := []interface{}{}
	argIdx := 1
	add := func(expr string, value interface{}) {
		sets = append(sets, fmt.Sprintf(expr, argIdx))
		args = append(args, value)
		argIdx++
	}

	if patch.IsDeleted != nil {
		// 软删除/恢复主文件时, 其捆绑组成员一并处理（与客户端本地缓存语义一致）
		expanded, err := expandWithGroupMembers(ids)
		if err != nil {
			return nil, err
		}
		ids = expanded
		add("is_deleted = $%d", *patch.IsDeleted)
	}
	if patch.Message != nil {
		var message *string
		if trimmed := strings.TrimSpace(*patch.Message); trimmed != "" {
			message = &trimmed
		}
		add("message = $%d", message)
	}
	if patch.GroupID != nil {
		for _, id := range ids {
			if id == *patch.GroupID {
				return nil, ErrMediaSelfGroup
			}
		}
		add("group_id = $%d", *patch.GroupID)
	} else if patch.ClearGroup {
		sets = append(sets, "group_id = NULL")
	}
	if patch.SetEditParams != nil {
		// jsonb 列需显式转换，避免驱动按 text 编码
		sets = append(sets, fmt.Sprintf("edit_params = $%d::jsonb", argIdx))
		args = append(args, *patch.SetEditParams)
		argIdx++
	} else if patch.ClearEditParams {
		sets = append(sets, "edit_params = NULL")
	}
	if patch.MarkProcessed {
		sets = append(sets, "sync_count = sync_count + 1")
	}

	if len(sets) == 0 {
		return FetchMediaAssetsByIDs(ids)
	}

	args = append(args, ids)
	query := fmt.Sprintf(`UPDATE gallery.media_assets SET %s WHERE id = ANY($%d)`,
		strings.Join(sets, ", "), argIdx)
	res, err := db.GetPool().Exec(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("更新媒体标注失败: %w", err)
	}
	if int(res.RowsAffected()) != len(ids) {
		return nil, ErrMediaNotFound
	}
	return FetchMediaAssetsByIDs(ids)
}

// buildMediaOrderClause 媒体列表排序（白名单字段，默认按拍摄时间倒序）
func buildMediaOrderClause(params model.MediaQueryParams) string {
	allowed := map[string]string{
		"captured_at": "m.captured_at",
		"sync_count":  "m.sync_count",
		"size_bytes":  "m.size_bytes",
		"file_path":   "m.file_path",
	}
	field := "m.captured_at"
	if v, ok := allowed[params.SortBy]; ok {
		field = v
	}
	order := "DESC"
	if strings.EqualFold(params.SortOrder, "asc") {
		order = "ASC"
	}
	return fmt.Sprintf("%s %s, m.id ASC", field, order)
}

// FetchMediaAssetsByQuery 按标签/类型/删除状态等条件查询媒体及其标签关联
func FetchMediaAssetsByQuery(params model.MediaQueryParams) ([]model.MediaAsset, []model.MediaTagLink, int, error) {
	conditions := []string{}
	args := []interface{}{}
	argIdx := 1

	if !params.IncludeDeleted {
		conditions = append(conditions, "m.is_deleted = false")
	}
	if params.MimeType != "" {
		if strings.Contains(params.MimeType, "/") {
			conditions = append(conditions, fmt.Sprintf("m.mime_type = $%d", argIdx))
			args = append(args, params.MimeType)
		} else {
			conditions = append(conditions, fmt.Sprintf("m.mime_type LIKE $%d", argIdx))
			args = append(args, params.MimeType+"/%")
		}
		argIdx++
	}

	if ids := parseUUIDList(params.IDs); len(ids) > 0 {
		conditions = append(conditions, fmt.Sprintf("m.id = ANY($%d)", argIdx))
		args = append(args, ids)
		argIdx++
	}

	if tagIDs := parseUUIDList(params.TagIDs); len(tagIDs) > 0 {
		if params.IncludeDescendants {
			conditions = append(conditions, fmt.Sprintf(`EXISTS (
				SELECT 1 FROM gallery.media_tag_links l
				WHERE l.media_id = m.id AND l.tag_id IN (
					WITH RECURSIVE sub AS (
						SELECT id FROM gallery.tags WHERE id = ANY($%d)
						UNION ALL
						SELECT t.id FROM gallery.tags t JOIN sub ON t.parent_id = sub.id
					) SELECT id FROM sub))`, argIdx))
		} else {
			conditions = append(conditions, fmt.Sprintf(
				`EXISTS (SELECT 1 FROM gallery.media_tag_links l WHERE l.media_id = m.id AND l.tag_id = ANY($%d))`, argIdx))
		}
		args = append(args, tagIDs)
		argIdx++
	}

	if params.Untagged {
		conditions = append(conditions,
			"NOT EXISTS (SELECT 1 FROM gallery.media_tag_links l WHERE l.media_id = m.id)")
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	var total int
	countQuery := fmt.Sprintf(`SELECT COUNT(*) FROM gallery.media_assets m WHERE %s`, where)
	if err := db.GetPool().QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, nil, 0, fmt.Errorf("统计媒体资产失败: %w", err)
	}

	listArgs := append(append([]interface{}{}, args...), params.Limit, params.Offset)
	listQuery := fmt.Sprintf(`
		SELECT m.id, m.created_at, m.updated_at, m.captured_at, m.file_path,
			m.thumb_path, m.preview_path, m.hash, m.size_bytes, m.mime_type,
			m.is_deleted, m.sync_count, m.group_id, COALESCE(m.message, ''), m.edit_params
		FROM gallery.media_assets m
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d`, where, buildMediaOrderClause(params), argIdx, argIdx+1)

	rows, err := db.GetPool().Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, nil, 0, fmt.Errorf("查询媒体资产失败: %w", err)
	}
	defer rows.Close()

	assets, err := scanMediaAssets(rows)
	if err != nil {
		return nil, nil, 0, err
	}

	mediaIDs := make([]uuid.UUID, len(assets))
	for i, asset := range assets {
		mediaIDs[i] = asset.ID
	}
	links, err := FetchMediaTagLinks(mediaIDs)
	if err != nil {
		return nil, nil, 0, err
	}
	return assets, links, total, nil
}

// parseUUIDList 解析逗号分隔的 UUID 列表（忽略非法项）
func parseUUIDList(raw string) []uuid.UUID {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	result := []uuid.UUID{}
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		if id, err := uuid.Parse(part); err == nil {
			result = append(result, id)
		}
	}
	return result
}

// BeginTx 开始一个新事务，供外部使用
func BeginTx(ctx context.Context) (pgx.Tx, error) {
	return db.GetPool().Begin(ctx)
}

// GetPool 获取数据库连接池
func GetPool() *pgxpool.Pool {
	return db.GetPool()
}
