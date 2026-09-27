package ai_repo

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// ReviewPreset 近期回顾的语气与角色预设（可在前端编辑）。
type ReviewPreset struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Tone      string `json:"tone"`
	Role      string `json:"role"`
	IsDefault bool   `json:"is_default"`
}

// DefaultReviewPreset 是首次启动时写入的默认预设：中性、只陈述事实。
func DefaultReviewPreset() ReviewPreset {
	return ReviewPreset{
		ID:        uuid.NewString(),
		Name:      "平实记录",
		Tone:      "平实、克制，不夸张不煽情",
		Role:      "熟悉我日常节奏的记录者",
		IsDefault: true,
	}
}

// ListReviewPresets 返回全部预设，默认预设排首位。
func ListReviewPresets() ([]ReviewPreset, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	rows, err := db.R().QueryContext(ctx,
		`SELECT id, name, tone, role, is_default FROM ai_review_presets
		 ORDER BY is_default DESC, created_at ASC`)
	if err != nil {
		return nil, fmt.Errorf("查询回顾预设失败: %w", err)
	}
	defer rows.Close()

	out := []ReviewPreset{}
	for rows.Next() {
		var p ReviewPreset
		if err := rows.Scan(&p.ID, &p.Name, &p.Tone, &p.Role, &p.IsDefault); err != nil {
			return nil, fmt.Errorf("扫描回顾预设失败: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// GetReviewPreset 按 ID 取预设；不存在时返回 nil。
func GetReviewPreset(id string) (*ReviewPreset, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	var p ReviewPreset
	err := db.R().QueryRowContext(ctx,
		`SELECT id, name, tone, role, is_default FROM ai_review_presets WHERE id = ?`, id).
		Scan(&p.ID, &p.Name, &p.Tone, &p.Role, &p.IsDefault)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("查询回顾预设失败: %w", err)
	}
	return &p, nil
}

// UpsertReviewPreset 新增或更新预设；设为默认时会取消其它预设的默认标记。
func UpsertReviewPreset(p ReviewPreset) error {
	p.Name = strings.TrimSpace(p.Name)
	if p.ID == "" {
		p.ID = uuid.NewString()
	}
	if p.Name == "" {
		return errors.New("预设名称不能为空")
	}
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	now := model.Now()

	return db.Tx(ctx, func(tx *sql.Tx) error {
		if p.IsDefault {
			if _, err := tx.ExecContext(ctx,
				`UPDATE ai_review_presets SET is_default = 0, updated_at = ? WHERE is_default = 1`, now); err != nil {
				return fmt.Errorf("重置默认预设失败: %w", err)
			}
		}
		_, err := tx.ExecContext(ctx, `
			INSERT INTO ai_review_presets (id, name, tone, role, is_default, created_at, updated_at)
			VALUES (?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT (id) DO UPDATE SET
				name = excluded.name, tone = excluded.tone, role = excluded.role,
				is_default = excluded.is_default, updated_at = excluded.updated_at`,
			p.ID, p.Name, p.Tone, p.Role, p.IsDefault, now, now)
		if err != nil {
			return fmt.Errorf("写入回顾预设失败: %w", err)
		}
		return nil
	})
}

// DeleteReviewPreset 删除预设；默认预设不允许删除。
func DeleteReviewPreset(id string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	res, err := db.W().ExecContext(ctx, `DELETE FROM ai_review_presets WHERE id = ? AND is_default = 0`, id)
	if err != nil {
		return fmt.Errorf("删除回顾预设失败: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return errors.New("预设不存在，或它是默认预设（不可删除）")
	}
	return nil
}

// EnsureReviewPresets 保证至少存在一个默认预设。
func EnsureReviewPresets() error {
	presets, err := ListReviewPresets()
	if err != nil {
		return err
	}
	if len(presets) > 0 {
		return nil
	}
	return UpsertReviewPreset(DefaultReviewPreset())
}

// CachedReview 缓存的回顾结果。
type CachedReview struct {
	Stats     string `json:"stats"`
	Narrative string `json:"narrative"`
	Model     string `json:"model"`
	PresetID  string `json:"preset_id"`
	CreatedAt string `json:"created_at"`
}

// GetCachedReview 取缓存；未命中返回 nil。
func GetCachedReview(kind, scopeKey, presetID, modelName string) (*CachedReview, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	var c CachedReview
	err := db.R().QueryRowContext(ctx, `
		SELECT stats, narrative, model, preset_id, created_at
		FROM ai_reviews
		WHERE kind = ? AND scope_key = ? AND preset_id = ? AND model = ?`,
		kind, scopeKey, presetID, modelName).
		Scan(&c.Stats, &c.Narrative, &c.Model, &c.PresetID, &c.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("查询回顾缓存失败: %w", err)
	}
	return &c, nil
}

// SaveReview 写入回顾缓存（同一指纹重复生成时覆盖旧结果）。
func SaveReview(kind, scopeKey, presetID, modelName, stats, narrative string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	_, err := db.W().ExecContext(ctx, `
		INSERT INTO ai_reviews (kind, scope_key, preset_id, model, stats, narrative, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (kind, scope_key, preset_id, model) DO UPDATE SET
			stats = excluded.stats, narrative = excluded.narrative, created_at = excluded.created_at`,
		kind, scopeKey, presetID, modelName, stats, narrative, model.Now())
	if err != nil {
		return fmt.Errorf("写入回顾缓存失败: %w", err)
	}
	return nil
}
