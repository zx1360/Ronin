package data_repo

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"reflect"
	"slices"

	"github.com/google/uuid"

	"monarch/internal/model"
)

type EssayReceipt struct {
	ID           uuid.UUID `json:"id"`
	ContentSaved bool      `json:"content_saved"`
	LabelsSaved  bool      `json:"labels_saved"`
}

func essayReceipts(ctx context.Context, tx *sql.Tx, essays []model.EssayArticle) ([]EssayReceipt, error) {
	receipts := make([]EssayReceipt, 0, len(essays))
	for _, essay := range essays {
		receipt := EssayReceipt{ID: essay.ID}
		var title, content string
		var mood *string
		var images, labels, messages []byte
		err := tx.QueryRowContext(ctx, `SELECT title, content, mood, imgs, labels, messages
			FROM essay_articles WHERE id = ?`, essay.ID).Scan(&title, &content, &mood, &images, &labels, &messages)
		if errors.Is(err, sql.ErrNoRows) {
			receipts = append(receipts, receipt)
			continue
		}
		if err != nil {
			return nil, err
		}
		var savedImages, savedLabels []string
		var savedMessages, submittedMessages []any
		if err := errors.Join(
			json.Unmarshal(images, &savedImages),
			json.Unmarshal(labels, &savedLabels),
			json.Unmarshal(messages, &savedMessages),
			json.Unmarshal(essayMessages(essay.Messages), &submittedMessages),
		); err != nil {
			return nil, err
		}
		receipt.ContentSaved = title == essay.Title && content == essay.Content &&
			reflect.DeepEqual(mood, essay.Mood) && slices.Equal(savedImages, essay.Imgs) &&
			slices.EqualFunc(savedMessages, submittedMessages, reflect.DeepEqual)
		receipt.LabelsSaved = slices.Equal(savedLabels, essay.Labels)
		receipts = append(receipts, receipt)
	}
	return receipts, nil
}

func essayMessages(messages json.RawMessage) json.RawMessage {
	if len(messages) == 0 {
		return json.RawMessage("[]")
	}
	return messages
}
