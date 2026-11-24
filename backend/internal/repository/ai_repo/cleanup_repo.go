package ai_repo

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

func enqueueFilter(capability string) string {
	if capability != model.CapCleanup {
		return ""
	}
	return ` AND (COALESCE(m.mime_type, '') = '' OR m.mime_type LIKE 'image/%' OR m.mime_type LIKE 'video/%')
	         AND NOT EXISTS (SELECT 1 FROM duplicate_ignores i WHERE i.media_id = m.id)`
}

type CleanupEvidence struct {
	Caption string `json:"caption,omitempty"`
	Text    string `json:"text,omitempty"`
	HasFace bool   `json:"has_face,omitempty"`
}

func ReadCleanupEvidence(ctx context.Context, id uuid.UUID) (CleanupEvidence, bool, error) {
	var evidence CleanupEvidence
	err := db.Read().QueryRowContext(ctx, `
		SELECT COALESCE(substr(a.caption, 1, 320), ''), COALESCE(substr(a.ocr_text, 1, 500), ''),
		       EXISTS (SELECT 1 FROM faces f WHERE f.media_id = m.id)
		FROM media_assets m LEFT JOIN media_ai a ON a.media_id = m.id
		WHERE m.id = ? AND m.is_deleted = 0`+enqueueFilter(model.CapCleanup), id).
		Scan(&evidence.Caption, &evidence.Text, &evidence.HasFace)
	if errors.Is(err, sql.ErrNoRows) {
		return evidence, false, nil
	}
	return evidence, err == nil, err
}

func SaveDeletionCandidate(ctx context.Context, id uuid.UUID, reason string) error {
	if reason == "" {
		_, err := db.Exec(ctx, `DELETE FROM deletion_candidates WHERE media_id = ?`, id)
		return err
	}
	_, err := db.Exec(ctx, `
		INSERT INTO deletion_candidates(media_id, reason) VALUES (?, ?)
		ON CONFLICT(media_id) DO UPDATE SET reason = excluded.reason`, id, reason)
	return err
}

type DeletionCandidate struct {
	MediaID uuid.UUID
	Reason  string
}

func ListDeletionCandidates(ctx context.Context, limit, offset int) ([]DeletionCandidate, error) {
	rows, err := db.Read().QueryContext(ctx, `
		SELECT d.media_id, d.reason
		FROM deletion_candidates d JOIN media_assets m ON m.id = d.media_id
		WHERE m.is_deleted = 0
		  AND NOT EXISTS (SELECT 1 FROM duplicate_ignores i WHERE i.media_id = m.id)
		ORDER BY d.media_id LIMIT ? OFFSET ?`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var candidates []DeletionCandidate
	for rows.Next() {
		var item DeletionCandidate
		if err := rows.Scan(&item.MediaID, &item.Reason); err != nil {
			return nil, err
		}
		candidates = append(candidates, item)
	}
	return candidates, rows.Err()
}

func CleanupProgress(ctx context.Context) (model.AiCapabilityStat, error) {
	progress := model.AiCapabilityStat{Capability: model.CapCleanup}
	err := db.Read().QueryRowContext(ctx, `
		SELECT COUNT(*) FILTER (WHERE status = 'pending'), COUNT(*) FILTER (WHERE status = 'running'),
		       COUNT(*) FILTER (WHERE status = 'done'), COUNT(*) FILTER (WHERE status = 'failed'), COUNT(*)
		FROM jobs WHERE capability = ?`, model.CapCleanup).
		Scan(&progress.Pending, &progress.Running, &progress.Done, &progress.Failed, &progress.Total)
	return progress, err
}
