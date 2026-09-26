package gallery_repo

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// mediaAssetColumnList 媒体资产的完整列清单（顺序与 [scanMediaAssets] 一一对应）。
// message 允许为 NULL，读取时归一化为空串。
var mediaAssetColumnList = []string{
	"id", "created_at", "updated_at", "captured_at", "file_path",
	"thumb_path", "preview_path", "hash", "size_bytes", "mime_type",
	"is_deleted", "sync_count", "group_id", "COALESCE(message, '')", "edit_params",
}

// mediaAssetColumns 生成列清单；alias 非空时逐列加表别名前缀。
func mediaAssetColumns(alias string) string {
	if alias == "" {
		return strings.Join(mediaAssetColumnList, ", ")
	}
	parts := make([]string, len(mediaAssetColumnList))
	for i, col := range mediaAssetColumnList {
		if strings.Contains(col, "message") {
			parts[i] = strings.Replace(col, "message", alias+".message", 1)
			continue
		}
		parts[i] = alias + "." + col
	}
	return strings.Join(parts, ", ")
}

// mediaSortFields 允许的排序字段白名单。
var mediaSortFields = map[string]bool{
	"captured_at": true,
	"sync_count":  true,
	"size_bytes":  true,
	"file_path":   true,
}

// IsValidSortField 报告排序字段是否受支持（handler 用于参数校验）。
func IsValidSortField(field string) bool {
	return mediaSortFields[field]
}

// scanMediaAssets 扫描媒体资产结果集（列顺序必须与 [mediaAssetColumnList] 一致）。
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

// setBuilder 累积 UPDATE 的 SET 片段与参数，避免手工维护占位符下标。
type setBuilder struct {
	sets []string
	args []any
}

// add 追加 `expr`（其中 %d 表示占位符序号）。
func (b *setBuilder) add(expr string, value any) {
	b.sets = append(b.sets, fmt.Sprintf(expr, len(b.args)+1))
	b.args = append(b.args, value)
}

// raw 追加不带参数的赋值（如 `group_id = NULL`）。
func (b *setBuilder) raw(expr string) {
	b.sets = append(b.sets, expr)
}

// isEmpty 报告是否没有任何待更新字段。
func (b *setBuilder) isEmpty() bool {
	return len(b.sets) == 0
}

// build 生成完整 UPDATE 语句与参数（where 中的 %d 为主查询参数之后的占位符序号）。
func (b *setBuilder) build(table, where string, whereArgs ...any) (string, []any) {
	query := fmt.Sprintf("UPDATE %s SET %s WHERE %s",
		table, strings.Join(b.sets, ", "), fmt.Sprintf(where, len(b.args)+1))
	return query, append(b.args, whereArgs...)
}

// rowQuerier 抽象 pgx.Tx 与 *pgxpool.Pool，使校验逻辑在事务内外均可复用。
type rowQuerier interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// mimeCondition 生成 MIME 过滤条件：含 "/" 视为精确匹配，否则按大类前缀匹配。
func mimeCondition(column, mimeType string, argIdx int) (string, any) {
	if strings.Contains(mimeType, "/") {
		return fmt.Sprintf("%s = $%d", column, argIdx), mimeType
	}
	return fmt.Sprintf("%s LIKE $%d", column, argIdx), mimeType + "/%"
}

// ============ 媒体资产查询 ============

// buildBatchWhereClause 构建 /batch 的 WHERE 条件。
func buildBatchWhereClause(params model.BatchQueryParams) (string, []any) {
	conditions := []string{"is_deleted = false"}
	args := []any{}

	if params.MimeType != "" {
		cond, value := mimeCondition("mime_type", params.MimeType, len(args)+1)
		conditions = append(conditions, cond)
		args = append(args, value)
	}

	if params.Year > 0 {
		switch {
		case params.Month > 0 && params.Day > 0:
			conditions = append(conditions, fmt.Sprintf("DATE(captured_at) = $%d", len(args)+1))
			args = append(args, fmt.Sprintf("%04d-%02d-%02d", params.Year, params.Month, params.Day))
		case params.Month > 0:
			conditions = append(conditions,
				fmt.Sprintf("EXTRACT(YEAR FROM captured_at) = $%d AND EXTRACT(MONTH FROM captured_at) = $%d",
					len(args)+1, len(args)+2))
			args = append(args, params.Year, params.Month)
		default:
			conditions = append(conditions, fmt.Sprintf("EXTRACT(YEAR FROM captured_at) = $%d", len(args)+1))
			args = append(args, params.Year)
		}
	}

	return strings.Join(conditions, " AND "), args
}

// buildBatchOrderClause 构建 /batch 的 ORDER BY 子句。
//
// 排序方向同时作用于主排序与并列时的兜底排序；末尾固定追加 id，使偏移分页在
// 排序键取值相同时也有稳定顺序（否则翻页可能重复或漏掉记录）。
func buildBatchOrderClause(params model.BatchQueryParams) string {
	primary := "sync_count"
	if mediaSortFields[params.SortBy] {
		primary = params.SortBy
	}
	order := "ASC"
	if upper := strings.ToUpper(params.SortOrder); upper == "DESC" || upper == "ASC" {
		order = upper
	}

	keys := []string{fmt.Sprintf("%s %s", primary, order)}
	if primary != "captured_at" {
		keys = append(keys, fmt.Sprintf("captured_at %s", order))
	}
	if mediaSortFields[params.SecondarySort] {
		for _, key := range keys {
			if strings.HasPrefix(key, params.SecondarySort+" ") {
				return strings.Join(append(keys, "id ASC"), ", ")
			}
		}
		keys = append(keys, fmt.Sprintf("%s %s", params.SecondarySort, order))
	}
	return strings.Join(append(keys, "id ASC"), ", ")
}

// FetchMediaAssetsWithParams 根据查询参数获取媒体资产（支持筛选和排序）
func FetchMediaAssetsWithParams(params model.BatchQueryParams) ([]model.MediaAsset, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	whereClause, args := buildBatchWhereClause(params)
	query := fmt.Sprintf(`
		SELECT %s
		FROM gallery.media_assets
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, mediaAssetColumns(""), whereClause, buildBatchOrderClause(params), len(args)+1, len(args)+2)

	rows, err := db.GetPool().Query(ctx, query, append(args, params.Limit, params.Offset)...)
	if err != nil {
		return nil, fmt.Errorf("查询媒体资产失败: %w", err)
	}
	defer rows.Close()
	return scanMediaAssets(rows)
}

// FetchGalleryOverview 获取画廊总览统计数据
func FetchGalleryOverview() (*model.GalleryOverview, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	overview := &model.GalleryOverview{}
	pool := db.GetPool()

	// 类型分布 / 总大小 / sync_count 统计 / 年份极值：单次扫描得出
	err := pool.QueryRow(ctx, `
		SELECT
			COUNT(*),
			COALESCE(SUM(CASE WHEN mime_type LIKE 'image/%' THEN 1 ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN mime_type LIKE 'video/%' THEN 1 ELSE 0 END), 0),
			COALESCE(SUM(size_bytes), 0),
			COALESCE(MIN(sync_count), 0),
			COALESCE(MAX(sync_count), 0),
			COALESCE(AVG(sync_count), 0),
			COALESCE(EXTRACT(YEAR FROM MIN(captured_at))::int, 0),
			COALESCE(EXTRACT(YEAR FROM MAX(captured_at))::int, 0)
		FROM gallery.media_assets
		WHERE is_deleted = false
	`).Scan(
		&overview.TotalMedia, &overview.ImageCount, &overview.VideoCount, &overview.TotalSize,
		&overview.SyncStats.MinSyncCount, &overview.SyncStats.MaxSyncCount, &overview.SyncStats.AvgSyncCount,
		&overview.MinYear, &overview.MaxYear,
	)
	if err != nil {
		return nil, fmt.Errorf("查询媒体统计失败: %w", err)
	}

	if overview.TotalMedia > 0 {
		overview.ImageRatio = float64(overview.ImageCount) / float64(overview.TotalMedia)
		overview.VideoRatio = float64(overview.VideoCount) / float64(overview.TotalMedia)
	}

	if err := pool.QueryRow(ctx, `
		SELECT
			(SELECT COUNT(*) FROM gallery.tags),
			(SELECT COUNT(*) FROM gallery.tags WHERE parent_id IS NULL),
			(SELECT COUNT(*) FROM gallery.media_tag_links)
	`).Scan(&overview.TotalTags, &overview.RootTags, &overview.TotalLinks); err != nil {
		return nil, fmt.Errorf("查询标签统计失败: %w", err)
	}

	rows, err := pool.Query(ctx, `
		SELECT EXTRACT(YEAR FROM captured_at)::int AS year, COUNT(*)
		FROM gallery.media_assets
		WHERE is_deleted = false AND captured_at IS NOT NULL
		GROUP BY year
		ORDER BY year DESC
	`)
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
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历年份统计失败: %w", err)
	}

	return overview, nil
}

// FetchMediaAssetByID 根据 ID 获取单个媒体资产（不存在时返回 nil, nil）
func FetchMediaAssetByID(id uuid.UUID) (*model.MediaAsset, error) {
	assets, err := FetchMediaAssetsByIDs([]uuid.UUID{id})
	if err != nil || len(assets) == 0 {
		return nil, err
	}
	return &assets[0], nil
}

// FetchMediaAssetsByIDs 按 ID 批量获取媒体（保持 captured_at 升序）
func FetchMediaAssetsByIDs(ids []uuid.UUID) ([]model.MediaAsset, error) {
	if len(ids) == 0 {
		return []model.MediaAsset{}, nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, fmt.Sprintf(
		`SELECT %s FROM gallery.media_assets WHERE id = ANY($1) ORDER BY captured_at ASC, id ASC`,
		mediaAssetColumns("")), ids)
	if err != nil {
		return nil, fmt.Errorf("查询媒体资产失败: %w", err)
	}
	defer rows.Close()
	return scanMediaAssets(rows)
}

// buildMediaOrderClause 媒体列表排序（白名单字段，默认按拍摄时间倒序）
func buildMediaOrderClause(params model.MediaQueryParams) string {
	field := "m.captured_at"
	if mediaSortFields[params.SortBy] {
		field = "m." + params.SortBy
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
	args := []any{}

	if params.OnlyDeleted {
		conditions = append(conditions, "m.is_deleted = true")
	} else if !params.IncludeDeleted {
		conditions = append(conditions, "m.is_deleted = false")
	}
	if params.MimeType != "" {
		cond, value := mimeCondition("m.mime_type", params.MimeType, len(args)+1)
		conditions = append(conditions, cond)
		args = append(args, value)
	}
	if ids := parseUUIDList(params.IDs); len(ids) > 0 {
		conditions = append(conditions, fmt.Sprintf("m.id = ANY($%d)", len(args)+1))
		args = append(args, ids)
	}
	if tagIDs := parseUUIDList(params.TagIDs); len(tagIDs) > 0 {
		if params.IncludeDescendants {
			conditions = append(conditions, fmt.Sprintf(
				`EXISTS (SELECT 1 FROM gallery.media_tag_links l
					WHERE l.media_id = m.id AND l.tag_id IN (
						WITH RECURSIVE sub AS (
							SELECT id FROM gallery.tags WHERE id = ANY($%d)
							UNION ALL
							SELECT t.id FROM gallery.tags t JOIN sub ON t.parent_id = sub.id
						) SELECT id FROM sub))`, len(args)+1))
		} else {
			conditions = append(conditions, fmt.Sprintf(
				`EXISTS (SELECT 1 FROM gallery.media_tag_links l WHERE l.media_id = m.id AND l.tag_id = ANY($%d))`,
				len(args)+1))
		}
		args = append(args, tagIDs)
	}
	if params.Untagged {
		conditions = append(conditions,
			"NOT EXISTS (SELECT 1 FROM gallery.media_tag_links l WHERE l.media_id = m.id)")
	}
	// AI 标签筛选为可选路径：不传 vlm_tags 时完全不触及 ai schema，
	// 未初始化 AI 层的部署不会因此查询报错。
	if tags := parseTextList(params.VLMTags); len(tags) > 0 {
		conditions = append(conditions, fmt.Sprintf(
			`EXISTS (SELECT 1 FROM ai.media_ai a WHERE a.media_id = m.id AND a.vlm_tags && $%d)`,
			len(args)+1))
		args = append(args, tags)
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	var total int
	if err := db.GetPool().QueryRow(ctx,
		fmt.Sprintf(`SELECT COUNT(*) FROM gallery.media_assets m WHERE %s`, where), args...).Scan(&total); err != nil {
		return nil, nil, 0, fmt.Errorf("统计媒体资产失败: %w", err)
	}

	listQuery := fmt.Sprintf(`
		SELECT %s
		FROM gallery.media_assets m
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d`,
		mediaAssetColumns("m"), where, buildMediaOrderClause(params), len(args)+1, len(args)+2)

	rows, err := db.GetPool().Query(ctx, listQuery, append(args, params.Limit, params.Offset)...)
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

// parseTextList 解析逗号分隔的文本列表（去空白、去重、忽略空项）
func parseTextList(raw string) []string {
	result := []string{}
	seen := map[string]bool{}
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" || seen[part] {
			continue
		}
		seen[part] = true
		result = append(result, part)
	}
	return result
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

// ============ 标签查询 ============

// FetchAllTags 获取所有标签（含收藏标记与直接关联的媒体数）
func FetchAllTags() ([]model.Tag, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `
		SELECT t.id, t.created_at, t.updated_at, t.name, t.parent_id, t.full_path, t.is_favorite,
			COUNT(m.id) AS media_count
		FROM gallery.tags t
		LEFT JOIN gallery.media_tag_links l ON l.tag_id = t.id
		LEFT JOIN gallery.media_assets m ON m.id = l.media_id AND m.is_deleted = false
		GROUP BY t.id
		ORDER BY t.full_path ASC
	`)
	if err != nil {
		return nil, fmt.Errorf("查询标签失败: %w", err)
	}
	defer rows.Close()

	tags := []model.Tag{}
	for rows.Next() {
		var tag model.Tag
		if err := rows.Scan(
			&tag.ID, &tag.CreatedAt, &tag.UpdatedAt, &tag.Name,
			&tag.ParentID, &tag.FullPath, &tag.IsFavorite, &tag.MediaCount,
		); err != nil {
			return nil, fmt.Errorf("扫描标签行失败: %w", err)
		}
		tags = append(tags, tag)
	}
	if err := rows.Err(); err != nil {
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

	rows, err := db.GetPool().Query(ctx,
		`SELECT media_id, tag_id FROM gallery.media_tag_links WHERE media_id = ANY($1)`, mediaIDs)
	if err != nil {
		return nil, fmt.Errorf("查询媒体标签关联失败: %w", err)
	}
	defer rows.Close()

	links := []model.MediaTagLink{}
	for rows.Next() {
		var link model.MediaTagLink
		if err := rows.Scan(&link.MediaID, &link.TagID); err != nil {
			return nil, fmt.Errorf("扫描标签关联行失败: %w", err)
		}
		links = append(links, link)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历标签关联结果集失败: %w", err)
	}
	return links, nil
}

// FetchTagByID 获取单个标签（不存在时返回 nil, nil）
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
	return descendantIDs(ctx, db.GetPool(), id)
}

// descendantIDs 递归查询子孙标签 ID（parentID 起点由参数决定）。
func descendantIDs(ctx context.Context, q interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
}, rootID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := q.Query(ctx, `
		WITH RECURSIVE sub AS (
			SELECT id FROM gallery.tags WHERE parent_id = $1
			UNION ALL
			SELECT t.id FROM gallery.tags t JOIN sub ON t.parent_id = sub.id
		) SELECT id FROM sub`, rootID)
	if err != nil {
		return nil, fmt.Errorf("查询子孙标签失败: %w", err)
	}
	defer rows.Close()

	ids := []uuid.UUID{}
	for rows.Next() {
		var childID uuid.UUID
		if err := rows.Scan(&childID); err != nil {
			return nil, fmt.Errorf("扫描子孙标签失败: %w", err)
		}
		ids = append(ids, childID)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历子孙标签失败: %w", err)
	}
	return ids, nil
}

// ============ 标签写操作 ============

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

	var b setBuilder
	effectiveName := currentName
	if patch.Name != nil {
		effectiveName = strings.TrimSpace(*patch.Name)
		if effectiveName == "" {
			return nil, ErrTagEmptyName
		}
		b.add("name = $%d", effectiveName)
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
		b.add("parent_id = $%d", effectiveParent)
	}

	// (name, parent_id) 唯一性：数据库 UNIQUE 约束不覆盖 parent_id IS NULL，这里显式校验
	if patch.Name != nil || patch.MoveToRoot || patch.ParentID != nil {
		if err := ensureSiblingNameFree(ctx, tx, effectiveName, effectiveParent, &id); err != nil {
			return nil, err
		}
	}

	if patch.IsFavorite != nil {
		b.add("is_favorite = $%d", *patch.IsFavorite)
	}

	if !b.isEmpty() {
		query, args := b.build("gallery.tags", "id = $%d", id)
		if _, err := tx.Exec(ctx, query, args...); err != nil {
			return nil, classifyTagWriteError(err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("提交事务失败: %w", err)
	}
	return FetchTagByID(id)
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
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM gallery.tags WHERE id = $1)`, id).Scan(&exists); err != nil {
		return nil, fmt.Errorf("查询标签失败: %w", err)
	}
	if !exists {
		return nil, ErrTagNotFound
	}

	descendants, err := descendantIDs(ctx, tx, id)
	if err != nil {
		return nil, err
	}

	// 子标签与标签关联由外键 ON DELETE CASCADE 清理
	if _, err := tx.Exec(ctx, `DELETE FROM gallery.tags WHERE id = $1`, id); err != nil {
		return nil, fmt.Errorf("删除标签失败: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("提交事务失败: %w", err)
	}

	return append(descendants, id), nil
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

// ensureParentExist 校验父标签存在
func ensureParentExist(ctx context.Context, q rowQuerier, parentID *uuid.UUID) error {
	if parentID == nil {
		return nil
	}
	var exists bool
	if err := q.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM gallery.tags WHERE id = $1)`, *parentID).Scan(&exists); err != nil {
		return fmt.Errorf("校验父标签失败: %w", err)
	}
	if !exists {
		return ErrTagParentNotFound
	}
	return nil
}

// ensureSiblingNameFree 校验同级同名（NULL 父级也参与比较）
func ensureSiblingNameFree(ctx context.Context, q rowQuerier, name string, parentID, excludeID *uuid.UUID) error {
	var exists bool
	err := q.QueryRow(ctx, `
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
func ensureMediaExist(ctx context.Context, q rowQuerier, ids []uuid.UUID) error {
	return ensureAllExist(ctx, q, "gallery.media_assets", ids, ErrMediaNotFound, "校验媒体失败")
}

// ensureTagsExist 校验标签 ID 全部存在
func ensureTagsExist(ctx context.Context, q rowQuerier, ids []uuid.UUID) error {
	return ensureAllExist(ctx, q, "gallery.tags", ids, ErrTagNotFound, "校验标签失败")
}

// ensureAllExist 校验 ids 在 table 中全部存在（空集合视为通过）；table 仅接受本包字面量。
func ensureAllExist(ctx context.Context, q rowQuerier, table string, ids []uuid.UUID, notFound error, errPrefix string) error {
	if len(ids) == 0 {
		return nil
	}
	var count int
	if err := q.QueryRow(ctx,
		"SELECT COUNT(*) FROM "+table+" WHERE id = ANY($1)", ids).Scan(&count); err != nil {
		return fmt.Errorf("%s: %w", errPrefix, err)
	}
	if count != len(ids) {
		return notFound
	}
	return nil
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

// PatchMediaAssets 按 [MediaPatch] 批量更新媒体标注，返回更新后的行
func PatchMediaAssets(patch MediaPatch) ([]model.MediaAsset, error) {
	ids := uniqueUUIDs(patch.MediaIDs)
	if len(ids) == 0 {
		return []model.MediaAsset{}, nil
	}

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	// 先校验目标媒体存在：后续展开组成员会掩盖"ID 不存在"的情况
	if err := ensureMediaExist(ctx, db.GetPool(), ids); err != nil {
		return nil, err
	}

	var b setBuilder
	if patch.IsDeleted != nil {
		// 软删除/恢复主文件时, 其捆绑组成员一并处理（与客户端本地缓存语义一致）
		expanded, err := expandWithGroupMembers(ids)
		if err != nil {
			return nil, err
		}
		ids = expanded
		b.add("is_deleted = $%d", *patch.IsDeleted)
	}
	if patch.Message != nil {
		var message *string
		if trimmed := strings.TrimSpace(*patch.Message); trimmed != "" {
			message = &trimmed
		}
		b.add("message = $%d", message)
	}
	if patch.GroupID != nil {
		for _, id := range ids {
			if id == *patch.GroupID {
				return nil, ErrMediaSelfGroup
			}
		}
		b.add("group_id = $%d", *patch.GroupID)
	} else if patch.ClearGroup {
		b.raw("group_id = NULL")
	}
	if patch.SetEditParams != nil {
		// jsonb 列需显式转换，避免驱动按 text 编码
		b.add("edit_params = $%d::jsonb", *patch.SetEditParams)
	} else if patch.ClearEditParams {
		b.raw("edit_params = NULL")
	}
	if patch.MarkProcessed {
		b.raw("sync_count = sync_count + 1")
	}

	if b.isEmpty() {
		return FetchMediaAssetsByIDs(ids)
	}

	query, args := b.build("gallery.media_assets", "id = ANY($%d)", ids)
	res, err := db.GetPool().Exec(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("更新媒体标注失败: %w", err)
	}
	if int(res.RowsAffected()) != len(ids) {
		return nil, ErrMediaNotFound
	}
	return FetchMediaAssetsByIDs(ids)
}
