package ai_repo

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"monarch/internal/dbutil"
	"monarch/internal/model"
	"monarch/internal/service/db"
)

// 单条 INSERT 内联的最大元组数：避免大列表触发 SQLite 的参数上限。
const insertChunk = 200

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
		for start := 0; start < len(mediaIDs); start += insertChunk {
			end := start + insertChunk
			if end > len(mediaIDs) {
				end = len(mediaIDs)
			}
			chunk := mediaIDs[start:end]
			values := make([]string, 0, len(chunk))
			args := make([]any, 0, len(chunk)*2)
			for _, id := range chunk {
				values = append(values, "(?, ?)")
				args = append(args, capability, id)
			}
			res, err := tx.ExecContext(ctx,
				`INSERT INTO jobs (capability, media_id) VALUES `+strings.Join(values, ", ")+
					` ON CONFLICT (capability, media_id) DO NOTHING`, args...)
			if err != nil {
				return fmt.Errorf("入队 AI 任务失败: %w", err)
			}
			n, _ := res.RowsAffected()
			inserted += n
		}
		return nil
	})
	return inserted, err
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

	res, err := db.Exec(ctx, `
		INSERT INTO jobs (capability, media_id, priority)
		SELECT ?, m.id, ?
		FROM media_assets m
		WHERE m.is_deleted = 0
		  AND NOT EXISTS (
		      SELECT 1 FROM jobs j WHERE j.capability = ? AND j.media_id = m.id
		  )
		ORDER BY m.captured_at
		LIMIT ?
		ON CONFLICT (capability, media_id) DO NOTHING`, capability, priority, capability, limit)
	if err != nil {
		return 0, fmt.Errorf("补充入队 AI 任务失败: %w", err)
	}
	n, _ := res.RowsAffected()
	return n, nil
}

// Claim 原子认领至多 limit 条待处理任务（pending → running，attempts+1）。
//
// 单写者模型下进程内不存在竞争（写连接唯一），跨进程也不会有第二个 AI worker，
// 因此用一条 UPDATE ... RETURNING 完成"挑选 + 置位"，无需 PG 的 SKIP LOCKED。
func Claim(capability string, limit int) ([]ClaimedJob, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return nil, err
	}

	claimed := []ClaimedJob{}
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		claimed = claimed[:0]
		rows, err := tx.QueryContext(ctx, `
			UPDATE jobs
			SET status = 'running', attempts = attempts + 1,
			    started_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'), last_error = NULL
			WHERE id IN (
				SELECT id FROM jobs
				WHERE capability = ? AND status = 'pending'
				ORDER BY priority, id
				LIMIT ?
			)
			RETURNING id, media_id`, capability, limit)
		if err != nil {
			return fmt.Errorf("认领 AI 任务失败: %w", err)
		}
		defer rows.Close()
		for rows.Next() {
			var item ClaimedJob
			if err := rows.Scan(&item.JobID, &item.MediaID); err != nil {
				return fmt.Errorf("扫描认领结果失败: %w", err)
			}
			claimed = append(claimed, item)
		}
		return rows.Err()
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
	_, err := db.Exec(ctx, `
		UPDATE jobs
		SET status = 'done', finished_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'), last_error = NULL
		WHERE id IN (`+placeholders(len(jobIDs))+`)`, int64Args(jobIDs)...)
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
	_, err := db.Exec(ctx, `
		UPDATE jobs
		SET last_error = ?,
		    status = CASE WHEN attempts < ? THEN 'pending' ELSE 'failed' END,
		    started_at = CASE WHEN attempts < ? THEN NULL ELSE started_at END,
		    finished_at = CASE WHEN attempts < ?
		                       THEN NULL
		                       ELSE strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') END
		WHERE id IN (`+placeholders(len(jobIDs))+`)`,
		append([]any{truncate(errMsg, 1000), maxAttempts, maxAttempts, maxAttempts},
			int64Args(jobIDs)...)...)
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
	_, err := db.Exec(ctx, `
		UPDATE jobs SET status = 'pending', started_at = NULL
		WHERE status = 'running' AND id IN (`+placeholders(len(jobIDs))+`)`, int64Args(jobIDs)...)
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
	cutoff := dbutil.TS(time.Now().Add(-staleAfter))
	res, err := db.Exec(ctx, `
		UPDATE jobs
		SET status = CASE WHEN attempts < ? THEN 'pending' ELSE 'failed' END,
		    started_at = NULL,
		    last_error = COALESCE(last_error, '进程中断，任务已回收')
		WHERE status = 'running' AND started_at < ?`, maxAttempts, cutoff)
	if err != nil {
		return 0, fmt.Errorf("回收孤儿任务失败: %w", err)
	}
	n, _ := res.RowsAffected()
	return n, nil
}

// RetryFailed 把失败任务重置为待处理（attempts 归零）；mediaIDs 为空表示全部。
func RetryFailed(capability string, mediaIDs []uuid.UUID) (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}

	query := `UPDATE jobs SET status = 'pending', attempts = 0, last_error = NULL,
	          started_at = NULL, finished_at = NULL WHERE status = 'failed'`
	args := []any{}
	if capability != "" {
		query += " AND capability = ?"
		args = append(args, capability)
	}
	if len(mediaIDs) > 0 {
		query += " AND media_id IN (" + placeholders(len(mediaIDs)) + ")"
		args = append(args, uuidArgs(mediaIDs)...)
	}

	res, err := db.Exec(ctx, query, args...)
	if err != nil {
		return 0, fmt.Errorf("重试失败任务失败: %w", err)
	}
	n, _ := res.RowsAffected()
	return n, nil
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

	rows, err := db.Read().QueryContext(ctx, `
		SELECT capability,
		       COUNT(*) FILTER (WHERE status = 'pending'),
		       COUNT(*) FILTER (WHERE status = 'running'),
		       COUNT(*) FILTER (WHERE status = 'done'),
		       COUNT(*) FILTER (WHERE status = 'failed'),
		       COUNT(*)
		FROM jobs GROUP BY capability`)
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
		where += " AND capability = ?"
		args = append(args, capability)
	}
	if status != "" {
		where += " AND status = ?"
		args = append(args, status)
	}

	var total int
	if err := db.Read().QueryRowContext(ctx,
		"SELECT COUNT(*) FROM jobs WHERE "+where, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("统计任务失败: %w", err)
	}

	query := fmt.Sprintf(`
		SELECT id, capability, media_id, status, priority, attempts, last_error,
		       started_at, finished_at, created_at, updated_at
		FROM jobs WHERE %s
		ORDER BY updated_at DESC, id DESC
		LIMIT ? OFFSET ?`, where)

	rows, err := db.Read().QueryContext(ctx, query, append(args, limit, offset)...)
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
	err := db.Read().QueryRowContext(ctx, `
		SELECT COUNT(*) FROM jobs WHERE capability = ? AND status IN ('pending','running')`,
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
	if err := db.Read().QueryRowContext(ctx,
		`SELECT value FROM settings WHERE key = 'auto_capabilities'`).Scan(&raw); err != nil {
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
	_, err := db.Exec(ctx, `
		INSERT INTO settings (key, value) VALUES ('auto_capabilities', ?)
		ON CONFLICT (key) DO UPDATE SET value = excluded.value`, joined)
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
	if err := db.Read().QueryRowContext(ctx,
		`SELECT value FROM settings WHERE key = 'ollama_vlm_model'`).Scan(&value); err != nil {
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
		if _, err := db.Exec(ctx,
			`DELETE FROM settings WHERE key = 'ollama_vlm_model'`); err != nil {
			return fmt.Errorf("清除模型设置失败: %w", err)
		}
		return nil
	}
	_, err := db.Exec(ctx, `
		INSERT INTO settings (key, value) VALUES ('ollama_vlm_model', ?)
		ON CONFLICT (key) DO UPDATE SET value = excluded.value`, model)
	if err != nil {
		return fmt.Errorf("保存模型设置失败: %w", err)
	}
	return nil
}

// int64Args 把 int64 列表转为 SQL 参数。
func int64Args(values []int64) []any {
	args := make([]any, len(values))
	for i, v := range values {
		args[i] = v
	}
	return args
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max]
}
