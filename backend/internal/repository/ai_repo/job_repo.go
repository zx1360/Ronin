package ai_repo

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// ClaimedJob 一次认领到的任务（任务 ID + 目标媒体）。
type ClaimedJob struct {
	JobID   int64
	MediaID uuid.UUID
}

// Enqueue 为指定媒体批量入队某能力（重复入队幂等，已存在的任务行不变）。
func Enqueue(capability string, mediaIDs []uuid.UUID) (int64, error) {
	if len(mediaIDs) == 0 {
		return 0, nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}

	tag, err := db.GetPool().Exec(ctx, `
		INSERT INTO ai.jobs (capability, media_id)
		SELECT $1, unnest($2::uuid[])
		ON CONFLICT (capability, media_id) DO NOTHING`, capability, mediaIDs)
	if err != nil {
		return 0, fmt.Errorf("入队 AI 任务失败: %w", err)
	}
	return tag.RowsAffected(), nil
}

// EnqueueMissing 为"尚无该能力任务行"的未删除媒体批量入队，最多 limit 条。
//
// 这是入库自动触发的唯一入口：定时 reconcile 调用它，插入时幂等，
// 因此媒体何时入库、以何种方式入库都不影响最终一致性。
func EnqueueMissing(capability string, limit int, priority int) (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}

	tag, err := db.GetPool().Exec(ctx, `
		INSERT INTO ai.jobs (capability, media_id, priority)
		SELECT $1, m.id, $3
		FROM gallery.media_assets m
		WHERE m.is_deleted = false
		  AND NOT EXISTS (
		      SELECT 1 FROM ai.jobs j WHERE j.capability = $1 AND j.media_id = m.id
		  )
		ORDER BY m.captured_at
		LIMIT $2
		ON CONFLICT (capability, media_id) DO NOTHING`, capability, limit, priority)
	if err != nil {
		return 0, fmt.Errorf("补充入队 AI 任务失败: %w", err)
	}
	return tag.RowsAffected(), nil
}

// Claim 原子认领至多 limit 条待处理任务（pending → running，attempts+1）。
func Claim(capability string, limit int) ([]ClaimedJob, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return nil, err
	}

	rows, err := db.GetPool().Query(ctx, `
		WITH picked AS (
			SELECT id FROM ai.jobs
			WHERE capability = $1 AND status = 'pending'
			ORDER BY priority, id
			LIMIT $2
			FOR UPDATE SKIP LOCKED
		)
		UPDATE ai.jobs j
		SET status = 'running', attempts = j.attempts + 1, started_at = NOW(), last_error = NULL
		FROM picked
		WHERE j.id = picked.id
		RETURNING j.id, j.media_id`, capability, limit)
	if err != nil {
		return nil, fmt.Errorf("认领 AI 任务失败: %w", err)
	}
	defer rows.Close()

	var claimed []ClaimedJob
	for rows.Next() {
		var item ClaimedJob
		if err := rows.Scan(&item.JobID, &item.MediaID); err != nil {
			return nil, fmt.Errorf("扫描认领结果失败: %w", err)
		}
		claimed = append(claimed, item)
	}
	return claimed, rows.Err()
}

// FinishDone 标记任务成功完成。
func FinishDone(jobIDs []int64) error {
	if len(jobIDs) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.GetPool().Exec(ctx, `
		UPDATE ai.jobs SET status = 'done', finished_at = NOW(), last_error = NULL
		WHERE id = ANY($1)`, jobIDs)
	if err != nil {
		return fmt.Errorf("更新任务完成状态失败: %w", err)
	}
	return nil
}

// FinishFailed 记录失败；未超过 maxAttempts 时退回 pending 等待重试，否则置为 failed。
func FinishFailed(jobIDs []int64, errMsg string, maxAttempts int) error {
	if len(jobIDs) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.GetPool().Exec(ctx, `
		UPDATE ai.jobs
		SET last_error = $2,
		    status = CASE WHEN attempts < $3 THEN 'pending' ELSE 'failed' END,
		    started_at = CASE WHEN attempts < $3 THEN NULL ELSE started_at END,
		    finished_at = CASE WHEN attempts < $3 THEN NULL ELSE NOW() END
		WHERE id = ANY($1)`, jobIDs, truncate(errMsg, 1000), maxAttempts)
	if err != nil {
		return fmt.Errorf("更新任务失败状态失败: %w", err)
	}
	return nil
}

// ReleaseRunning 把 running 退回 pending（中断/停机时使用，不计失败）。
func ReleaseRunning(jobIDs []int64) error {
	if len(jobIDs) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.GetPool().Exec(ctx, `
		UPDATE ai.jobs SET status = 'pending', started_at = NULL
		WHERE id = ANY($1) AND status = 'running'`, jobIDs)
	if err != nil {
		return fmt.Errorf("释放任务失败: %w", err)
	}
	return nil
}

// RecoverStaleRunning 回收超过 staleAfter 仍处于 running 的任务（进程崩溃后的孤儿）。
func RecoverStaleRunning(staleAfter time.Duration, maxAttempts int) (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}
	tag, err := db.GetPool().Exec(ctx, `
		UPDATE ai.jobs
		SET status = CASE WHEN attempts < $2 THEN 'pending' ELSE 'failed' END,
		    started_at = NULL,
		    last_error = COALESCE(last_error, '进程中断，任务已回收')
		WHERE status = 'running' AND started_at < NOW() - $1::interval`,
		fmt.Sprintf("%d seconds", int(staleAfter.Seconds())), maxAttempts)
	if err != nil {
		return 0, fmt.Errorf("回收孤儿任务失败: %w", err)
	}
	return tag.RowsAffected(), nil
}

// RetryFailed 把失败任务重置为待处理（attempts 归零）；mediaIDs 为空表示全部。
func RetryFailed(capability string, mediaIDs []uuid.UUID) (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}

	sql := `UPDATE ai.jobs SET status = 'pending', attempts = 0, last_error = NULL, started_at = NULL, finished_at = NULL
	        WHERE status = 'failed'`
	args := []any{}
	if capability != "" {
		args = append(args, capability)
		sql += fmt.Sprintf(" AND capability = $%d", len(args))
	}
	if len(mediaIDs) > 0 {
		args = append(args, mediaIDs)
		sql += fmt.Sprintf(" AND media_id = ANY($%d)", len(args))
	}

	tag, err := db.GetPool().Exec(ctx, sql, args...)
	if err != nil {
		return 0, fmt.Errorf("重试失败任务失败: %w", err)
	}
	return tag.RowsAffected(), nil
}

// Stats 返回各能力的队列计数（按 model.AllCapabilities 顺序补齐缺失项）。
func Stats() ([]model.AiCapabilityStat, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	byCap := map[string]*model.AiCapabilityStat{}
	for _, c := range model.AllCapabilities {
		byCap[c] = &model.AiCapabilityStat{Capability: c}
	}

	if err := ensureSchema(ctx); err != nil {
		return nil, err
	}

	rows, err := db.GetPool().Query(ctx, `
		SELECT capability,
		       COUNT(*) FILTER (WHERE status = 'pending'),
		       COUNT(*) FILTER (WHERE status = 'running'),
		       COUNT(*) FILTER (WHERE status = 'done'),
		       COUNT(*) FILTER (WHERE status = 'failed'),
		       COUNT(*)
		FROM ai.jobs GROUP BY capability`)
	if err != nil {
		return nil, fmt.Errorf("统计任务队列失败: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var stat model.AiCapabilityStat
		if err := rows.Scan(&stat.Capability, &stat.Pending, &stat.Running,
			&stat.Done, &stat.Failed, &stat.Total); err != nil {
			return nil, fmt.Errorf("扫描队列统计失败: %w", err)
		}
		if target, ok := byCap[stat.Capability]; ok {
			*target = stat
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	stats := make([]model.AiCapabilityStat, 0, len(model.AllCapabilities))
	for _, c := range model.AllCapabilities {
		stats = append(stats, *byCap[c])
	}
	return stats, nil
}

// ListJobs 查询任务列表（capability/status 为空表示不过滤）。
func ListJobs(capability, status string, limit, offset int) ([]model.AiJob, int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	where := "TRUE"
	args := []any{}
	if capability != "" {
		args = append(args, capability)
		where += fmt.Sprintf(" AND capability = $%d", len(args))
	}
	if status != "" {
		args = append(args, status)
		where += fmt.Sprintf(" AND status = $%d", len(args))
	}

	var total int
	if err := db.GetPool().QueryRow(ctx,
		"SELECT COUNT(*) FROM ai.jobs WHERE "+where, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("统计任务失败: %w", err)
	}

	query := fmt.Sprintf(`
		SELECT id, capability, media_id, status, priority, attempts, last_error,
		       started_at, finished_at, created_at, updated_at
		FROM ai.jobs WHERE %s
		ORDER BY updated_at DESC, id DESC
		LIMIT $%d OFFSET $%d`, where, len(args)+1, len(args)+2)

	rows, err := db.GetPool().Query(ctx, query, append(args, limit, offset)...)
	if err != nil {
		return nil, 0, fmt.Errorf("查询任务失败: %w", err)
	}
	defer rows.Close()

	jobs := []model.AiJob{}
	for rows.Next() {
		var job model.AiJob
		if err := rows.Scan(&job.ID, &job.Capability, &job.MediaID, &job.Status,
			&job.Priority, &job.Attempts, &job.LastError, &job.StartedAt,
			&job.FinishedAt, &job.CreatedAt, &job.UpdatedAt); err != nil {
			return nil, 0, fmt.Errorf("扫描任务行失败: %w", err)
		}
		jobs = append(jobs, job)
	}
	return jobs, total, rows.Err()
}

// PendingCount 返回能力维度待处理任务数（0 表示已排空）。
func PendingCount(capability string) (int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	var n int
	err := db.GetPool().QueryRow(ctx, `
		SELECT COUNT(*) FROM ai.jobs WHERE capability = $1 AND status IN ('pending','running')`,
		capability).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("统计待处理任务失败: %w", err)
	}
	return n, nil
}

// AutoCapabilities 读取运行时设置中的"入库自动入队能力"。
func AutoCapabilities(fallback []string) []string {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return fallback
	}
	var raw string
	if err := db.GetPool().QueryRow(ctx,
		`SELECT value FROM ai.settings WHERE key = 'auto_capabilities'`).Scan(&raw); err != nil {
		return fallback
	}
	var caps []string
	for _, part := range SplitAndTrim(raw) {
		if model.IsValidCapability(part) {
			caps = append(caps, part)
		}
	}
	return caps
}

// SetAutoCapabilities 持久化"入库自动入队能力"。
func SetAutoCapabilities(caps []string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return err
	}
	joined := joinCSV(caps)
	_, err := db.GetPool().Exec(ctx, `
		INSERT INTO ai.settings (key, value) VALUES ('auto_capabilities', $1)
		ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, joined)
	if err != nil {
		return fmt.Errorf("保存自动处理能力失败: %w", err)
	}
	return nil
}

// VLMModel 返回运行时的 VLM 模型选择（未设置时返回空串，由调用方回落到配置默认值）。
func VLMModel() string {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	if !SchemaReady(ctx) {
		return ""
	}
	var value string
	if err := db.GetPool().QueryRow(ctx,
		`SELECT value FROM ai.settings WHERE key = 'ollama_vlm_model'`).Scan(&value); err != nil {
		return ""
	}
	return strings.TrimSpace(value)
}

// SetVLMModel 持久化 VLM 模型选择；model 为空表示恢复 .env 默认值。
func SetVLMModel(model string) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return err
	}
	model = strings.TrimSpace(model)
	if model == "" {
		if _, err := db.GetPool().Exec(ctx,
			`DELETE FROM ai.settings WHERE key = 'ollama_vlm_model'`); err != nil {
			return fmt.Errorf("清除模型设置失败: %w", err)
		}
		return nil
	}
	_, err := db.GetPool().Exec(ctx, `
		INSERT INTO ai.settings (key, value) VALUES ('ollama_vlm_model', $1)
		ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, model)
	if err != nil {
		return fmt.Errorf("保存模型设置失败: %w", err)
	}
	return nil
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max]
}
