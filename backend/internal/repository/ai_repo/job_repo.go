package ai_repo

import (
	"context"
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
//
// inputSig 为空表示调用方不声明输入档位/执行者（这类任务不参与自动重排判断）。
func Enqueue(capability string, mediaIDs []uuid.UUID, inputSig string) (int64, error) {
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
			args := make([]any, 0, len(chunk)*3)
			for _, id := range chunk {
				values = append(values, "(?, ?, ?)")
				args = append(args, capability, id, inputSig)
			}
			res, err := tx.ExecContext(ctx,
				`INSERT INTO jobs (capability, media_id, input_sig) VALUES `+strings.Join(values, ", ")+
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
func EnqueueMissing(capability string, limit int, priority int, inputSig string) (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}

	res, err := db.Exec(ctx, `
		INSERT INTO jobs (capability, media_id, priority, input_sig)
		SELECT ?, m.id, ?, ?
		FROM media_assets m
		WHERE m.is_deleted = 0
		  AND NOT EXISTS (
		      SELECT 1 FROM jobs j WHERE j.capability = ? AND j.media_id = m.id
		  )
		ORDER BY m.captured_at
		LIMIT ?
		ON CONFLICT (capability, media_id) DO NOTHING`, capability, priority, inputSig, capability, limit)
	if err != nil {
		return 0, fmt.Errorf("补充入队 AI 任务失败: %w", err)
	}
	n, _ := res.RowsAffected()
	return n, nil
}

// ResetStaleInput 把"输入档位/执行者已变"的旧产物重新排队。
//
// 只处理已完成/已失败的任务行：pending/running 的行本来就会用最新签名重算。
// 旧版本留下的空签名（input_sig IS NULL）不算不匹配——那会让升级后的第一次
// reconcile 把全库 28 万条任务一次性重排，代价不可接受；这类历史数据只能由
// 用户显式"全量重生成"来刷新。
func ResetStaleInput(capability, inputSig string) (int64, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}
	res, err := db.Exec(ctx, `
		UPDATE jobs
		SET status = 'pending', attempts = 0, last_error = NULL,
		    started_at = NULL, finished_at = NULL, input_sig = ?
		WHERE capability = ? AND status IN ('done', 'failed')
		  AND input_sig IS NOT NULL AND input_sig <> ?`, inputSig, capability, inputSig)
	if err != nil {
		return 0, fmt.Errorf("重排旧产物失败: %w", err)
	}
	n, _ := res.RowsAffected()
	return n, nil
}

// CountStaleInput 统计该能力下输入档位/执行者已变、待重排的任务数。
func CountStaleInput(capability, inputSig string) (int, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}
	var n int
	err := db.Read().QueryRowContext(ctx, `
		SELECT COUNT(*) FROM jobs
		WHERE capability = ? AND status IN ('done', 'failed')
		  AND input_sig IS NOT NULL AND input_sig <> ?`, capability, inputSig).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("统计待重排任务失败: %w", err)
	}
	return n, nil
}

// Regenerate 全量重生成某能力：先清掉该能力的既有产物，再把全部未删除媒体排队重算。
//
// 这是显式的破坏性操作（调用方必须二次确认）：清产物期间该能力的检索/筛选结果为空，
// 但换向量模型、换 VLM 模型或需要彻底重算时，这是唯一能让结果干净的路径。
// 只影响指定能力，其它能力的产物不受任何影响。
func Regenerate(capability string, inputSig string, priority int) (cleared int64, enqueued int64, err error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, 0, err
	}

	err = db.Tx(ctx, func(tx *sql.Tx) error {
		var clearErr error
		if cleared, clearErr = clearCapabilityResults(ctx, tx, capability); clearErr != nil {
			return clearErr
		}
		// 任务行全部回到待处理：已存在的行不会因 INSERT 而更新，需显式重置
		if _, err := tx.ExecContext(ctx, `
			UPDATE jobs
			SET status = 'pending', attempts = 0, last_error = NULL,
			    started_at = NULL, finished_at = NULL, input_sig = ?
			WHERE capability = ?`, inputSig, capability); err != nil {
			return fmt.Errorf("重置任务状态失败: %w", err)
		}
		// 为"尚无任务行"的媒体补行；已有的行上一步已重置
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO jobs (capability, media_id, priority, input_sig)
			SELECT ?, m.id, ?, ?
			FROM media_assets m
			WHERE m.is_deleted = 0
			  AND NOT EXISTS (
			      SELECT 1 FROM jobs j WHERE j.capability = ? AND j.media_id = m.id
			  )
			ON CONFLICT (capability, media_id) DO NOTHING`,
			capability, priority, inputSig, capability); err != nil {
			return fmt.Errorf("全量入队失败: %w", err)
		}
		// 任务总数 = 重置的行数 + 新增的行数
		var total int64
		if err := tx.QueryRowContext(ctx,
			`SELECT COUNT(*) FROM jobs WHERE capability = ?`, capability).Scan(&total); err != nil {
			return fmt.Errorf("统计重生成任务失败: %w", err)
		}
		enqueued = total
		return nil
	})
	return cleared, enqueued, err
}

// RegenerateMedia 只对指定媒体重新入队（批量重算的轻量入口，不清全库产物）。
//
// 任务行会被重置为待处理并写入最新签名；尚无任务行的媒体补一行。
func RegenerateMedia(capability string, mediaIDs []uuid.UUID, inputSig string) (int64, error) {
	if len(mediaIDs) == 0 {
		return 0, nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	if err := ensureSchema(ctx); err != nil {
		return 0, err
	}

	var affected int64
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx, `
			UPDATE jobs
			SET status = 'pending', attempts = 0, last_error = NULL,
			    started_at = NULL, finished_at = NULL, input_sig = ?
			WHERE capability = ? AND media_id IN (`+placeholders(len(mediaIDs))+`)`,
			append([]any{inputSig, capability}, uuidArgs(mediaIDs)...)...)
		if err != nil {
			return fmt.Errorf("重置指定媒体任务失败: %w", err)
		}
		affected, _ = res.RowsAffected()

		values := make([]string, 0, len(mediaIDs))
		args := make([]any, 0, len(mediaIDs)*3)
		for _, id := range mediaIDs {
			values = append(values, "(?, ?, ?)")
			args = append(args, capability, id, inputSig)
		}
		res, err = tx.ExecContext(ctx,
			`INSERT INTO jobs (capability, media_id, input_sig) VALUES `+strings.Join(values, ", ")+
				` ON CONFLICT (capability, media_id) DO NOTHING`, args...)
		if err != nil {
			return fmt.Errorf("入队 AI 任务失败: %w", err)
		}
		inserted, _ := res.RowsAffected()
		affected += inserted
		return nil
	})
	return affected, err
}

// clearCapabilityResults 清除某能力的既有产物（只动该能力自己的列/表）。
func clearCapabilityResults(ctx context.Context, tx *sql.Tx, capability string) (int64, error) {
	switch capability {
	case model.CapPHash:
		res, err := tx.ExecContext(ctx,
			`UPDATE media_ai SET phash = NULL, phash_input_sig = NULL WHERE phash IS NOT NULL`)
		return rowsAffected(res, err, "清除感知哈希失败")
	case model.CapOCR:
		res, err := tx.ExecContext(ctx,
			`UPDATE media_ai SET ocr_text = NULL, ocr_input_sig = NULL WHERE ocr_text IS NOT NULL`)
		return rowsAffected(res, err, "清除 OCR 结果失败")
	case model.CapVLM:
		res, err := tx.ExecContext(ctx,
			`UPDATE media_ai SET caption = NULL, caption_input_sig = NULL WHERE caption IS NOT NULL`)
		if err != nil {
			return 0, fmt.Errorf("清除 VLM 结果失败: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM media_ai_tags`); err != nil {
			return 0, fmt.Errorf("清除 AI 标签失败: %w", err)
		}
		return rowsAffected(res, nil, "")
	case model.CapEmbed:
		res, err := tx.ExecContext(ctx, `DELETE FROM embeddings`)
		return rowsAffected(res, err, "清除图像向量失败")
	case model.CapFace:
		// 人脸清空后人物分组必然为空，一并清掉避免留下无法解释的空分组
		res, err := tx.ExecContext(ctx, `DELETE FROM faces`)
		if err != nil {
			return 0, fmt.Errorf("清除人脸失败: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM persons`); err != nil {
			return 0, fmt.Errorf("清除人物分组失败: %w", err)
		}
		return rowsAffected(res, nil, "")
	default:
		return 0, fmt.Errorf("未知能力: %s", capability)
	}
}

// rowsAffected 统一处理 Exec 结果与错误。
func rowsAffected(res sql.Result, err error, message string) (int64, error) {
	if err != nil {
		return 0, fmt.Errorf("%s: %w", message, err)
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

// FinishDone 标记任务成功完成，并记录本次使用的输入档位/执行者指纹。
func FinishDone(jobIDs []int64, inputSig string) error {
	if len(jobIDs) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.Exec(ctx, `
		UPDATE jobs
		SET status = 'done', finished_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'),
		    last_error = NULL, input_sig = ?
		WHERE id IN (`+placeholders(len(jobIDs))+`)`, append([]any{inputSig}, int64Args(jobIDs)...)...)
	if err != nil {
		return fmt.Errorf("更新任务完成状态失败: %w", err)
	}
	return nil
}

// FinishFailed 记录失败；未超过 maxAttempts 时退回 pending 等待重试，否则置为 failed。
//
// 同时写入本次的 input_sig：失败的任务同样"已经用当前档位/执行者尝试过"，
// 否则它会被自动重排逻辑反复识别为指纹不匹配而无限重排（永不收敛）。
func FinishFailed(jobIDs []int64, errMsg string, maxAttempts int, inputSig string) error {
	if len(jobIDs) == 0 {
		return nil
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	_, err := db.Exec(ctx, `
		UPDATE jobs
		SET last_error = ?,
		    input_sig = ?,
		    status = CASE WHEN attempts < ? THEN 'pending' ELSE 'failed' END,
		    started_at = CASE WHEN attempts < ? THEN NULL ELSE started_at END,
		    finished_at = CASE WHEN attempts < ?
		                       THEN NULL
		                       ELSE strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') END
		WHERE id IN (`+placeholders(len(jobIDs))+`)`,
		append([]any{truncate(errMsg, 1000), inputSig, maxAttempts, maxAttempts, maxAttempts},
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
		       input_sig, started_at, finished_at, created_at, updated_at
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
			&job.Priority, &job.Attempts, &job.LastError, &job.InputSig, &job.StartedAt,
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

// LegacyAutoCapabilities 读取旧版存放在 settings 表里的"入库自动入队能力"。
//
// 配置已迁到 STATIC_DIR/data/ai_config.json（见 config.ConfigStore）；这里只在
// 首次生成该文件时把旧值搬过去一次，之后不再读写。
func LegacyAutoCapabilities() ([]string, bool) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	if !SchemaReady(ctx) {
		return nil, false
	}
	var raw string
	if err := db.Read().QueryRowContext(ctx,
		`SELECT value FROM settings WHERE key = 'auto_capabilities'`).Scan(&raw); err != nil {
		return nil, false
	}
	var caps []string
	for _, part := range SplitAndTrim(raw) {
		if model.IsValidCapability(part) {
			caps = append(caps, part)
		}
	}
	return caps, true
}

// LegacyVLMModel 读取旧版存放在 settings 表里的 VLM 模型选择（同上，仅迁移用一次）。
func LegacyVLMModel() (string, bool) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	if !SchemaReady(ctx) {
		return "", false
	}
	var value string
	if err := db.Read().QueryRowContext(ctx,
		`SELECT value FROM settings WHERE key = 'ollama_vlm_model'`).Scan(&value); err != nil {
		return "", false
	}
	return strings.TrimSpace(value), true
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
