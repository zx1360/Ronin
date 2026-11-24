package ai_repo

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// FaceWrite 一张待写入的人脸。
type FaceWrite struct {
	ID        uuid.UUID
	MediaID   uuid.UUID
	Box       []float32 // 归一化 x1,y1,x2,y2
	DetScore  float64
	Quality   float64
	Embedding []byte // 512 × float32
}

// ReplaceFaces 保留同一位置的人脸 ID 与人工归属，并返回需要归组的新检测。
func ReplaceFaces(mediaID uuid.UUID, faces []FaceWrite, inputSig string) ([]FaceWrite, bool, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	var added []FaceWrite
	var changed bool
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		added = added[:0]
		changed = false
		type detection struct {
			id  uuid.UUID
			box []float64
		}
		var old []detection
		people := make(map[uuid.UUID]bool)
		rows, err := tx.QueryContext(ctx, `SELECT id, bbox, person_id FROM faces WHERE media_id = ? ORDER BY id`, mediaID)
		if err != nil {
			return err
		}
		for rows.Next() {
			var faceID uuid.UUID
			var box string
			var person uuid.NullUUID
			if err := rows.Scan(&faceID, &box, &person); err != nil {
				rows.Close()
				return err
			}
			old = append(old, detection{id: faceID, box: decodeBox(box)})
			if person.Valid {
				people[person.UUID] = true
			}
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
		stmt, err := tx.PrepareContext(ctx, `
			INSERT INTO faces (id, media_id, bbox, det_score, quality, embedding, input_sig)
			VALUES (?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT(id) DO UPDATE SET bbox = excluded.bbox, det_score = excluded.det_score,
				quality = excluded.quality, embedding = excluded.embedding, input_sig = excluded.input_sig`)
		if err != nil {
			return fmt.Errorf("准备人脸写入失败: %w", err)
		}
		defer stmt.Close()
		for _, f := range faces {
			best, overlap := -1, 0.6
			for i, previous := range old {
				if previous.id == uuid.Nil {
					continue
				}
				if score := faceBoxOverlap(f.Box, previous.box); score > overlap {
					best, overlap = i, score
				}
			}
			if best >= 0 {
				f.ID = old[best].id
				old[best].id = uuid.Nil
			} else {
				added = append(added, f)
			}
			if _, err := stmt.ExecContext(ctx,
				f.ID, mediaID, encodeBox(f.Box), f.DetScore, f.Quality, f.Embedding, inputSig); err != nil {
				return fmt.Errorf("写入人脸失败: %w", err)
			}
		}
		for _, previous := range old {
			if previous.id != uuid.Nil {
				if _, err := tx.ExecContext(ctx, `DELETE FROM faces WHERE id = ?`, previous.id); err != nil {
					return err
				}
			}
		}
		changed = len(people) > 0
		ids := make([]uuid.UUID, 0, len(people))
		for id := range people {
			ids = append(ids, id)
		}
		return refreshPersonStats(ctx, tx, ids)
	})
	return added, changed, err
}

func faceBoxOverlap(a []float32, b []float64) float64 {
	if len(a) != 4 || len(b) != 4 {
		return 0
	}
	x := max(0, min(float64(a[2]), b[2])-max(float64(a[0]), b[0]))
	y := max(0, min(float64(a[3]), b[3])-max(float64(a[1]), b[1]))
	area := x * y
	if area == 0 {
		return 0
	}
	return area / (float64((a[2]-a[0])*(a[3]-a[1])) + (b[2]-b[0])*(b[3]-b[1]) - area)
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
// FaceEmbedding 聚类所需的单张人脸特征。
type FaceEmbedding struct {
	ID       uuid.UUID
	MediaID  uuid.UUID
	PersonID *uuid.UUID
	Quality  float64
	Vector   []float32
}

// LoadFaceEmbeddings 按归属筛选，assigned 为 nil 时读取所有人脸。
func LoadFaceEmbeddings(ctx context.Context, assigned *bool) ([]FaceEmbedding, error) {
	query := `SELECT id, media_id, person_id, quality, embedding FROM faces`
	switch {
	case assigned != nil && *assigned:
		query += ` WHERE person_id IS NOT NULL`
	case assigned != nil:
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
		if err := rows.Scan(&item.ID, &item.MediaID, &item.PersonID, &item.Quality, &raw); err != nil {
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

func assignFaceRows(ctx context.Context, q querier, faceIDs []uuid.UUID, personID *uuid.UUID) error {
	if len(faceIDs) == 0 {
		return nil
	}
	_, err := q.ExecContext(ctx,
		`UPDATE faces SET person_id = ? WHERE id IN (`+placeholders(len(faceIDs))+`)`,
		append([]any{personID}, uuidArgs(faceIDs)...)...)
	if err != nil {
		return fmt.Errorf("分配人脸失败: %w", err)
	}
	return nil
}

// ReassignFaces 人工纠正时同事务更新两侧统计并清理空分组。
func ReassignFaces(faceIDs []uuid.UUID, personID *uuid.UUID) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return db.Tx(ctx, func(tx *sql.Tx) error {
		if err := assignFaceRows(ctx, tx, faceIDs, personID); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, refreshPersonStatsSQL); err != nil {
			return err
		}
		_, err := tx.ExecContext(ctx, `DELETE FROM persons WHERE face_count = 0`)
		return err
	})
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

type FaceGroup struct {
	PersonID uuid.UUID
	FaceIDs  []uuid.UUID
	New      bool
}

func ApplyFaceGroups(ctx context.Context, groups []FaceGroup, reset bool) error {
	if len(groups) == 0 && !reset {
		return nil
	}
	return db.Tx(ctx, func(tx *sql.Tx) error {
		if reset {
			if _, err := tx.ExecContext(ctx, `DELETE FROM persons`); err != nil {
				return fmt.Errorf("重置人物分组失败: %w", err)
			}
		}
		touched := make([]uuid.UUID, 0, len(groups))
		for _, group := range groups {
			if group.New {
				if _, err := tx.ExecContext(ctx, `INSERT INTO persons (id) VALUES (?)`, group.PersonID); err != nil {
					return err
				}
			}
			for start := 0; start < len(group.FaceIDs); start += insertChunk {
				end := min(start+insertChunk, len(group.FaceIDs))
				if err := assignFaceRows(ctx, tx, group.FaceIDs[start:end], &group.PersonID); err != nil {
					return err
				}
			}
			touched = append(touched, group.PersonID)
		}
		for start := 0; start < len(touched); start += insertChunk {
			if err := refreshPersonStats(ctx, tx, touched[start:min(start+insertChunk, len(touched))]); err != nil {
				return err
			}
		}
		return nil
	})
}
