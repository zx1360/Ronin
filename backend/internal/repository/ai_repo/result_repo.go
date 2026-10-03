package ai_repo

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"monarch/internal/dbutil"
	"monarch/internal/model"
	"monarch/internal/repository/gallery_repo"
	"monarch/internal/service/db"
)

// EmbeddingWrite 一条待写入的图像向量（int8 量化）。
type EmbeddingWrite struct {
	MediaID  uuid.UUID
	Kind     string
	Model    string
	Dim      int
	Scale    float32
	Vec      []byte
	InputSig string // 输入档位 + 执行者指纹（追溯用）
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
func SavePHash(mediaID uuid.UUID, hash int64, inputSig string) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.Exec(ctx, `
		INSERT INTO media_ai (media_id, phash, phash_input_sig) VALUES (?, ?, ?)
		ON CONFLICT (media_id) DO UPDATE SET phash = excluded.phash,
		                                     phash_input_sig = excluded.phash_input_sig`,
		mediaID, hash, inputSig)
	if err != nil {
		return fmt.Errorf("写入感知哈希失败: %w", err)
	}
	return nil
}

// SaveOCR 写入 OCR 文本（空文本同样落库，表示"已识别但无文字"）。
func SaveOCR(mediaID uuid.UUID, text, inputSig string) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.Exec(ctx, `
		INSERT INTO media_ai (media_id, ocr_text, ocr_input_sig) VALUES (?, ?, ?)
		ON CONFLICT (media_id) DO UPDATE SET ocr_text = excluded.ocr_text,
		                                     ocr_input_sig = excluded.ocr_input_sig`,
		mediaID, text, inputSig)
	if err != nil {
		return fmt.Errorf("写入 OCR 结果失败: %w", err)
	}
	return nil
}

// SaveVLM 写入 VLM 描述与关键词（关键词存 media_ai_tags，整批替换）。
func SaveVLM(mediaID uuid.UUID, caption string, tags []string, inputSig string) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	return db.Tx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO media_ai (media_id, caption, caption_input_sig) VALUES (?, ?, ?)
			ON CONFLICT (media_id) DO UPDATE SET caption = excluded.caption,
			                                     caption_input_sig = excluded.caption_input_sig`,
			mediaID, caption, inputSig); err != nil {
			return fmt.Errorf("写入 VLM 结果失败: %w", err)
		}
		return replaceVLMTags(ctx, tx, mediaID, tags)
	})
}

// replaceVLMTags 全量替换某媒体的 AI 标签。
func replaceVLMTags(ctx context.Context, tx *sql.Tx, mediaID uuid.UUID, tags []string) error {
	if _, err := tx.ExecContext(ctx, `DELETE FROM media_ai_tags WHERE media_id = ?`, mediaID); err != nil {
		return fmt.Errorf("清理旧 AI 标签失败: %w", err)
	}
	seen := map[string]bool{}
	for _, tag := range tags {
		tag = strings.TrimSpace(tag)
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO media_ai_tags (media_id, tag) VALUES (?, ?)`,
			mediaID, tag); err != nil {
			return fmt.Errorf("写入 AI 标签失败: %w", err)
		}
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

	return db.Tx(ctx, func(tx *sql.Tx) error {
		stmt, err := tx.PrepareContext(ctx, `
			INSERT INTO embeddings (media_id, kind, model, dim, scale, vec, input_sig)
			VALUES (?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT (media_id, kind, model) DO UPDATE
			SET dim = excluded.dim, scale = excluded.scale, vec = excluded.vec,
			    input_sig = excluded.input_sig`)
		if err != nil {
			return fmt.Errorf("准备向量写入失败: %w", err)
		}
		defer stmt.Close()
		for _, row := range rows {
			if _, err := stmt.ExecContext(ctx,
				row.MediaID, row.Kind, row.Model, row.Dim, row.Scale, row.Vec, row.InputSig); err != nil {
				return fmt.Errorf("写入图像向量失败: %w", err)
			}
		}
		return nil
	})
}

// ReplaceFaces 全量替换某媒体的人脸记录（重跑该能力时不留残留）。
//
// 被删除的人脸若曾作为人物封面，由外键 ON DELETE SET NULL 自动清理。
// 人物归属不在此处决定，交由聚类阶段统一维护。
func ReplaceFaces(mediaID uuid.UUID, faces []FaceWrite, inputSig string) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	return db.Tx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `DELETE FROM faces WHERE media_id = ?`, mediaID); err != nil {
			return fmt.Errorf("清理旧人脸失败: %w", err)
		}
		stmt, err := tx.PrepareContext(ctx, `
			INSERT INTO faces (id, media_id, bbox, det_score, quality, embedding, input_sig)
			VALUES (?, ?, ?, ?, ?, ?, ?)`)
		if err != nil {
			return fmt.Errorf("准备人脸写入失败: %w", err)
		}
		defer stmt.Close()
		for _, f := range faces {
			if _, err := stmt.ExecContext(ctx,
				f.ID, f.MediaID, encodeBox(f.Box), f.DetScore, f.Quality, f.Embedding, inputSig); err != nil {
				return fmt.Errorf("写入人脸失败: %w", err)
			}
		}
		return nil
	})
}

// encodeBox 把人脸框编码为 JSON 文本（SQLite 无数组类型）。
func encodeBox(box []float32) string {
	values := make([]float64, len(box))
	for i, v := range box {
		values[i] = float64(v)
	}
	raw, err := json.Marshal(values)
	if err != nil {
		return "[]"
	}
	return string(raw)
}

// decodeBox 解析人脸框 JSON 文本。
func decodeBox(raw string) []float64 {
	var values []float64
	if err := json.Unmarshal([]byte(raw), &values); err != nil {
		return []float64{}
	}
	return values
}

// ---------- 读取 ----------

// LoadPHashes 载入全部感知哈希（7w 条约 1MB，常驻内存便于快速分组）。
func LoadPHashes() (map[uuid.UUID]int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	rows, err := db.Read().QueryContext(ctx,
		`SELECT media_id, phash FROM media_ai WHERE phash IS NOT NULL`)
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
	rows, err := db.Read().QueryContext(ctx, `
		SELECT media_id, dim, scale, vec FROM embeddings WHERE kind = ? AND model = ?`,
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
	err := db.Read().QueryRowContext(ctx,
		`SELECT COUNT(*) FROM embeddings WHERE kind = ? AND model = ?`, kind, modelName).Scan(&n)
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
	err := db.Read().QueryRowContext(ctx, `
		SELECT dim, scale, vec FROM embeddings
		WHERE media_id = ? AND kind = ? AND model = ?`, mediaID, kind, modelName).
		Scan(&row.Dim, &row.Scale, &row.Vec)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
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
	err := db.Read().QueryRowContext(ctx, `
		SELECT phash, ocr_text, caption
		FROM media_ai WHERE media_id = ?`, mediaID).
		Scan(&detail.PHash, &detail.OCRText, &detail.Caption)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("读取媒体 AI 结果失败: %w", err)
	}

	tags, err := listVLMTagsByMedia(ctx, mediaID)
	if err != nil {
		return nil, err
	}
	detail.VLMTags = tags

	if err := db.Read().QueryRowContext(ctx,
		`SELECT EXISTS(SELECT 1 FROM embeddings WHERE media_id = ?)`, mediaID).
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

// listVLMTagsByMedia 读取单个媒体的 AI 标签。
func listVLMTagsByMedia(ctx context.Context, mediaID uuid.UUID) ([]string, error) {
	rows, err := db.Read().QueryContext(ctx,
		`SELECT tag FROM media_ai_tags WHERE media_id = ? ORDER BY tag`, mediaID)
	if err != nil {
		return nil, fmt.Errorf("读取 AI 标签失败: %w", err)
	}
	defer rows.Close()

	tags := []string{}
	for rows.Next() {
		var tag string
		if err := rows.Scan(&tag); err != nil {
			return nil, err
		}
		tags = append(tags, tag)
	}
	return tags, rows.Err()
}

// ListFacesByMedia 按媒体批量查询人脸。
func ListFacesByMedia(mediaIDs []uuid.UUID) (map[uuid.UUID][]model.AiFace, error) {
	if len(mediaIDs) == 0 {
		return map[uuid.UUID][]model.AiFace{}, nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.Read().QueryContext(ctx, `
		SELECT id, media_id, person_id, bbox, det_score, quality, created_at
		FROM faces WHERE media_id IN (`+placeholders(len(mediaIDs))+`) ORDER BY det_score DESC`,
		uuidArgs(mediaIDs)...)
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

// scanFaceRow 读取一行人脸记录（bbox 为 JSON 文本）。
func scanFaceRow(rows *sql.Rows) (model.AiFace, error) {
	var face model.AiFace
	var box string
	if err := rows.Scan(&face.ID, &face.MediaID, &face.PersonID, &box,
		&face.DetScore, &face.Quality, &face.CreatedAt); err != nil {
		return face, err
	}
	face.Box = decodeBox(box)
	return face, nil
}

// uuidArgs 把 UUID 列表转为 SQL 参数。
func uuidArgs(ids []uuid.UUID) []any {
	args := make([]any, len(ids))
	for i, id := range ids {
		args[i] = id
	}
	return args
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

	query := `SELECT id, person_id, quality, embedding FROM faces`
	if unassignedOnly {
		query += ` WHERE person_id IS NULL`
	}
	rows, err := db.Read().QueryContext(ctx, query)
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

	rows, err := db.Read().QueryContext(ctx, `
		SELECT p.id, p.name, p.cover_face_id, f.media_id, p.face_count, p.created_at, p.updated_at
		FROM persons p
		LEFT JOIN faces f ON f.id = p.cover_face_id
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
	if err := db.Read().QueryRowContext(ctx,
		`SELECT COUNT(*) FROM faces WHERE person_id = ?`, personID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("统计人物人脸失败: %w", err)
	}

	rows, err := db.Read().QueryContext(ctx, `
		SELECT id, media_id, person_id, bbox, det_score, quality, created_at
		FROM faces WHERE person_id = ?
		ORDER BY quality DESC, created_at ASC LIMIT ? OFFSET ?`, personID, limit, offset)
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
	_, err := db.Exec(ctx, `INSERT INTO persons (id, name) VALUES (?, ?)`, id, name)
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
	_, err := db.Exec(ctx,
		`UPDATE faces SET person_id = ? WHERE id IN (`+placeholders(len(faceIDs))+`)`,
		append([]any{personID}, uuidArgs(faceIDs)...)...)
	if err != nil {
		return fmt.Errorf("分配人脸失败: %w", err)
	}
	return nil
}

// RenamePerson 设置或清空人物名称。
func RenamePerson(personID uuid.UUID, name *string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	res, err := db.Exec(ctx, `UPDATE persons SET name = ? WHERE id = ?`, name, personID)
	if err != nil {
		return fmt.Errorf("重命名人物失败: %w", err)
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrPersonMissing
	}
	return nil
}

// MergePersons 把 srcIDs 下的人脸全部并到 dstID，并删除被合并的分组。
func MergePersons(srcIDs []uuid.UUID, dstID uuid.UUID) (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	var moved int64
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx,
			`UPDATE faces SET person_id = ? WHERE person_id IN (`+placeholders(len(srcIDs))+`)`,
			append([]any{dstID}, uuidArgs(srcIDs)...)...)
		if err != nil {
			return fmt.Errorf("合并人脸失败: %w", err)
		}
		moved, _ = res.RowsAffected()
		if _, err := tx.ExecContext(ctx,
			`DELETE FROM persons WHERE id IN (`+placeholders(len(srcIDs))+`)`,
			uuidArgs(srcIDs)...); err != nil {
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
	res, err := db.Exec(ctx, `DELETE FROM persons WHERE id = ?`, personID)
	if err != nil {
		return fmt.Errorf("删除人物失败: %w", err)
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrPersonMissing
	}
	return nil
}

// RefreshPersonStats 重算指定人物的人脸数与封面（增量归并后调用）。
func RefreshPersonStats(personIDs []uuid.UUID) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return db.Tx(ctx, func(tx *sql.Tx) error {
		return refreshPersonStats(ctx, tx, personIDs)
	})
}

// RefreshAllPersonStats 重算全部人物的人脸数与封面（封面取质量最高的人脸）。
func RefreshAllPersonStats() error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if _, err := db.Exec(ctx, refreshPersonStatsSQL); err != nil {
		return fmt.Errorf("重算人物统计失败: %w", err)
	}
	return nil
}

// refreshPersonStatsSQL 以相关子查询重算人脸数与封面；SQLite 无 UPDATE ... FROM，
// 但人物数很小（十级），逐行子查询代价可忽略。
const refreshPersonStatsSQL = `
	UPDATE persons SET
		face_count = (SELECT COUNT(*) FROM faces f WHERE f.person_id = persons.id),
		cover_face_id = (SELECT f.id FROM faces f WHERE f.person_id = persons.id
		                 ORDER BY f.quality DESC, f.det_score DESC LIMIT 1)`

func refreshPersonStats(ctx context.Context, q querier, personIDs []uuid.UUID) error {
	if len(personIDs) == 0 {
		return nil
	}
	_, err := q.ExecContext(ctx,
		refreshPersonStatsSQL+` WHERE id IN (`+placeholders(len(personIDs))+`)`,
		uuidArgs(personIDs)...)
	if err != nil {
		return fmt.Errorf("重算人物统计失败: %w", err)
	}
	return nil
}

// DropEmptyPersons 删除没有任何人脸的空分组。
func DropEmptyPersons() (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	res, err := db.Exec(ctx, `
		DELETE FROM persons WHERE NOT EXISTS (SELECT 1 FROM faces f WHERE f.person_id = persons.id)`)
	if err != nil {
		return 0, fmt.Errorf("清理空人物分组失败: %w", err)
	}
	n, _ := res.RowsAffected()
	return n, nil
}

// ResetAllFaceAssignments 清空全部人脸归属（重新聚类前调用）。
func ResetAllFaceAssignments() error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return db.Tx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `UPDATE faces SET person_id = NULL`); err != nil {
			return fmt.Errorf("重置人脸归属失败: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM persons`); err != nil {
			return fmt.Errorf("清空人物分组失败: %w", err)
		}
		return nil
	})
}

// ---------- 结构化筛选（组合搜索的候选集） ----------

// SearchFilters 结构化筛选条件（语义相关度在 Go 侧计算，不在此处）。
type SearchFilters struct {
	Keyword        string      // 命中 OCR 文本 / VLM 描述 / AI 关键词
	Filename       string      // 命中文件路径（文件名或扩展名，忽略大小写）
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
	if strings.TrimSpace(f.Keyword) != "" {
		// SQLite 的 LIKE 对 ASCII 大小写不敏感，正好覆盖关键词检索；
		// 无 trigram 索引，这里对 media_ai 做一次全表扫描（见 AGENTS_DB.md 的性能说明）。
		pattern := "%" + strings.TrimSpace(f.Keyword) + "%"
		args = append(args, pattern, pattern, pattern)
		conditions = append(conditions, `m.id IN (
			SELECT a.media_id FROM media_ai a WHERE a.ocr_text LIKE ? OR a.caption LIKE ?
			UNION
			SELECT t.media_id FROM media_ai_tags t WHERE t.tag LIKE ?
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
	if strings.TrimSpace(f.Filename) != "" {
		args = append(args, "%"+strings.TrimSpace(f.Filename)+"%")
		conditions = append(conditions, "m.file_path LIKE ?")
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

// SearchMediaIDs 返回满足结构化条件的媒体 ID 及总数。
func SearchMediaIDs(f SearchFilters) ([]uuid.UUID, int, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	if f.Descendants && len(f.TagIDs) > 0 {
		expanded, err := gallery_repo.ExpandTagIDs(f.TagIDs)
		if err != nil {
			return nil, 0, err
		}
		f.TagIDs = expanded
	}

	where, args := BuildSearchWhere(f)

	var total int
	if err := db.Read().QueryRowContext(ctx,
		fmt.Sprintf(`SELECT COUNT(*) FROM media_assets m WHERE %s`, where),
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
		SELECT m.id FROM media_assets m
		WHERE %s ORDER BY %s, m.id ASC LIMIT ? OFFSET ?`, where, order)

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
	return ids, total, rows.Err()
}

// VLMTagCount AI 标签及其出现次数（供客户端展示只读的 AI 标签筛选）。
type VLMTagCount struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

// ListVLMTags 聚合未删除媒体的全部 AI 标签。
func ListVLMTags(limit int) ([]VLMTagCount, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	if limit <= 0 || limit > 2000 {
		limit = 500
	}

	rows, err := db.Read().QueryContext(ctx, `
		SELECT t.tag, COUNT(*) AS n
		FROM media_ai_tags t
		JOIN media_assets m ON m.id = t.media_id
		WHERE m.is_deleted = 0 AND t.tag <> ''
		GROUP BY t.tag
		ORDER BY n DESC, t.tag ASC
		LIMIT ?`, limit)
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

// CountUndeletedMedia 返回未删除媒体总数（能力进度的分母）。
func CountUndeletedMedia() (int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	var n int
	err := db.Read().QueryRowContext(ctx,
		`SELECT COUNT(*) FROM media_assets WHERE is_deleted = 0`).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("统计媒体总数失败: %w", err)
	}
	return n, nil
}

// CountMediaMissingAll 一次扫描算出各能力"尚无产物"的未删除媒体数。
//
// 用 LEFT JOIN 而非 5 个相关 EXISTS：三次哈希连接远快于五个逐行子计划。
// media_ai 以 media_id 为主键、另两张表先各自去重，因此不会放大行数。
func CountMediaMissingAll() (map[string]int, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	counts := map[string]int{}
	var phash, embed, face, ocr, vlm int
	err := db.Read().QueryRowContext(ctx, `
		SELECT
			COUNT(*) FILTER (WHERE a.media_id IS NULL OR a.phash IS NULL),
			COUNT(*) FILTER (WHERE e.media_id IS NULL),
			COUNT(*) FILTER (WHERE f.media_id IS NULL),
			COUNT(*) FILTER (WHERE a.media_id IS NULL OR a.ocr_text IS NULL),
			COUNT(*) FILTER (WHERE a.media_id IS NULL OR a.caption IS NULL)
		FROM media_assets m
		LEFT JOIN media_ai a ON a.media_id = m.id
		LEFT JOIN (SELECT DISTINCT media_id FROM embeddings) e ON e.media_id = m.id
		LEFT JOIN (SELECT DISTINCT media_id FROM faces) f ON f.media_id = m.id
		WHERE m.is_deleted = 0`).Scan(&phash, &embed, &face, &ocr, &vlm)
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
