package ai_repo

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/service/db"
	"monarch/internal/settings"
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

	var inserted int64
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		inserted = 0
		now := model.Now()
		for _, mediaID := range mediaIDs {
			res, err := tx.ExecContext(ctx, `
				INSERT INTO ai_jobs (capability, media_id, created_at, updated_at)
				VALUES (?, ?, ?, ?)
				ON CONFLICT (capability, media_id) DO NOTHING`,
				capability, mediaID, now, now)
			if err != nil {
				return fmt.Errorf("入队 AI 任务失败: %w", err)
			}
			n, err := res.RowsAffected()
			if err != nil {
				return err
			}
			inserted += n
		}
		return nil
	})
	if err != nil {
		return 0, err
	}
	return inserted, nil
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

	now := model.Now()
	res, err := db.W().ExecContext(ctx, `
		INSERT INTO ai_jobs (capability, media_id, priority, created_at, updated_at)
		SELECT ?, m.id, ?, ?, ?
		FROM gallery_media_assets m
		WHERE m.is_deleted = 0
		  AND NOT EXISTS (
		      SELECT 1 FROM ai_jobs j WHERE j.capability = ? AND j.media_id = m.id
		  )
		ORDER BY m.captured_at
		LIMIT ?
		ON CONFLICT (capability, media_id) DO NOTHING`,
		capability, priority, now, now, capability, limit)
	if err != nil {
		return 0, fmt.Errorf("补充入队 AI 任务失败: %w", err)
	}
	return res.RowsAffected()
}

// EnqueueStale 把"结果规格已失配或尚无结果"的媒体重新入队（能力实现或输入档位变更后自动重排）。
//
// 重置条件刻意分成两半：
//   - done 的任务无条件重排——调用方只会传入"缺结果或结果规格不符"的媒体，所以这里
//     也覆盖了"任务标记完成却没有溯源记录"的历史行，否则它们会永远不再被处理。
//   - failed 的任务只在结果确实存在且规格不符、且尚未耗尽重试次数时重排，
//     避免把永久失败的媒体无限复活。
func EnqueueStale(capability, tier, executor string, mediaIDs []uuid.UUID, priority, maxAttempts int) (int64, error) {
	if len(mediaIDs) == 0 {
		return 0, nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}

	const staleResult = `EXISTS (
		SELECT 1 FROM ai_results r
		WHERE r.media_id = ai_jobs.media_id
		  AND r.capability = ai_jobs.capability
		  AND (r.input_tier <> ? OR r.executor <> ?)
	)`
	const missingResult = `NOT EXISTS (
		SELECT 1 FROM ai_results r
		WHERE r.media_id = ai_jobs.media_id
		  AND r.capability = ai_jobs.capability
	)`

	var changed int64
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		changed = 0
		now := model.Now()
		for _, mediaID := range mediaIDs {
			res, err := tx.ExecContext(ctx, `
				INSERT INTO ai_jobs (capability, media_id, priority, created_at, updated_at)
				VALUES (?, ?, ?, ?, ?)
				ON CONFLICT (capability, media_id) DO UPDATE SET
					status = 'pending', priority = excluded.priority, attempts = 0,
					last_error = NULL, started_at = NULL, finished_at = NULL,
					updated_at = excluded.updated_at
				WHERE (ai_jobs.status = 'done'
				       OR (ai_jobs.status = 'failed' AND ai_jobs.attempts < ?))
				  AND (`+staleResult+` OR `+missingResult+`)`,
				capability, mediaID, priority, now, now, maxAttempts, tier, executor)
			if err != nil {
				return fmt.Errorf("重排 AI 任务失败: %w", err)
			}
			n, err := res.RowsAffected()
			if err != nil {
				return err
			}
			changed += n
		}
		return nil
	})
	if err != nil {
		return 0, err
	}
	return changed, nil
}

// Claim 原子认领至多 limit 条待处理任务（pending → running，attempts+1）。
//
// 写池只有一条连接，认领在进程内天然串行，因此不需要 PostgreSQL 的 FOR UPDATE SKIP LOCKED。
func Claim(capability string, limit int) ([]ClaimedJob, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return nil, err
	}

	var claimed []ClaimedJob
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		claimed = nil
		rows, err := tx.QueryContext(ctx, `
			SELECT id, media_id FROM ai_jobs
			WHERE capability = ? AND status = 'pending'
			ORDER BY priority, id
			LIMIT ?`, capability, limit)
		if err != nil {
			return fmt.Errorf("筛选待处理任务失败: %w", err)
		}
		for rows.Next() {
			var item ClaimedJob
			if err := rows.Scan(&item.JobID, &item.MediaID); err != nil {
				rows.Close()
				return fmt.Errorf("扫描认领结果失败: %w", err)
			}
			claimed = append(claimed, item)
		}
		if err := rows.Err(); err != nil {
			rows.Close()
			return err
		}
		rows.Close()
		if len(claimed) == 0 {
			return nil
		}

		now := model.Now()
		for _, job := range claimed {
			if _, err := tx.ExecContext(ctx, `
				UPDATE ai_jobs
				SET status = 'running', attempts = attempts + 1,
				    started_at = ?, last_error = NULL, updated_at = ?
				WHERE id = ?`, now, now, job.JobID); err != nil {
				return fmt.Errorf("认领 AI 任务失败: %w", err)
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return claimed, nil
}

// FinishDone 标记任务成功完成。
func FinishDone(jobIDs []int64) error {
	if len(jobIDs) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	now := model.Now()
	args := append([]any{now, now}, anyArgs(jobIDs)...)
	_, err := db.W().ExecContext(ctx, `
		UPDATE ai_jobs SET status = 'done', finished_at = ?, last_error = NULL, updated_at = ?
		WHERE id IN (`+placeholders(len(jobIDs))+`)`, args...)
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
	now := model.Now()
	args := append([]any{truncate(errMsg, 1000), maxAttempts, maxAttempts, maxAttempts, now, now},
		anyArgs(jobIDs)...)
	_, err := db.W().ExecContext(ctx, `
		UPDATE ai_jobs
		SET last_error = ?,
		    status = CASE WHEN attempts < ? THEN 'pending' ELSE 'failed' END,
		    started_at = CASE WHEN attempts < ? THEN NULL ELSE started_at END,
		    finished_at = CASE WHEN attempts < ? THEN NULL ELSE ? END,
		    updated_at = ?
		WHERE id IN (`+placeholders(len(jobIDs))+`)`, args...)
	if err != nil {
		return fmt.Errorf("更新任务失败状态失败: %w", err)
	}
	return nil
}

// ReleaseRunning 把 running 退回 pending（中断/停机时使用，不计失败）。
//
// 认领时 attempts 已经 +1，这里要把它退回去：中断是用户主动行为，若照旧计数，
// 反复暂停/继续会悄悄吃掉重试预算，让真正失败的媒体提前被判为永久失败。
func ReleaseRunning(jobIDs []int64) error {
	if len(jobIDs) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	args := append([]any{model.Now()}, anyArgs(jobIDs)...)
	_, err := db.W().ExecContext(ctx, `
		UPDATE ai_jobs
		SET status = 'pending',
		    started_at = NULL,
		    attempts = CASE WHEN attempts > 0 THEN attempts - 1 ELSE 0 END,
		    updated_at = ?
		WHERE id IN (`+placeholders(len(jobIDs))+`) AND status = 'running'`, args...)
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
	cutoff := model.FormatTime(time.Now().Add(-staleAfter))
	res, err := db.W().ExecContext(ctx, `
		UPDATE ai_jobs
		SET status = CASE WHEN attempts < ? THEN 'pending' ELSE 'failed' END,
		    started_at = NULL,
		    last_error = COALESCE(last_error, '进程中断，任务已回收'),
		    updated_at = ?
		WHERE status = 'running' AND started_at < ?`,
		maxAttempts, model.Now(), cutoff)
	if err != nil {
		return 0, fmt.Errorf("回收孤儿任务失败: %w", err)
	}
	return res.RowsAffected()
}

// RetryFailed 把失败任务重置为待处理（attempts 归零）；mediaIDs 为空表示全部。
func RetryFailed(capability string, mediaIDs []uuid.UUID) (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}

	query := `UPDATE ai_jobs
	          SET status = 'pending', attempts = 0, last_error = NULL,
	              started_at = NULL, finished_at = NULL, updated_at = ?
	          WHERE status = 'failed'`
	args := []any{model.Now()}
	if capability != "" {
		args = append(args, capability)
		query += " AND capability = ?"
	}
	if len(mediaIDs) > 0 {
		args = append(args, anyArgs(mediaIDs)...)
		query += " AND media_id IN (" + placeholders(len(mediaIDs)) + ")"
	}

	res, err := db.W().ExecContext(ctx, query, args...)
	if err != nil {
		return 0, fmt.Errorf("重试失败任务失败: %w", err)
	}
	return res.RowsAffected()
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

	rows, err := db.R().QueryContext(ctx, `
		SELECT capability,
		       SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END),
		       SUM(CASE WHEN status = 'running' THEN 1 ELSE 0 END),
		       SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END),
		       SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END),
		       COUNT(*)
		FROM ai_jobs GROUP BY capability`)
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

	where := "1=1"
	args := []any{}
	if capability != "" {
		args = append(args, capability)
		where += " AND capability = ?"
	}
	if status != "" {
		args = append(args, status)
		where += " AND status = ?"
	}

	var total int
	if err := db.R().QueryRowContext(ctx,
		`SELECT COUNT(*) FROM ai_jobs WHERE `+where, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("统计任务失败: %w", err)
	}

	query := `
		SELECT id, capability, media_id, status, priority, attempts, last_error,
		       started_at, finished_at, created_at, updated_at
		FROM ai_jobs WHERE ` + where + `
		ORDER BY updated_at DESC, id DESC
		LIMIT ? OFFSET ?`

	rows, err := db.R().QueryContext(ctx, query, append(args, limit, offset)...)
	if err != nil {
		return nil, 0, fmt.Errorf("查询任务失败: %w", err)
	}
	defer rows.Close()

	jobs := []model.AiJob{}
	for rows.Next() {
		var job model.AiJob
		var started, finished sql.NullString
		var createdAt, updatedAt string
		if err := rows.Scan(&job.ID, &job.Capability, &job.MediaID, &job.Status,
			&job.Priority, &job.Attempts, &job.LastError, &started,
			&finished, &createdAt, &updatedAt); err != nil {
			return nil, 0, fmt.Errorf("扫描任务行失败: %w", err)
		}
		if job.StartedAt, err = parseNullableTime(started); err != nil {
			return nil, 0, err
		}
		if job.FinishedAt, err = parseNullableTime(finished); err != nil {
			return nil, 0, err
		}
		if job.CreatedAt, err = model.ParseTime(createdAt); err != nil {
			return nil, 0, fmt.Errorf("解析任务创建时间失败: %w", err)
		}
		if job.UpdatedAt, err = model.ParseTime(updatedAt); err != nil {
			return nil, 0, fmt.Errorf("解析任务更新时间失败: %w", err)
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
	err := db.R().QueryRowContext(ctx, `
		SELECT COUNT(*) FROM ai_jobs WHERE capability = ? AND status IN ('pending','running')`,
		capability).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("统计待处理任务失败: %w", err)
	}
	return n, nil
}

// AutoCapabilities 读取运行时设置中的"入库自动入队能力"。
//
// 配置表始终存在，未设置时 settings 返回该键的默认值；空串表示显式关闭自动入队，
// 因此不再回退到 fallback（参数保留只为兼容既有签名，仅作切片容量提示）。
func AutoCapabilities(fallback []string) []string {
	caps := make([]string, 0, len(fallback))
	for _, part := range settings.GetCSV("ai.auto_capabilities") {
		if model.IsValidCapability(part) {
			caps = append(caps, part)
		}
	}
	return caps
}

// VLMModel 返回运行时的 VLM 模型选择；空串表示未做覆盖，由调用方回落到配置默认值。
func VLMModel() string {
	return strings.TrimSpace(settings.Get("ai.vlm_model"))
}

// parseNullableTime 解析可空时间列（TEXT，格式见 model.TimeFormat）。
func parseNullableTime(v sql.NullString) (*time.Time, error) {
	if !v.Valid || strings.TrimSpace(v.String) == "" {
		return nil, nil
	}
	t, err := model.ParseTime(v.String)
	if err != nil {
		return nil, fmt.Errorf("解析任务时间失败: %w", err)
	}
	return &t, nil
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max]
}
