package ai_repo

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// EmbeddingWrite 一条待写入的图像向量（int8 量化）。
type EmbeddingWrite struct {
	MediaID uuid.UUID
	Kind    string
	Model   string
	Dim     int
	Scale   float32
	Vec     []byte
}

// FaceWrite 一张待写入的人脸。
type FaceWrite struct {
	ID        uuid.UUID
	MediaID   uuid.UUID
	Box       []float32 // 归一化 x1,y1,x2,y2
	DetScore  float64
	Quality   float64
	Embedding []byte // 512 × float32
}

// ---------- 写入 ----------

// SavePHash 写入感知哈希（-1 表示无法解码，同样落库以避免重复尝试）。
func SavePHash(mediaID uuid.UUID, hash int64) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.GetPool().Exec(ctx, `
		INSERT INTO ai.media_ai (media_id, phash) VALUES ($1, $2)
		ON CONFLICT (media_id) DO UPDATE SET phash = EXCLUDED.phash`, mediaID, hash)
	if err != nil {
		return fmt.Errorf("写入感知哈希失败: %w", err)
	}
	return nil
}

// SaveOCR 写入 OCR 文本（空文本同样落库，表示"已识别但无文字"）。
func SaveOCR(mediaID uuid.UUID, text string) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.GetPool().Exec(ctx, `
		INSERT INTO ai.media_ai (media_id, ocr_text) VALUES ($1, $2)
		ON CONFLICT (media_id) DO UPDATE SET ocr_text = EXCLUDED.ocr_text`, mediaID, text)
	if err != nil {
		return fmt.Errorf("写入 OCR 结果失败: %w", err)
	}
	return nil
}

// SaveVLM 写入 VLM 描述与关键词。
func SaveVLM(mediaID uuid.UUID, caption string, tags []string) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if tags == nil {
		tags = []string{}
	}
	_, err := db.GetPool().Exec(ctx, `
		INSERT INTO ai.media_ai (media_id, caption, vlm_tags) VALUES ($1, $2, $3)
		ON CONFLICT (media_id) DO UPDATE SET caption = EXCLUDED.caption, vlm_tags = EXCLUDED.vlm_tags`,
		mediaID, caption, tags)
	if err != nil {
		return fmt.Errorf("写入 VLM 结果失败: %w", err)
	}
	return nil
}

// SaveEmbeddings 批量写入图像向量（同媒体同模型覆盖）。
func SaveEmbeddings(rows []EmbeddingWrite) error {
	if len(rows) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	batch := &pgx.Batch{}
	for _, row := range rows {
		batch.Queue(`
			INSERT INTO ai.embeddings (media_id, kind, model, dim, scale, vec)
			VALUES ($1, $2, $3, $4, $5, $6)
			ON CONFLICT (media_id, kind, model) DO UPDATE
			SET dim = EXCLUDED.dim, scale = EXCLUDED.scale, vec = EXCLUDED.vec`,
			row.MediaID, row.Kind, row.Model, row.Dim, row.Scale, row.Vec)
	}

	results := db.GetPool().SendBatch(ctx, batch)
	defer results.Close()
	for range rows {
		if _, err := results.Exec(); err != nil {
			return fmt.Errorf("写入图像向量失败: %w", err)
		}
	}
	return results.Close()
}

// ReplaceFaces 全量替换某媒体的人脸记录（重跑该能力时不留残留）。
//
// 被删除的人脸若曾作为人物封面，由数据库 ON DELETE SET NULL 自动清理。
// 人物归属不在此处决定，交由聚类阶段统一维护。
func ReplaceFaces(mediaID uuid.UUID, faces []FaceWrite) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	return withTx(ctx, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `DELETE FROM ai.faces WHERE media_id = $1`, mediaID); err != nil {
			return fmt.Errorf("清理旧人脸失败: %w", err)
		}
		for _, f := range faces {
			if _, err := tx.Exec(ctx, `
				INSERT INTO ai.faces (id, media_id, bbox, det_score, quality, embedding)
				VALUES ($1, $2, $3, $4, $5, $6)`,
				f.ID, f.MediaID, f.Box, f.DetScore, f.Quality, f.Embedding); err != nil {
				return fmt.Errorf("写入人脸失败: %w", err)
			}
		}
		return nil
	})
}

// ---------- 读取 ----------

// LoadPHashes 载入全部感知哈希（7w 条约 1MB，常驻内存便于快速分组）。
func LoadPHashes() (map[uuid.UUID]int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	rows, err := db.GetPool().Query(ctx,
		`SELECT media_id, phash FROM ai.media_ai WHERE phash IS NOT NULL`)
	if err != nil {
		return nil, fmt.Errorf("载入感知哈希失败: %w", err)
	}
	defer rows.Close()

	result := make(map[uuid.UUID]int64)
	for rows.Next() {
		var id uuid.UUID
		var hash int64
		if err := rows.Scan(&id, &hash); err != nil {
			return nil, err
		}
		result[id] = hash
	}
	return result, rows.Err()
}

// EmbeddingRow 一条图像向量。
type EmbeddingRow struct {
	MediaID uuid.UUID
	Dim     int
	Scale   float32
	Vec     []byte
}

// LoadEmbeddings 载入某模型的全部图像向量（7w × 768B ≈ 54MB）。
func LoadEmbeddings(kind, modelName string) ([]EmbeddingRow, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	rows, err := db.GetPool().Query(ctx, `
		SELECT media_id, dim, scale, vec FROM ai.embeddings WHERE kind = $1 AND model = $2`,
		kind, modelName)
	if err != nil {
		return nil, fmt.Errorf("载入图像向量失败: %w", err)
	}
	defer rows.Close()

	result := []EmbeddingRow{}
	for rows.Next() {
		var row EmbeddingRow
		if err := rows.Scan(&row.MediaID, &row.Dim, &row.Scale, &row.Vec); err != nil {
			return nil, err
		}
		result = append(result, row)
	}
	return result, rows.Err()
}

// EmbeddingCount 统计向量条数（用于判断内存索引是否需要重建）。
func EmbeddingCount(kind, modelName string) (int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	var n int
	err := db.GetPool().QueryRow(ctx,
		`SELECT COUNT(*) FROM ai.embeddings WHERE kind = $1 AND model = $2`, kind, modelName).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("统计图像向量失败: %w", err)
	}
	return n, nil
}

// GetEmbedding 取单个媒体的向量（以图搜图时若查询图已是库内媒体可直接复用）。
func GetEmbedding(mediaID uuid.UUID, kind, modelName string) (*EmbeddingRow, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	row := EmbeddingRow{MediaID: mediaID}
	err := db.GetPool().QueryRow(ctx, `
		SELECT dim, scale, vec FROM ai.embeddings
		WHERE media_id = $1 AND kind = $2 AND model = $3`, mediaID, kind, modelName).
		Scan(&row.Dim, &row.Scale, &row.Vec)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &row, nil
}

// GetMediaDetail 读取单个媒体的 AI 结果汇总。
func GetMediaDetail(mediaID uuid.UUID) (*model.AiMediaDetail, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	detail := &model.AiMediaDetail{MediaID: mediaID, VLMTags: []string{}, Faces: []model.AiFace{}}
	err := db.GetPool().QueryRow(ctx, `
		SELECT phash, ocr_text, caption, vlm_tags
		FROM ai.media_ai WHERE media_id = $1`, mediaID).
		Scan(&detail.PHash, &detail.OCRText, &detail.Caption, &detail.VLMTags)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("读取媒体 AI 结果失败: %w", err)
	}

	if err := db.GetPool().QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM ai.embeddings WHERE media_id = $1)`, mediaID).
		Scan(&detail.HasVector); err != nil {
		return nil, fmt.Errorf("读取向量状态失败: %w", err)
	}

	faces, err := ListFacesByMedia([]uuid.UUID{mediaID})
	if err != nil {
		return nil, err
	}
	if list, ok := faces[mediaID]; ok {
		detail.Faces = list
	}
	return detail, nil
}

// ListFacesByMedia 按媒体批量查询人脸。
func ListFacesByMedia(mediaIDs []uuid.UUID) (map[uuid.UUID][]model.AiFace, error) {
	if len(mediaIDs) == 0 {
		return map[uuid.UUID][]model.AiFace{}, nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `
		SELECT id, media_id, person_id, bbox, det_score, quality, created_at
		FROM ai.faces WHERE media_id = ANY($1) ORDER BY det_score DESC`, mediaIDs)
	if err != nil {
		return nil, fmt.Errorf("查询人脸失败: %w", err)
	}
	defer rows.Close()

	result := map[uuid.UUID][]model.AiFace{}
	for rows.Next() {
		face, err := scanFaceRow(rows)
		if err != nil {
			return nil, err
		}
		result[face.MediaID] = append(result[face.MediaID], face)
	}
	return result, rows.Err()
}

// scanFaceRow 读取一行人脸记录（bbox 由数据库的 float4[] 加宽为 float64）。
func scanFaceRow(rows pgx.Rows) (model.AiFace, error) {
	var face model.AiFace
	var box []float32
	if err := rows.Scan(&face.ID, &face.MediaID, &face.PersonID, &box,
		&face.DetScore, &face.Quality, &face.CreatedAt); err != nil {
		return face, err
	}
	face.Box = make([]float64, len(box))
	for i, v := range box {
		face.Box[i] = float64(v)
	}
	return face, nil
}

// FaceEmbedding 聚类所需的单张人脸特征。
type FaceEmbedding struct {
	ID       uuid.UUID
	PersonID *uuid.UUID
	Quality  float64
	Vector   []float32
}

// LoadFaceEmbeddings 载入全部人脸特征（未分配人物的可选过滤）。
func LoadFaceEmbeddings(unassignedOnly bool) ([]FaceEmbedding, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	sql := `SELECT id, person_id, quality, embedding FROM ai.faces`
	if unassignedOnly {
		sql += ` WHERE person_id IS NULL`
	}
	rows, err := db.GetPool().Query(ctx, sql)
	if err != nil {
		return nil, fmt.Errorf("载入人脸特征失败: %w", err)
	}
	defer rows.Close()

	result := []FaceEmbedding{}
	for rows.Next() {
		var item FaceEmbedding
		var raw []byte
		if err := rows.Scan(&item.ID, &item.PersonID, &item.Quality, &raw); err != nil {
			return nil, err
		}
		item.Vector = DecodeFloat32(raw)
		if len(item.Vector) == 0 {
			continue
		}
		result = append(result, item)
	}
	return result, rows.Err()
}

// ListPersons 列出人物分组（含封面媒体，供客户端直接取缩略图）。
func ListPersons() ([]model.AiPerson, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `
		SELECT p.id, p.name, p.cover_face_id, f.media_id, p.face_count, p.created_at, p.updated_at
		FROM ai.persons p
		LEFT JOIN ai.faces f ON f.id = p.cover_face_id
		ORDER BY p.face_count DESC, p.created_at ASC`)
	if err != nil {
		return nil, fmt.Errorf("查询人物分组失败: %w", err)
	}
	defer rows.Close()

	persons := []model.AiPerson{}
	for rows.Next() {
		var p model.AiPerson
		var coverFace *uuid.UUID
		var coverMedia *uuid.UUID
		if err := rows.Scan(&p.ID, &p.Name, &coverFace, &coverMedia,
			&p.FaceCount, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		if coverFace != nil {
			s := coverFace.String()
			p.CoverFaceID = &s
		}
		if coverMedia != nil {
			s := coverMedia.String()
			p.CoverMedia = &s
		}
		persons = append(persons, p)
	}
	return persons, rows.Err()
}

// ListPersonFaces 返回某人物下的人脸及其媒体（用于人物详情页）。
func ListPersonFaces(personID uuid.UUID, limit, offset int) ([]model.AiFace, int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	var total int
	if err := db.GetPool().QueryRow(ctx,
		`SELECT COUNT(*) FROM ai.faces WHERE person_id = $1`, personID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("统计人物人脸失败: %w", err)
	}

	rows, err := db.GetPool().Query(ctx, `
		SELECT id, media_id, person_id, bbox, det_score, quality, created_at
		FROM ai.faces WHERE person_id = $1
		ORDER BY quality DESC, created_at ASC LIMIT $2 OFFSET $3`, personID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("查询人物人脸失败: %w", err)
	}
	defer rows.Close()

	faces := []model.AiFace{}
	for rows.Next() {
		face, err := scanFaceRow(rows)
		if err != nil {
			return nil, 0, err
		}
		faces = append(faces, face)
	}
	return faces, total, rows.Err()
}

// ---------- 人物写操作 ----------

// CreatePerson 新建人物分组，返回其 ID。
func CreatePerson(name *string) (uuid.UUID, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	id := uuid.New()
	_, err := db.GetPool().Exec(ctx,
		`INSERT INTO ai.persons (id, name) VALUES ($1, $2)`, id, name)
	if err != nil {
		return uuid.Nil, fmt.Errorf("创建人物失败: %w", err)
	}
	return id, nil
}

// AssignFaces 把人脸分配给人（personID 为 nil 表示取消分配）。
func AssignFaces(faceIDs []uuid.UUID, personID *uuid.UUID) error {
	if len(faceIDs) == 0 {
		return nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	_, err := db.GetPool().Exec(ctx,
		`UPDATE ai.faces SET person_id = $2 WHERE id = ANY($1)`, faceIDs, personID)
	if err != nil {
		return fmt.Errorf("分配人脸失败: %w", err)
	}
	return nil
}

// RenamePerson 设置或清空人物名称。
func RenamePerson(personID uuid.UUID, name *string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	tag, err := db.GetPool().Exec(ctx,
		`UPDATE ai.persons SET name = $2 WHERE id = $1`, personID, name)
	if err != nil {
		return fmt.Errorf("重命名人物失败: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrPersonMissing
	}
	return nil
}

// MergePersons 把 srcIDs 下的人脸全部并到 dstID，并删除被合并的分组。
func MergePersons(srcIDs []uuid.UUID, dstID uuid.UUID) (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	var moved int64
	err := withTx(ctx, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx,
			`UPDATE ai.faces SET person_id = $1 WHERE person_id = ANY($2)`, dstID, srcIDs)
		if err != nil {
			return fmt.Errorf("合并人脸失败: %w", err)
		}
		moved = tag.RowsAffected()
		if _, err := tx.Exec(ctx,
			`DELETE FROM ai.persons WHERE id = ANY($1)`, srcIDs); err != nil {
			return fmt.Errorf("清理被合并分组失败: %w", err)
		}
		return refreshPersonStats(ctx, tx, []uuid.UUID{dstID})
	})
	return moved, err
}

// DeletePerson 删除分组（人脸回到未分配）。
func DeletePerson(personID uuid.UUID) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	tag, err := db.GetPool().Exec(ctx, `DELETE FROM ai.persons WHERE id = $1`, personID)
	if err != nil {
		return fmt.Errorf("删除人物失败: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrPersonMissing
	}
	return nil
}

// RefreshPersonStats 重算指定人物的人脸数与封面（增量归并后调用）。
func RefreshPersonStats(personIDs []uuid.UUID) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return refreshPersonStats(ctx, db.GetPool(), personIDs)
}

// RefreshAllPersonStats 重算全部人物的人脸数与封面（封面取质量最高的人脸）。
func RefreshAllPersonStats() error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.GetPool().Exec(ctx, `
		UPDATE ai.persons p
		SET face_count = COALESCE(c.n, 0),
		    cover_face_id = c.cover
		FROM (
			SELECT p2.id,
			       (SELECT COUNT(*) FROM ai.faces f WHERE f.person_id = p2.id) AS n,
			       (SELECT f2.id FROM ai.faces f2 WHERE f2.person_id = p2.id
			        ORDER BY f2.quality DESC, f2.det_score DESC LIMIT 1) AS cover
			FROM ai.persons p2
		) c
		WHERE p.id = c.id`)
	if err != nil {
		return fmt.Errorf("重算人物统计失败: %w", err)
	}
	return nil
}

// DropEmptyPersons 删除没有任何人脸的空分组。
func DropEmptyPersons() (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	tag, err := db.GetPool().Exec(ctx, `
		DELETE FROM ai.persons p
		WHERE NOT EXISTS (SELECT 1 FROM ai.faces f WHERE f.person_id = p.id)`)
	if err != nil {
		return 0, fmt.Errorf("清理空人物分组失败: %w", err)
	}
	return tag.RowsAffected(), nil
}

// ResetAllFaceAssignments 清空全部人脸归属（重新聚类前调用）。
func ResetAllFaceAssignments() error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return withTx(ctx, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `UPDATE ai.faces SET person_id = NULL`); err != nil {
			return fmt.Errorf("重置人脸归属失败: %w", err)
		}
		if _, err := tx.Exec(ctx, `DELETE FROM ai.persons`); err != nil {
			return fmt.Errorf("清空人物分组失败: %w", err)
		}
		return nil
	})
}

func refreshPersonStats(ctx context.Context, q querier, personIDs []uuid.UUID) error {
	if len(personIDs) == 0 {
		return nil
	}
	_, err := q.Exec(ctx, `
		UPDATE ai.persons p
		SET face_count = c.n, cover_face_id = c.cover
		FROM (
			SELECT p2.id,
			       (SELECT COUNT(*) FROM ai.faces f WHERE f.person_id = p2.id) AS n,
			       (SELECT f2.id FROM ai.faces f2 WHERE f2.person_id = p2.id
			        ORDER BY f2.quality DESC, f2.det_score DESC LIMIT 1) AS cover
			FROM ai.persons p2 WHERE p2.id = ANY($1)
		) c
		WHERE p.id = c.id`, personIDs)
	if err != nil {
		return fmt.Errorf("重算人物统计失败: %w", err)
	}
	return nil
}

// ---------- 结构化筛选（组合搜索的候选集） ----------

// SearchFilters 结构化筛选条件（语义相关度在 Go 侧计算，不在此处）。
type SearchFilters struct {
	Keyword        string      // 命中 OCR 文本 / VLM 描述 / VLM 关键词
	Filename       string      // 命中文件路径（文件名或扩展名，忽略大小写）
	VLMTags        []string    // AI 标签（任一命中；只读，与人工标签分开）
	TagIDs         []uuid.UUID // 人工标签（任一命中）
	Descendants    bool        // 标签是否含子孙
	PersonIDs      []uuid.UUID // 人物分组（任一命中）
	MimeType       string
	From, To       *time.Time
	IncludeDeleted bool
	SortBy         string
	SortOrder      string
	Limit          int
	Offset         int
}

// BuildSearchWhere 生成 WHERE 片段与参数（供候选集查询与计数复用）。
func BuildSearchWhere(f SearchFilters) (string, []any) {
	conditions := []string{}
	args := []any{}

	if !f.IncludeDeleted {
		conditions = append(conditions, "m.is_deleted = false")
	}
	if strings.TrimSpace(f.Keyword) != "" {
		args = append(args, "%"+strings.TrimSpace(f.Keyword)+"%")
		idx := len(args)
		conditions = append(conditions, fmt.Sprintf(`(
			EXISTS (SELECT 1 FROM ai.media_ai a WHERE a.media_id = m.id
			        AND (a.ocr_text ILIKE $%d OR a.caption ILIKE $%d))
			OR EXISTS (SELECT 1 FROM ai.media_ai a WHERE a.media_id = m.id
			           AND EXISTS (SELECT 1 FROM unnest(a.vlm_tags) t WHERE t ILIKE $%d))
		)`, idx, idx, idx))
	}
	if len(f.VLMTags) > 0 {
		args = append(args, f.VLMTags)
		conditions = append(conditions, fmt.Sprintf(
			`EXISTS (SELECT 1 FROM ai.media_ai a WHERE a.media_id = m.id AND a.vlm_tags && $%d)`, len(args)))
	}
	if strings.TrimSpace(f.Filename) != "" {
		args = append(args, "%"+strings.TrimSpace(f.Filename)+"%")
		conditions = append(conditions, fmt.Sprintf("m.file_path ILIKE $%d", len(args)))
	}
	if len(f.TagIDs) > 0 {
		args = append(args, f.TagIDs)
		idx := len(args)
		if f.Descendants {
			conditions = append(conditions, fmt.Sprintf(`EXISTS (
				SELECT 1 FROM gallery.media_tag_links l WHERE l.media_id = m.id AND l.tag_id IN (
					WITH RECURSIVE sub AS (
						SELECT id FROM gallery.tags WHERE id = ANY($%d)
						UNION ALL
						SELECT t.id FROM gallery.tags t JOIN sub ON t.parent_id = sub.id
					) SELECT id FROM sub))`, idx))
		} else {
			conditions = append(conditions, fmt.Sprintf(
				`EXISTS (SELECT 1 FROM gallery.media_tag_links l WHERE l.media_id = m.id AND l.tag_id = ANY($%d))`, idx))
		}
	}
	if len(f.PersonIDs) > 0 {
		args = append(args, f.PersonIDs)
		conditions = append(conditions, fmt.Sprintf(
			`EXISTS (SELECT 1 FROM ai.faces fa WHERE fa.media_id = m.id AND fa.person_id = ANY($%d))`, len(args)))
	}
	if f.MimeType != "" {
		if strings.Contains(f.MimeType, "/") {
			args = append(args, f.MimeType)
			conditions = append(conditions, fmt.Sprintf("m.mime_type = $%d", len(args)))
		} else {
			args = append(args, f.MimeType+"/%")
			conditions = append(conditions, fmt.Sprintf("m.mime_type LIKE $%d", len(args)))
		}
	}
	if f.From != nil {
		args = append(args, *f.From)
		conditions = append(conditions, fmt.Sprintf("m.captured_at >= $%d", len(args)))
	}
	if f.To != nil {
		args = append(args, *f.To)
		conditions = append(conditions, fmt.Sprintf("m.captured_at <= $%d", len(args)))
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}
	return where, args
}

// SearchMediaIDs 返回满足结构化条件的媒体 ID 及总数。
func SearchMediaIDs(f SearchFilters) ([]uuid.UUID, int, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	where, args := BuildSearchWhere(f)

	var total int
	if err := db.GetPool().QueryRow(ctx,
		fmt.Sprintf(`SELECT COUNT(*) FROM gallery.media_assets m WHERE %s`, where),
		args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("统计搜索结果失败: %w", err)
	}

	order := "m.captured_at"
	switch f.SortBy {
	case "size_bytes":
		order = "m.size_bytes"
	case "file_path":
		order = "m.file_path"
	}
	if strings.EqualFold(f.SortOrder, "asc") {
		order += " ASC"
	} else {
		order += " DESC"
	}

	query := fmt.Sprintf(`
		SELECT m.id FROM gallery.media_assets m
		WHERE %s ORDER BY %s, m.id ASC LIMIT $%d OFFSET $%d`,
		where, order, len(args)+1, len(args)+2)

	rows, err := db.GetPool().Query(ctx, query, append(args, f.Limit, f.Offset)...)
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
	return ids, total, rows.Err()
}

// VLMTagCount AI 标签及其出现次数（供客户端展示只读的 AI 标签筛选）。
type VLMTagCount struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

// ListVLMTags 聚合未删除媒体的全部 AI 标签。
//
// 一次全表 unnest 聚合；VLM 产物规模远小于媒体总数，代价可接受。
func ListVLMTags(limit int) ([]VLMTagCount, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	if limit <= 0 || limit > 2000 {
		limit = 500
	}

	rows, err := db.GetPool().Query(ctx, `
		SELECT t.tag, COUNT(*)::int AS n
		FROM ai.media_ai a
		JOIN gallery.media_assets m ON m.id = a.media_id
		CROSS JOIN LATERAL unnest(a.vlm_tags) AS t(tag)
		WHERE m.is_deleted = false AND t.tag <> ''
		GROUP BY t.tag
		ORDER BY n DESC, t.tag ASC
		LIMIT $1`, limit)
	if err != nil {
		return nil, fmt.Errorf("聚合 AI 标签失败: %w", err)
	}
	defer rows.Close()

	out := []VLMTagCount{}
	for rows.Next() {
		var item VLMTagCount
		if err := rows.Scan(&item.Tag, &item.Count); err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

// CountMediaMissingAll 一次扫描算出各能力"尚无产物"的未删除媒体数。
//
// 用 LEFT JOIN 而非 5 个相关 EXISTS：三次哈希连接远快于五个逐行子计划。
// ai.media_ai 以 media_id 为主键、另两张表先各自去重，因此不会放大行数。
func CountMediaMissingAll() (map[string]int, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	counts := map[string]int{}
	var phash, embed, face, ocr, vlm int
	err := db.GetPool().QueryRow(ctx, `
		SELECT
			COUNT(*) FILTER (WHERE a.media_id IS NULL OR a.phash IS NULL),
			COUNT(*) FILTER (WHERE e.media_id IS NULL),
			COUNT(*) FILTER (WHERE f.media_id IS NULL),
			COUNT(*) FILTER (WHERE a.media_id IS NULL OR a.ocr_text IS NULL),
			COUNT(*) FILTER (WHERE a.media_id IS NULL OR a.caption IS NULL)
		FROM gallery.media_assets m
		LEFT JOIN ai.media_ai a ON a.media_id = m.id
		LEFT JOIN (SELECT DISTINCT media_id FROM ai.embeddings) e ON e.media_id = m.id
		LEFT JOIN (SELECT DISTINCT media_id FROM ai.faces) f ON f.media_id = m.id
		WHERE m.is_deleted = false`).Scan(&phash, &embed, &face, &ocr, &vlm)
	if err != nil {
		return nil, fmt.Errorf("统计待处理媒体失败: %w", err)
	}

	counts[model.CapPHash] = phash
	counts[model.CapEmbed] = embed
	counts[model.CapFace] = face
	counts[model.CapOCR] = ocr
	counts[model.CapVLM] = vlm
	return counts, nil
}
