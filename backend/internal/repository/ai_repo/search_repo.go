package ai_repo

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"monarch/internal/dbutil"
	"monarch/internal/model"
	"monarch/internal/repository/gallery_repo"
	"monarch/internal/service/db"
)

// SearchFilters 结构化筛选条件（语义相关度在 Go 侧计算，不在此处）。
type SearchFilters struct {
	Keyword        string      // 命中 OCR 文本 / VLM 描述 / AI 关键词
	Filename       string      // 命中文件路径（文件名或扩展名，忽略大小写）
	FilenameOnly   bool        // 限定为末段文件名
	VLMTags        []string    // AI 标签（任一命中；只读，与人工标签分开）
	TagIDs         []uuid.UUID // 人工标签（任一命中）
	Descendants    bool        // 标签是否含子孙（由 [SearchMediaIDs] 预先展开）
	PersonIDs      []uuid.UUID // 人物分组（任一命中）
	MimeType       string
	From, To       *time.Time
	IncludeDeleted bool
	SortBy         string
	SortOrder      string
	Limit          int
	Offset         int
}

var likeEscaper = strings.NewReplacer("!", "!!", "%", "!%", "_", "!_")

func containsPattern(text string) string {
	return "%" + likeEscaper.Replace(text) + "%"
}

// BuildSearchWhere 生成 WHERE 片段与参数（供候选集查询与计数复用）。
//
// 一律写成 `m.id IN (子查询)` 而非 `EXISTS(...)`：让 SQLite 从索引侧的表
// （media_ai / media_tag_links / faces）驱动，避免对 7 万行媒体逐行回表探测。
// TagIDs 必须已包含子孙标签（见 [SearchMediaIDs]）：SQLite 无法高效地把相关
// 子查询里的递归 CTE 提前求值，展开统一在 Go 侧完成。
func BuildSearchWhere(f SearchFilters) (string, []any) {
	conditions := []string{}
	args := []any{}

	if !f.IncludeDeleted {
		conditions = append(conditions, "m.is_deleted = 0")
	}
	if keyword := strings.TrimSpace(f.Keyword); keyword != "" {
		// SQLite 的 LIKE 对 ASCII 大小写不敏感，正好覆盖关键词检索；
		// 无 trigram 索引，这里对 media_ai 做一次全表扫描（见 AGENTS_DB.md 的性能说明）。
		pattern := containsPattern(keyword)
		args = append(args, pattern, pattern, pattern)
		conditions = append(conditions, `m.id IN (
			SELECT a.media_id FROM media_ai a WHERE a.ocr_text LIKE ? ESCAPE '!' OR a.caption LIKE ? ESCAPE '!'
			UNION
			SELECT t.media_id FROM media_ai_tags t WHERE t.tag LIKE ? ESCAPE '!'
		)`)
	}
	if len(f.VLMTags) > 0 {
		conditions = append(conditions, fmt.Sprintf(
			`m.id IN (SELECT t.media_id FROM media_ai_tags t WHERE t.tag IN (%s))`,
			placeholders(len(f.VLMTags))))
		for _, tag := range f.VLMTags {
			args = append(args, tag)
		}
	}
	if filename := strings.TrimSpace(f.Filename); filename != "" {
		pattern := containsPattern(filename)
		conditions = append(conditions, "m.file_path LIKE ? ESCAPE '!'")
		args = append(args, pattern)
		if f.FilenameOnly {
			conditions = append(conditions, "media_basename(m.file_path) LIKE ? ESCAPE '!'")
			args = append(args, pattern)
		}
	}
	if len(f.TagIDs) > 0 {
		conditions = append(conditions, fmt.Sprintf(
			`m.id IN (SELECT l.media_id FROM media_tag_links l WHERE l.tag_id IN (%s))`,
			placeholders(len(f.TagIDs))))
		for _, id := range f.TagIDs {
			args = append(args, id)
		}
	}
	if len(f.PersonIDs) > 0 {
		conditions = append(conditions, fmt.Sprintf(
			`m.id IN (SELECT fa.media_id FROM faces fa WHERE fa.person_id IN (%s))`,
			placeholders(len(f.PersonIDs))))
		for _, id := range f.PersonIDs {
			args = append(args, id)
		}
	}
	if f.MimeType != "" {
		if strings.Contains(f.MimeType, "/") {
			args = append(args, f.MimeType)
			conditions = append(conditions, "m.mime_type = ?")
		} else {
			args = append(args, f.MimeType+"/%")
			conditions = append(conditions, "m.mime_type LIKE ?")
		}
	}
	if f.From != nil {
		args = append(args, dbutil.TS(*f.From))
		conditions = append(conditions, "m.captured_at >= ?")
	}
	if f.To != nil {
		args = append(args, dbutil.TS(*f.To))
		conditions = append(conditions, "m.captured_at <= ?")
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}
	return where, args
}

func searchWhere(f SearchFilters) (string, []any, error) {
	if f.Descendants && len(f.TagIDs) > 0 {
		expanded, err := gallery_repo.ExpandTagIDs(f.TagIDs)
		if err != nil {
			return "", nil, err
		}
		f.TagIDs = expanded
	}
	where, args := BuildSearchWhere(f)
	return where, args, nil
}

func searchOrder(f SearchFilters) (field, direction string) {
	field = "m.captured_at"
	switch f.SortBy {
	case "size_bytes":
		field = "m.size_bytes"
	case "file_path":
		field = "m.file_path"
	}
	direction = "DESC"
	if strings.EqualFold(f.SortOrder, "asc") {
		direction = "ASC"
	}
	return field, direction
}

// SearchMediaIDs 返回满足条件的媒体 ID 及总数。不分页且未指定排序时返回无序 ID。
func SearchMediaIDs(ctx context.Context, f SearchFilters) ([]uuid.UUID, int, error) {
	where, args, err := searchWhere(f)
	if err != nil {
		return nil, 0, err
	}
	unpaged := f.Limit < 0 && f.Offset == 0
	var total int
	if !unpaged {
		if err := db.Read().QueryRowContext(ctx,
			fmt.Sprintf(`SELECT COUNT(*) FROM media_assets m WHERE %s`, where),
			args...).Scan(&total); err != nil {
			return nil, 0, fmt.Errorf("统计搜索结果失败: %w", err)
		}
	}

	order := ""
	if !unpaged || f.SortBy != "" {
		field, direction := searchOrder(f)
		order = fmt.Sprintf("ORDER BY %s %s, m.id ASC", field, direction)
	}
	query := fmt.Sprintf(`
		SELECT m.id FROM media_assets m
		WHERE %s %s LIMIT ? OFFSET ?`, where, order)

	rows, err := db.Read().QueryContext(ctx, query, append(args, f.Limit, f.Offset)...)
	if err != nil {
		return nil, 0, fmt.Errorf("查询搜索结果失败: %w", err)
	}
	defer rows.Close()

	ids := []uuid.UUID{}
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, 0, err
		}
		ids = append(ids, id)
	}
	if unpaged {
		total = len(ids)
	}
	return ids, total, rows.Err()
}

type TextSearchPage struct {
	IDs     []uuid.UUID
	Sources map[uuid.UUID][]string
	Total   int
}

// SearchText 在同一份命中集合上计数、分页和标记来源。
func SearchText(ctx context.Context, f SearchFilters) (TextSearchPage, error) {
	keyword := strings.TrimSpace(f.Keyword)
	f.Keyword = ""
	where, args, err := searchWhere(f)
	if err != nil {
		return TextSearchPage{}, err
	}
	field, direction := searchOrder(f)
	var matches string
	if keyword == "" {
		matches = fmt.Sprintf(`
			SELECT m.id, %s AS sort_value, 0 AS ocr, 0 AS caption, 0 AS tag
			FROM media_assets m WHERE %s`, field, where)
	} else {
		pattern := containsPattern(keyword)
		args = append([]any{pattern, pattern, pattern}, args...)
		matches = fmt.Sprintf(`
			WITH sources AS (
				SELECT media_id, ocr_text LIKE ? ESCAPE '!' AS ocr_hit,
				       caption LIKE ? ESCAPE '!' AS caption_hit, 0 AS tag_hit
				FROM media_ai WHERE ocr_hit OR caption_hit
				UNION ALL
				SELECT media_id, 0, 0, 1 FROM media_ai_tags WHERE tag LIKE ? ESCAPE '!'
			)
			SELECT m.id, %s AS sort_value, max(coalesce(s.ocr_hit, 0)) AS ocr,
			       max(coalesce(s.caption_hit, 0)) AS caption, max(s.tag_hit) AS tag
			FROM sources s CROSS JOIN media_assets m ON m.id = s.media_id
			WHERE %s GROUP BY m.id`, field, where)
	}
	query := fmt.Sprintf(`
		WITH matches AS MATERIALIZED (%s)
		SELECT t.total, p.id, coalesce(p.ocr, 0), coalesce(p.caption, 0), coalesce(p.tag, 0)
		FROM (SELECT count(*) AS total FROM matches) t
		LEFT JOIN (SELECT * FROM matches ORDER BY sort_value %[2]s, id LIMIT ? OFFSET ?) p ON true
		ORDER BY p.sort_value %[2]s, p.id`, matches, direction)
	rows, err := db.Read().QueryContext(ctx, query, append(args, f.Limit, f.Offset)...)
	if err != nil {
		return TextSearchPage{}, fmt.Errorf("查询文本命中失败: %w", err)
	}
	defer rows.Close()

	page := TextSearchPage{}
	if keyword != "" {
		page.Sources = make(map[uuid.UUID][]string)
	}
	for rows.Next() {
		var id uuid.NullUUID
		var ocr, caption, tag bool
		if err := rows.Scan(&page.Total, &id, &ocr, &caption, &tag); err != nil {
			return TextSearchPage{}, err
		}
		if !id.Valid {
			continue
		}
		page.IDs = append(page.IDs, id.UUID)
		var sources []string
		if ocr {
			sources = append(sources, "ocr")
		}
		if caption {
			sources = append(sources, "caption")
		}
		if tag {
			sources = append(sources, "vlm_tag")
		}
		if len(sources) > 0 {
			page.Sources[id.UUID] = sources
		}
	}
	return page, rows.Err()
}

type RelatedMediaEvidence struct {
	EmbeddingRow
	Bundled    bool
	OtherGroup bool
	Caption    string
}

// RelatedMediaEvidenceFor 只读取本组和拍摄时间附近的有向量媒体。
func RelatedMediaEvidenceFor(ctx context.Context, asset model.MediaAsset, modelName string, window time.Duration) ([]RelatedMediaEvidence, error) {
	lead := asset.ID
	if asset.GroupID != nil {
		lead = *asset.GroupID
	}
	captured := asset.CapturedAt.Time()
	// 组员按 group_id 查找，避免 ORDER BY id 让 SQLite 扫描整个图库。
	rows, err := db.Read().QueryContext(ctx, `
		WITH bundled AS (
			SELECT id FROM media_assets INDEXED BY idx_media_assets_group_id
			WHERE group_id = ? AND id <> ? AND is_deleted = 0
			UNION
			SELECT id FROM media_assets WHERE id = ? AND id <> ? AND is_deleted = 0
			ORDER BY id LIMIT 24
		), nearby AS (
			SELECT m.id FROM media_assets m
			WHERE ? <> '' AND m.is_deleted = 0 AND m.id <> ? AND m.id <> ? AND m.group_id IS NOT ?
			  AND m.captured_at BETWEEN ? AND ?
			  AND EXISTS (SELECT 1 FROM embeddings e WHERE e.media_id = m.id AND e.kind = 'image' AND e.model = ?)
			ORDER BY m.captured_at DESC LIMIT 48
		), candidates AS (
			SELECT id, 1 AS bundled FROM bundled
			UNION ALL SELECT id, 0 FROM nearby
		)
		SELECT c.id, c.bundled, m.group_id IS NOT NULL OR EXISTS (
		          SELECT 1 FROM media_assets member WHERE member.group_id = m.id
		       ), COALESCE(substr(a.caption, 1, 240), ''),
		       COALESCE(e.dim, 0), COALESCE(e.scale, 0), e.vec
		FROM candidates c
		JOIN media_assets m ON m.id = c.id
		LEFT JOIN media_ai a ON a.media_id = c.id
		LEFT JOIN embeddings e ON c.bundled = 0 AND e.media_id = c.id AND e.kind = 'image' AND e.model = ?`,
		lead, asset.ID, lead, asset.ID, modelName, asset.ID, lead, lead,
		dbutil.TS(captured.Add(-window)), dbutil.TS(captured.Add(window)), modelName, modelName)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var matches []RelatedMediaEvidence
	for rows.Next() {
		var row RelatedMediaEvidence
		if err := rows.Scan(&row.MediaID, &row.Bundled, &row.OtherGroup, &row.Caption, &row.Dim, &row.Scale, &row.Vec); err != nil {
			return nil, err
		}
		matches = append(matches, row)
	}
	return matches, rows.Err()
}
