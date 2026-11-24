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
	MediaID  uuid.UUID
	Kind     string
	Model    string
	Dim      int
	Scale    float32
	Vec      []byte
	InputSig string // 输入档位 + 执行者指纹（追溯用）
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
func LoadEmbeddings(ctx context.Context, kind, modelName string) ([]EmbeddingRow, error) {
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
func EmbeddingCount(ctx context.Context, kind, modelName string) (int, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
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

// VLMTagCount AI 标签及其出现次数（供客户端展示只读的 AI 标签筛选）。
type VLMTagCount struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

// ListVLMTags 聚合未删除媒体的全部 AI 标签。
func ListVLMTags(ctx context.Context, limit int) ([]VLMTagCount, error) {
	if limit <= 0 || limit > 2000 {
		limit = 500
	}

	rows, err := db.Read().QueryContext(ctx, `
		SELECT t.tag, COUNT(*) AS n
		FROM media_ai_tags t
		WHERE t.tag <> '' AND t.media_id IN (SELECT id FROM media_assets WHERE is_deleted = 0)
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
