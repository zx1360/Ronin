package ai_repo

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

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

// markResult 在结果写入的同一事务内登记 (媒体, 能力) 的输入档位与执行者。
func markResult(ctx context.Context, tx *sql.Tx, mediaID uuid.UUID, capability, tier, executor string) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO ai_results (media_id, capability, input_tier, executor, updated_at)
		VALUES (?, ?, ?, ?, ?)
		ON CONFLICT (media_id, capability) DO UPDATE SET
			input_tier = excluded.input_tier,
			executor   = excluded.executor,
			updated_at = excluded.updated_at`,
		mediaID, capability, tier, executor, model.Now())
	if err != nil {
		return fmt.Errorf("写入结果溯源失败: %w", err)
	}
	return nil
}

// ---------- 写入 ----------

// SavePHash 写入感知哈希（-1 表示无法解码，同样落库以避免重复尝试），
// 并登记本次结果所用的输入档位与执行者。
func SavePHash(mediaID uuid.UUID, hash int64, tier, executor string) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return db.Tx(ctx, func(tx *sql.Tx) error {
		now := model.Now()
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO ai_media (media_id, phash, updated_at) VALUES (?, ?, ?)
			ON CONFLICT (media_id) DO UPDATE SET
				phash = excluded.phash, updated_at = excluded.updated_at`,
			mediaID, hash, now); err != nil {
			return fmt.Errorf("写入感知哈希失败: %w", err)
		}
		return markResult(ctx, tx, mediaID, model.CapPHash, tier, executor)
	})
}

// SaveOCR 写入 OCR 文本（空文本同样落库，表示"已识别但无文字"），
// 并登记本次结果所用的输入档位与执行者。
func SaveOCR(mediaID uuid.UUID, text, tier, executor string) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return db.Tx(ctx, func(tx *sql.Tx) error {
		now := model.Now()
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO ai_media (media_id, ocr_text, updated_at) VALUES (?, ?, ?)
			ON CONFLICT (media_id) DO UPDATE SET
				ocr_text = excluded.ocr_text, updated_at = excluded.updated_at`,
			mediaID, text, now); err != nil {
			return fmt.Errorf("写入 OCR 结果失败: %w", err)
		}
		return markResult(ctx, tx, mediaID, model.CapOCR, tier, executor)
	})
}

// SaveVLM 写入 VLM 描述与关键词，并登记本次结果所用的输入档位与执行者。
func SaveVLM(mediaID uuid.UUID, caption string, tags []string, tier, executor string) error {
	rawTags, err := encodeJSONArray(tags)
	if err != nil {
		return fmt.Errorf("序列化 AI 关键词失败: %w", err)
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return db.Tx(ctx, func(tx *sql.Tx) error {
		now := model.Now()
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO ai_media (media_id, caption, vlm_tags, updated_at) VALUES (?, ?, ?, ?)
			ON CONFLICT (media_id) DO UPDATE SET
				caption = excluded.caption, vlm_tags = excluded.vlm_tags, updated_at = excluded.updated_at`,
			mediaID, caption, rawTags, now); err != nil {
			return fmt.Errorf("写入 VLM 结果失败: %w", err)
		}
		return markResult(ctx, tx, mediaID, model.CapVLM, tier, executor)
	})
}

// SaveEmbeddings 批量写入图像向量（同媒体同模型覆盖），并登记结果溯源。
//
// 整批在一个事务内写入，任一条失败整批回滚。
// executor 应与 EmbeddingWrite.Model 一致：ai_results.executor 与 ai_embeddings.model
// 表示同一个执行者。
func SaveEmbeddings(rows []EmbeddingWrite, tier, executor string) error {
	if len(rows) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	return db.Tx(ctx, func(tx *sql.Tx) error {
		now := model.Now()
		for _, row := range rows {
			if _, err := tx.ExecContext(ctx, `
				INSERT INTO ai_embeddings (media_id, kind, model, dim, scale, vec, updated_at)
				VALUES (?, ?, ?, ?, ?, ?, ?)
				ON CONFLICT (media_id, kind, model) DO UPDATE SET
					dim = excluded.dim, scale = excluded.scale,
					vec = excluded.vec, updated_at = excluded.updated_at`,
				row.MediaID, row.Kind, row.Model, row.Dim, row.Scale, row.Vec, now); err != nil {
				return fmt.Errorf("写入图像向量失败: %w", err)
			}
			if err := markResult(ctx, tx, row.MediaID, model.CapEmbed, tier, executor); err != nil {
				return err
			}
		}
		return nil
	})
}

// ReplaceFaces 全量替换某媒体的人脸记录（重跑该能力时不留残留），
// 并按媒体登记一行 face 能力的结果溯源。
//
// 被删除的人脸若曾作为人物封面，由外键 ON DELETE SET NULL 自动清理。
// 人物归属不在此处决定，交由聚类阶段统一维护。
func ReplaceFaces(mediaID uuid.UUID, faces []FaceWrite, tier, executor string) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	return db.Tx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `DELETE FROM ai_faces WHERE media_id = ?`, mediaID); err != nil {
			return fmt.Errorf("清理旧人脸失败: %w", err)
		}
		now := model.Now()
		for _, f := range faces {
			rawBox, err := encodeJSONArray(f.Box)
			if err != nil {
				return fmt.Errorf("序列化人脸框失败: %w", err)
			}
			if _, err := tx.ExecContext(ctx, `
				INSERT INTO ai_faces (id, media_id, bbox, det_score, quality, embedding, created_at)
				VALUES (?, ?, ?, ?, ?, ?, ?)`,
				f.ID, f.MediaID, rawBox, f.DetScore, f.Quality, f.Embedding, now); err != nil {
				return fmt.Errorf("写入人脸失败: %w", err)
			}
		}
		return markResult(ctx, tx, mediaID, model.CapFace, tier, executor)
	})
}

// ---------- 读取 ----------

// LoadPHashes 载入全部感知哈希（7w 条约 1MB，常驻内存便于快速分组）。
func LoadPHashes() (map[uuid.UUID]int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	rows, err := db.R().QueryContext(ctx,
		`SELECT media_id, phash FROM ai_media WHERE phash IS NOT NULL`)
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
	rows, err := db.R().QueryContext(ctx, `
		SELECT media_id, dim, scale, vec FROM ai_embeddings WHERE kind = ? AND model = ?`,
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
	err := db.R().QueryRowContext(ctx,
		`SELECT COUNT(*) FROM ai_embeddings WHERE kind = ? AND model = ?`, kind, modelName).Scan(&n)
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
	err := db.R().QueryRowContext(ctx, `
		SELECT dim, scale, vec FROM ai_embeddings
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
	var rawTags string
	err := db.R().QueryRowContext(ctx, `
		SELECT phash, ocr_text, caption, vlm_tags
		FROM ai_media WHERE media_id = ?`, mediaID).
		Scan(&detail.PHash, &detail.OCRText, &detail.Caption, &rawTags)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("读取媒体 AI 结果失败: %w", err)
	}
	if err == nil {
		tags, err := decodeJSONArray[string](rawTags)
		if err != nil {
			return nil, fmt.Errorf("解析 AI 关键词失败: %w", err)
		}
		detail.VLMTags = tags
	}

	if err := db.R().QueryRowContext(ctx,
		`SELECT EXISTS(SELECT 1 FROM ai_embeddings WHERE media_id = ?)`, mediaID).
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

// ListStaleMediaIDs 返回 ai_results 中 (输入档位, 执行者) 与期望规格不符、或尚无记录的媒体 ID。
func ListStaleMediaIDs(capability, tier, executor string, limit int) ([]uuid.UUID, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	if limit <= 0 {
		limit = -1 // SQLite：负数 LIMIT 表示不设上限
	}

	rows, err := db.R().QueryContext(ctx, `
		SELECT m.id
		FROM gallery_media_assets m
		LEFT JOIN ai_results r ON r.media_id = m.id AND r.capability = ?
		WHERE m.is_deleted = 0
		  AND (r.media_id IS NULL OR r.input_tier <> ? OR r.executor <> ?)
		ORDER BY m.captured_at
		LIMIT ?`, capability, tier, executor, limit)
	if err != nil {
		return nil, fmt.Errorf("查询待重排媒体失败: %w", err)
	}
	defer rows.Close()

	ids := []uuid.UUID{}
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// ListFacesByMedia 按媒体批量查询人脸。
func ListFacesByMedia(mediaIDs []uuid.UUID) (map[uuid.UUID][]model.AiFace, error) {
	if len(mediaIDs) == 0 {
		return map[uuid.UUID][]model.AiFace{}, nil
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `
		SELECT id, media_id, person_id, bbox, det_score, quality, created_at
		FROM ai_faces WHERE media_id IN (`+placeholders(len(mediaIDs))+`)
		ORDER BY det_score DESC`, anyArgs(mediaIDs)...)
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

// scanFaceRow 读取一行人脸记录（bbox 为 JSON 文本，解析成 float64 切片）。
func scanFaceRow(rows *sql.Rows) (model.AiFace, error) {
	var face model.AiFace
	var rawBox, createdAt string
	if err := rows.Scan(&face.ID, &face.MediaID, &face.PersonID, &rawBox,
		&face.DetScore, &face.Quality, &createdAt); err != nil {
		return face, err
	}
	box, err := decodeJSONArray[float64](rawBox)
	if err != nil {
		return face, fmt.Errorf("解析人脸框失败: %w", err)
	}
	face.Box = box
	t, err := model.ParseTime(createdAt)
	if err != nil {
		return face, fmt.Errorf("解析人脸时间失败: %w", err)
	}
	face.CreatedAt = t
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

	query := `SELECT id, person_id, quality, embedding FROM ai_faces`
	if unassignedOnly {
		query += ` WHERE person_id IS NULL`
	}
	rows, err := db.R().QueryContext(ctx, query)
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

	rows, err := db.R().QueryContext(ctx, `
		SELECT p.id, p.name, p.cover_face_id, f.media_id, p.face_count, p.created_at, p.updated_at
		FROM ai_persons p
		LEFT JOIN ai_faces f ON f.id = p.cover_face_id
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
		var createdAt, updatedAt string
		if err := rows.Scan(&p.ID, &p.Name, &coverFace, &coverMedia,
			&p.FaceCount, &createdAt, &updatedAt); err != nil {
			return nil, fmt.Errorf("扫描人物行失败: %w", err)
		}
		if coverFace != nil {
			s := coverFace.String()
			p.CoverFaceID = &s
		}
		if coverMedia != nil {
			s := coverMedia.String()
			p.CoverMedia = &s
		}
		if p.CreatedAt, err = model.ParseTime(createdAt); err != nil {
			return nil, fmt.Errorf("解析人物创建时间失败: %w", err)
		}
		if p.UpdatedAt, err = model.ParseTime(updatedAt); err != nil {
			return nil, fmt.Errorf("解析人物更新时间失败: %w", err)
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
	if err := db.R().QueryRowContext(ctx,
		`SELECT COUNT(*) FROM ai_faces WHERE person_id = ?`, personID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("统计人物人脸失败: %w", err)
	}

	rows, err := db.R().QueryContext(ctx, `
		SELECT id, media_id, person_id, bbox, det_score, quality, created_at
		FROM ai_faces WHERE person_id = ?
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
	now := model.Now()
	_, err := db.W().ExecContext(ctx,
		`INSERT INTO ai_persons (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)`,
		id, name, now, now)
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
	args := append([]any{personID}, anyArgs(faceIDs)...)
	_, err := db.W().ExecContext(ctx,
		`UPDATE ai_faces SET person_id = ? WHERE id IN (`+placeholders(len(faceIDs))+`)`, args...)
	if err != nil {
		return fmt.Errorf("分配人脸失败: %w", err)
	}
	return nil
}

// RenamePerson 设置或清空人物名称。
func RenamePerson(personID uuid.UUID, name *string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	res, err := db.W().ExecContext(ctx,
		`UPDATE ai_persons SET name = ?, updated_at = ? WHERE id = ?`,
		name, model.Now(), personID)
	if err != nil {
		return fmt.Errorf("重命名人物失败: %w", err)
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return ErrPersonMissing
	}
	return nil
}

// MergePersons 把 srcIDs 下的人脸全部并到 dstID，并删除被合并的分组。
func MergePersons(srcIDs []uuid.UUID, dstID uuid.UUID) (int64, error) {
	if len(srcIDs) == 0 {
		return 0, nil
	}
	// dstID 混在 srcIDs 里会把目标分组一并删掉，先剔除。
	sources := make([]uuid.UUID, 0, len(srcIDs))
	for _, id := range srcIDs {
		if id != dstID {
			sources = append(sources, id)
		}
	}
	if len(sources) == 0 {
		return 0, nil
	}

	ctx, cancel := db.GetLongCtx()
	defer cancel()

	var moved int64
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		moved = 0
		res, err := tx.ExecContext(ctx,
			`UPDATE ai_faces SET person_id = ? WHERE person_id IN (`+placeholders(len(sources))+`)`,
			append([]any{dstID}, anyArgs(sources)...)...)
		if err != nil {
			return fmt.Errorf("合并人脸失败: %w", err)
		}
		if moved, err = res.RowsAffected(); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx,
			`DELETE FROM ai_persons WHERE id IN (`+placeholders(len(sources))+`)`,
			anyArgs(sources)...); err != nil {
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
	res, err := db.W().ExecContext(ctx, `DELETE FROM ai_persons WHERE id = ?`, personID)
	if err != nil {
		return fmt.Errorf("删除人物失败: %w", err)
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return ErrPersonMissing
	}
	return nil
}

// RefreshPersonStats 重算指定人物的人脸数与封面（增量归并后调用）。
func RefreshPersonStats(personIDs []uuid.UUID) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return refreshPersonStats(ctx, db.W(), personIDs)
}

// RefreshAllPersonStats 重算全部人物的人脸数与封面（封面取质量最高的人脸）。
func RefreshAllPersonStats() error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.W().ExecContext(ctx, refreshPersonStatsSQL, model.Now())
	if err != nil {
		return fmt.Errorf("重算人物统计失败: %w", err)
	}
	return nil
}

// DropEmptyPersons 删除没有任何人脸的空分组。
func DropEmptyPersons() (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	res, err := db.W().ExecContext(ctx, `
		DELETE FROM ai_persons
		WHERE NOT EXISTS (SELECT 1 FROM ai_faces f WHERE f.person_id = ai_persons.id)`)
	if err != nil {
		return 0, fmt.Errorf("清理空人物分组失败: %w", err)
	}
	return res.RowsAffected()
}

// ResetAllFaceAssignments 清空全部人脸归属（重新聚类前调用）。
func ResetAllFaceAssignments() error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return db.Tx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `UPDATE ai_faces SET person_id = NULL`); err != nil {
			return fmt.Errorf("重置人脸归属失败: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM ai_persons`); err != nil {
			return fmt.Errorf("清空人物分组失败: %w", err)
		}
		return nil
	})
}

// refreshPersonStatsSQL 用相关子查询重算统计（按人物主键逐行求值）。
const refreshPersonStatsSQL = `
	UPDATE ai_persons
	SET face_count = (SELECT COUNT(*) FROM ai_faces f WHERE f.person_id = ai_persons.id),
	    cover_face_id = (SELECT f2.id FROM ai_faces f2 WHERE f2.person_id = ai_persons.id
	                     ORDER BY f2.quality DESC, f2.det_score DESC LIMIT 1),
	    updated_at = ?`

func refreshPersonStats(ctx context.Context, q execer, personIDs []uuid.UUID) error {
	if len(personIDs) == 0 {
		return nil
	}
	args := append([]any{model.Now()}, anyArgs(personIDs)...)
	_, err := q.ExecContext(ctx,
		refreshPersonStatsSQL+` WHERE id IN (`+placeholders(len(personIDs))+`)`, args...)
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
//
// 通配匹配用 LIKE：SQLite 的 LIKE 对 ASCII 默认大小写不敏感（没有 ILIKE）。
func BuildSearchWhere(f SearchFilters) (string, []any) {
	conditions := []string{}
	args := []any{}

	if !f.IncludeDeleted {
		conditions = append(conditions, "m.is_deleted = 0")
	}
	if strings.TrimSpace(f.Keyword) != "" {
		like := "%" + strings.TrimSpace(f.Keyword) + "%"
		args = append(args, like, like, like)
		conditions = append(conditions, `(
			EXISTS (SELECT 1 FROM ai_media a WHERE a.media_id = m.id
			        AND (a.ocr_text LIKE ? OR a.caption LIKE ?))
			OR EXISTS (SELECT 1 FROM ai_media a WHERE a.media_id = m.id
			           AND EXISTS (SELECT 1 FROM json_each(a.vlm_tags) je WHERE je.value LIKE ?))
		)`)
	}
	if len(f.VLMTags) > 0 {
		args = append(args, anyArgs(f.VLMTags)...)
		conditions = append(conditions, `EXISTS (
			SELECT 1 FROM ai_media a
			WHERE a.media_id = m.id
			  AND EXISTS (SELECT 1 FROM json_each(a.vlm_tags) je
			              WHERE je.value IN (`+placeholders(len(f.VLMTags))+`)))`)
	}
	if strings.TrimSpace(f.Filename) != "" {
		args = append(args, "%"+strings.TrimSpace(f.Filename)+"%")
		conditions = append(conditions, "m.file_path LIKE ?")
	}
	if len(f.TagIDs) > 0 {
		args = append(args, anyArgs(f.TagIDs)...)
		if f.Descendants {
			conditions = append(conditions, `EXISTS (
				SELECT 1 FROM gallery_media_tag_links l WHERE l.media_id = m.id AND l.tag_id IN (
					WITH RECURSIVE sub AS (
						SELECT id FROM gallery_tags WHERE id IN (`+placeholders(len(f.TagIDs))+`)
						UNION ALL
						SELECT t.id FROM gallery_tags t JOIN sub ON t.parent_id = sub.id
					) SELECT id FROM sub))`)
		} else {
			conditions = append(conditions, `EXISTS (
				SELECT 1 FROM gallery_media_tag_links l
				WHERE l.media_id = m.id AND l.tag_id IN (`+placeholders(len(f.TagIDs))+`))`)
		}
	}
	if len(f.PersonIDs) > 0 {
		args = append(args, anyArgs(f.PersonIDs)...)
		conditions = append(conditions, `EXISTS (
			SELECT 1 FROM ai_faces fa
			WHERE fa.media_id = m.id AND fa.person_id IN (`+placeholders(len(f.PersonIDs))+`))`)
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
		args = append(args, model.FormatTime(*f.From))
		conditions = append(conditions, "m.captured_at >= ?")
	}
	if f.To != nil {
		args = append(args, model.FormatTime(*f.To))
		conditions = append(conditions, "m.captured_at <= ?")
	}

	where := "1=1"
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
	if err := db.R().QueryRowContext(ctx,
		`SELECT COUNT(*) FROM gallery_media_assets m WHERE `+where,
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

	query := `
		SELECT m.id FROM gallery_media_assets m
		WHERE ` + where + ` ORDER BY ` + order + `, m.id ASC LIMIT ? OFFSET ?`

	rows, err := db.R().QueryContext(ctx, query, append(args, f.Limit, f.Offset)...)
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
// 一次全表 json_each 聚合；VLM 产物规模远小于媒体总数，代价可接受。
func ListVLMTags(limit int) ([]VLMTagCount, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	if limit <= 0 || limit > 2000 {
		limit = 500
	}

	rows, err := db.R().QueryContext(ctx, `
		SELECT je.value AS tag, COUNT(*) AS n
		FROM ai_media a
		JOIN gallery_media_assets m ON m.id = a.media_id
		JOIN json_each(a.vlm_tags) AS je
		WHERE m.is_deleted = 0 AND je.value <> ''
		GROUP BY je.value
		ORDER BY n DESC, je.value ASC
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

// CountMediaMissingAll 一次扫描算出各能力"尚无产物"的未删除媒体数。
//
// 用 LEFT JOIN 而非 5 个相关 EXISTS：三次哈希连接远快于五个逐行子计划。
// ai_media 以 media_id 为主键、另两张表先各自去重，因此不会放大行数。
func CountMediaMissingAll() (map[string]int, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	counts := map[string]int{}
	var phash, embed, face, ocr, vlm int
	err := db.R().QueryRowContext(ctx, `
		SELECT
			COALESCE(SUM(CASE WHEN a.media_id IS NULL OR a.phash IS NULL THEN 1 ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN e.media_id IS NULL THEN 1 ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN f.media_id IS NULL THEN 1 ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN a.media_id IS NULL OR a.ocr_text IS NULL THEN 1 ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN a.media_id IS NULL OR a.caption IS NULL THEN 1 ELSE 0 END), 0)
		FROM gallery_media_assets m
		LEFT JOIN ai_media a ON a.media_id = m.id
		LEFT JOIN (SELECT DISTINCT media_id FROM ai_embeddings) e ON e.media_id = m.id
		LEFT JOIN (SELECT DISTINCT media_id FROM ai_faces) f ON f.media_id = m.id
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
