package gallery_repo

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"errors"
	"sort"
	"strings"

	"github.com/google/uuid"

	"monarch/internal/service/db"
)

func LibraryID(ctx context.Context) (string, error) {
	var id string
	const query = `SELECT id FROM gallery_library WHERE slot = 1`
	err := db.Read().QueryRowContext(ctx, query).Scan(&id)
	if !errors.Is(err, sql.ErrNoRows) {
		return id, err
	}
	if _, err := db.Exec(ctx, `INSERT OR IGNORE INTO gallery_library (slot, id) VALUES (1, ?)`, uuid.NewString()); err != nil {
		return "", err
	}
	err = db.Read().QueryRowContext(ctx, query).Scan(&id)
	return id, err
}

var ErrProcessedRequestMismatch = errors.New("标记已处理的请求编号已用于另一批媒体")

func registerProcessed(ctx context.Context, tx *sql.Tx, requestID uuid.UUID, ids []uuid.UUID) (bool, error) {
	keys := make([]string, len(ids))
	for i, id := range ids {
		keys[i] = id.String()
	}
	sort.Strings(keys)
	sum := sha256.Sum256([]byte(strings.Join(keys, ",")))
	result, err := tx.ExecContext(ctx, `INSERT OR IGNORE INTO gallery_processed_requests
		(request_id, media_ids_hash) VALUES (?, ?)`, requestID, sum[:])
	if err != nil {
		return false, err
	}
	count, err := result.RowsAffected()
	if err != nil || count > 0 {
		return count > 0, err
	}
	var previous []byte
	if err := tx.QueryRowContext(ctx, `SELECT media_ids_hash FROM gallery_processed_requests WHERE request_id = ?`, requestID).Scan(&previous); err != nil {
		return false, err
	}
	if !bytes.Equal(previous, sum[:]) {
		return false, ErrProcessedRequestMismatch
	}
	return false, nil
}
