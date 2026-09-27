// Package data_repo 提供 user_data 表的读写：随笔(essay)与打卡(booklet)。
//
// 写入是"逐行合并"而非全量替换：客户端只提交发生变化的行，服务端在同一事务里按
// updated_at 做最后写入者胜出（更新的行整体覆盖，等值忽略，未提交的行保持不动，
// 因此两端可并发写入而互不抹除）；删除以 deleted_at 墓碑表达，更新的非墓碑行可复活。
// 读取包含墓碑行，客户端凭它删除本地副本。
package data_repo

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// ============================================================================
// 读取
// ============================================================================

// FetchAllEssayArticles 获取所有随笔（含墓碑行）
func FetchAllEssayArticles() ([]model.EssayArticle, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `
		SELECT id, date, word_count, content, imgs, labels, messages, mood, deleted_at, created_at, updated_at
		FROM user_data_essay_articles
		ORDER BY date DESC, id
	`)
	if err != nil {
		return nil, fmt.Errorf("查询随笔列表失败: %w", err)
	}
	defer rows.Close()

	var articles []model.EssayArticle
	for rows.Next() {
		var (
			a         model.EssayArticle
			date      model.FlexTime
			deletedAt model.FlexTime
			createdAt model.FlexTime
			updatedAt model.FlexTime
			messages  string
			imgs      string
			labels    string
		)
		if err := rows.Scan(
			&a.ID, &date, &a.WordCount, &a.Content,
			&imgs, &labels, &messages, &a.Mood,
			&deletedAt, &createdAt, &updatedAt,
		); err != nil {
			return nil, fmt.Errorf("扫描随笔行失败: %w", err)
		}
		if a.Imgs, err = decodeStringArray(imgs, "随笔图片列表"); err != nil {
			return nil, fmt.Errorf("随笔 %s: %w", a.ID, err)
		}
		if a.Labels, err = decodeStringArray(labels, "随笔标签列表"); err != nil {
			return nil, fmt.Errorf("随笔 %s: %w", a.ID, err)
		}
		a.Messages = rawJSON(messages, "[]")
		a.Date, a.DeletedAt, a.CreatedAt, a.UpdatedAt = date.Time(), tombstone(deletedAt), createdAt.Time(), updatedAt.Time()
		articles = append(articles, a)
	}
	return articles, rows.Err()
}

// FetchAllEssayLabels 获取所有随笔标签（含墓碑行）
func FetchAllEssayLabels() ([]model.EssayLabel, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `
		SELECT id, name, essay_count, deleted_at, created_at, updated_at
		FROM user_data_essay_labels
		ORDER BY essay_count DESC, name
	`)
	if err != nil {
		return nil, fmt.Errorf("查询标签列表失败: %w", err)
	}
	defer rows.Close()

	var labels []model.EssayLabel
	for rows.Next() {
		var (
			l         model.EssayLabel
			deletedAt model.FlexTime
			createdAt model.FlexTime
			updatedAt model.FlexTime
		)
		if err := rows.Scan(&l.ID, &l.Name, &l.EssayCount, &deletedAt, &createdAt, &updatedAt); err != nil {
			return nil, fmt.Errorf("扫描标签行失败: %w", err)
		}
		l.DeletedAt, l.CreatedAt, l.UpdatedAt = tombstone(deletedAt), createdAt.Time(), updatedAt.Time()
		labels = append(labels, l)
	}
	return labels, rows.Err()
}

// FetchAllEssayYearSummaries 获取所有年度汇总（含墓碑行）
func FetchAllEssayYearSummaries() ([]model.EssayYearSummary, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `
		SELECT year, essay_count, word_count, month_summaries, deleted_at, updated_at
		FROM user_data_essay_year_summaries
		ORDER BY year DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("查询年度汇总失败: %w", err)
	}
	defer rows.Close()

	var summaries []model.EssayYearSummary
	for rows.Next() {
		var (
			s              model.EssayYearSummary
			deletedAt      model.FlexTime
			updatedAt      model.FlexTime
			monthSummaries string
		)
		if err := rows.Scan(&s.Year, &s.EssayCount, &s.WordCount, &monthSummaries, &deletedAt, &updatedAt); err != nil {
			return nil, fmt.Errorf("扫描年度汇总行失败: %w", err)
		}
		s.MonthSummaries = rawJSON(monthSummaries, "[]")
		s.DeletedAt, s.UpdatedAt = tombstone(deletedAt), updatedAt.Time()
		summaries = append(summaries, s)
	}
	return summaries, rows.Err()
}

// FetchAllBookletStyles 获取所有打卡样式（含墓碑行）
func FetchAllBookletStyles() ([]model.BookletStyle, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `
		SELECT id, start_date, valid_check_in, fully_done, longest_streak, longest_fully_streak,
		       tasks, deleted_at, created_at, updated_at
		FROM user_data_booklet_styles
		ORDER BY start_date DESC, id
	`)
	if err != nil {
		return nil, fmt.Errorf("查询打卡样式列表失败: %w", err)
	}
	defer rows.Close()

	var styles []model.BookletStyle
	for rows.Next() {
		var (
			s         model.BookletStyle
			startDate model.FlexTime
			deletedAt model.FlexTime
			createdAt model.FlexTime
			updatedAt model.FlexTime
			tasks     string
		)
		if err := rows.Scan(
			&s.ID, &startDate, &s.ValidCheckIn, &s.FullyDone,
			&s.LongestStreak, &s.LongestFullyStreak, &tasks,
			&deletedAt, &createdAt, &updatedAt,
		); err != nil {
			return nil, fmt.Errorf("扫描打卡样式行失败: %w", err)
		}
		s.Tasks = rawJSON(tasks, "[]")
		s.StartDate, s.DeletedAt, s.CreatedAt, s.UpdatedAt = startDate.Time(), tombstone(deletedAt), createdAt.Time(), updatedAt.Time()
		styles = append(styles, s)
	}
	return styles, rows.Err()
}

// FetchAllBookletRecords 获取所有打卡记录（含墓碑行）
func FetchAllBookletRecords() ([]model.BookletRecord, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `
		SELECT id, style_id, date, message, task_completion, mood, deleted_at, created_at, updated_at
		FROM user_data_booklet_records
		ORDER BY date DESC, style_id
	`)
	if err != nil {
		return nil, fmt.Errorf("查询打卡记录列表失败: %w", err)
	}
	defer rows.Close()

	var records []model.BookletRecord
	for rows.Next() {
		var (
			r              model.BookletRecord
			date           model.FlexTime
			deletedAt      model.FlexTime
			createdAt      model.FlexTime
			updatedAt      model.FlexTime
			taskCompletion string
		)
		if err := rows.Scan(
			&r.ID, &r.StyleID, &date, &r.Message,
			&taskCompletion, &r.Mood,
			&deletedAt, &createdAt, &updatedAt,
		); err != nil {
			return nil, fmt.Errorf("扫描打卡记录行失败: %w", err)
		}
		r.TaskCompletion = rawJSON(taskCompletion, "{}")
		r.Date, r.DeletedAt, r.CreatedAt, r.UpdatedAt = date.Time(), tombstone(deletedAt), createdAt.Time(), updatedAt.Time()
		records = append(records, r)
	}
	return records, rows.Err()
}

// CollectEssayReferencedImages 收集随笔引用的图片文件名（仅文件名，不含路径）。
// 墓碑行不再持有引用，其图片由孤儿清理回收。
func CollectEssayReferencedImages() (map[string]bool, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `SELECT imgs FROM user_data_essay_articles WHERE deleted_at IS NULL`)
	if err != nil {
		return nil, fmt.Errorf("查询随笔图片引用失败: %w", err)
	}
	defer rows.Close()

	refs := make(map[string]bool)
	for rows.Next() {
		var raw string
		if err := rows.Scan(&raw); err != nil {
			return nil, fmt.Errorf("扫描图片列表失败: %w", err)
		}
		imgs, err := decodeStringArray(raw, "随笔图片列表")
		if err != nil {
			continue
		}
		for _, img := range imgs {
			if img != "" {
				refs[filepath.Base(img)] = true
			}
		}
	}
	return refs, rows.Err()
}

// CollectBookletReferencedImages 收集打卡任务引用的图片文件名。墓碑样式同样不持有引用。
func CollectBookletReferencedImages() (map[string]bool, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.R().QueryContext(ctx, `SELECT tasks FROM user_data_booklet_styles WHERE deleted_at IS NULL`)
	if err != nil {
		return nil, fmt.Errorf("查询打卡任务图片引用失败: %w", err)
	}
	defer rows.Close()

	refs := make(map[string]bool)
	for rows.Next() {
		var tasksJSON string
		if err := rows.Scan(&tasksJSON); err != nil {
			return nil, fmt.Errorf("扫描任务JSON失败: %w", err)
		}
		var tasks []map[string]any
		if err := json.Unmarshal([]byte(tasksJSON), &tasks); err != nil {
			continue
		}
		for _, task := range tasks {
			if img, ok := task["image"].(string); ok && img != "" {
				refs[filepath.Base(img)] = true
			}
		}
	}
	return refs, rows.Err()
}

// ============================================================================
// 事务内逐行合并
// ============================================================================

// MergeResult 逐行合并的结果统计。
type MergeResult struct {
	Applied int `json:"applied"` // 实际写入（含墓碑）的行数
	Skipped int `json:"skipped"` // 因 updated_at 不更新而被忽略的行数
}

func (r *MergeResult) count(applied bool) {
	if applied {
		r.Applied++
		return
	}
	r.Skipped++
}

// EssayBackupData 随笔备份的完整数据集
type EssayBackupData struct {
	Articles      []model.EssayArticle
	Labels        []model.EssayLabel
	YearSummaries []model.EssayYearSummary
}

// BookletBackupData 打卡备份的完整数据集
type BookletBackupData struct {
	Styles  []model.BookletStyle
	Records []model.BookletRecord
}

// MergeEssayData 在事务中逐行合并随笔、标签与年度汇总。
func MergeEssayData(data EssayBackupData) (MergeResult, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	var res MergeResult
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		res = MergeResult{} // 事务可能因 SQLITE_BUSY 重试，统计随之重算
		for _, a := range data.Articles {
			applied, err := mergeEssayArticle(ctx, tx, a)
			if err != nil {
				return fmt.Errorf("写入随笔 %s 失败: %w", a.ID, err)
			}
			res.count(applied)
		}
		for _, l := range data.Labels {
			applied, err := mergeEssayLabel(ctx, tx, l)
			if err != nil {
				return fmt.Errorf("写入标签 %s 失败: %w", l.ID, err)
			}
			res.count(applied)
		}
		for _, s := range data.YearSummaries {
			applied, err := mergeEssayYearSummary(ctx, tx, s)
			if err != nil {
				return fmt.Errorf("写入年度汇总 %d 失败: %w", s.Year, err)
			}
			res.count(applied)
		}
		return nil
	})
	if err != nil {
		return MergeResult{}, err
	}
	return res, nil
}

// MergeBookletData 在事务中逐行合并打卡样式与记录。
// styles 先于 records 合并，保证记录的外键目标已存在。
func MergeBookletData(data BookletBackupData) (MergeResult, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	var res MergeResult
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		res = MergeResult{} // 事务可能因 SQLITE_BUSY 重试，统计随之重算
		for _, s := range data.Styles {
			applied, err := mergeBookletStyle(ctx, tx, s)
			if err != nil {
				return fmt.Errorf("写入打卡样式 %s 失败: %w", s.ID, err)
			}
			res.count(applied)
		}
		for _, r := range data.Records {
			applied, err := mergeBookletRecord(ctx, tx, r)
			if err != nil {
				return fmt.Errorf("写入打卡记录 %s 失败: %w", r.ID, err)
			}
			res.count(applied)
		}
		return nil
	})
	if err != nil {
		return MergeResult{}, err
	}
	return res, nil
}

// mergeEssayArticle 合并单条随笔（键 id）。
func mergeEssayArticle(ctx context.Context, tx *sql.Tx, a model.EssayArticle) (bool, error) {
	updated, created := mergeStamps(a.UpdatedAt, a.CreatedAt)
	stored, exists, err := storedUpdatedAt(ctx, tx,
		`SELECT updated_at FROM user_data_essay_articles WHERE id = ?`, a.ID)
	if err != nil {
		return false, err
	}
	if exists && !newerThan(updated, stored) {
		return false, nil
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_data_essay_articles
			(id, date, word_count, content, imgs, labels, messages, mood, deleted_at, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (id) DO UPDATE SET
			date = excluded.date, word_count = excluded.word_count, content = excluded.content,
			imgs = excluded.imgs, labels = excluded.labels, messages = excluded.messages,
			mood = excluded.mood, deleted_at = excluded.deleted_at, updated_at = excluded.updated_at
	`, a.ID, model.FormatTime(a.Date), a.WordCount, a.Content,
		jsonStringArray(a.Imgs), jsonStringArray(a.Labels), jsonText(a.Messages, "[]"),
		a.Mood, nullableTime(a.DeletedAt), created, updated)
	return true, err
}

// mergeEssayLabel 合并单个标签（键 id）。
func mergeEssayLabel(ctx context.Context, tx *sql.Tx, l model.EssayLabel) (bool, error) {
	updated, created := mergeStamps(l.UpdatedAt, l.CreatedAt)
	stored, exists, err := storedUpdatedAt(ctx, tx,
		`SELECT updated_at FROM user_data_essay_labels WHERE id = ?`, l.ID)
	if err != nil {
		return false, err
	}
	if exists && !newerThan(updated, stored) {
		return false, nil
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_data_essay_labels (id, name, essay_count, deleted_at, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT (id) DO UPDATE SET
			name = excluded.name, essay_count = excluded.essay_count,
			deleted_at = excluded.deleted_at, updated_at = excluded.updated_at
	`, l.ID, l.Name, l.EssayCount, nullableTime(l.DeletedAt), created, updated)
	return true, err
}

// mergeEssayYearSummary 合并单条年度汇总（键 year）。
func mergeEssayYearSummary(ctx context.Context, tx *sql.Tx, s model.EssayYearSummary) (bool, error) {
	updated := distinctStamp(s.UpdatedAt)
	stored, exists, err := storedUpdatedAt(ctx, tx,
		`SELECT updated_at FROM user_data_essay_year_summaries WHERE year = ?`, int(s.Year))
	if err != nil {
		return false, err
	}
	if exists && !newerThan(updated, stored) {
		return false, nil
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_data_essay_year_summaries
			(year, essay_count, word_count, month_summaries, deleted_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT (year) DO UPDATE SET
			essay_count = excluded.essay_count, word_count = excluded.word_count,
			month_summaries = excluded.month_summaries, deleted_at = excluded.deleted_at,
			updated_at = excluded.updated_at
	`, int(s.Year), s.EssayCount, s.WordCount, jsonText(s.MonthSummaries, "[]"),
		nullableTime(s.DeletedAt), updated)
	return true, err
}

// mergeBookletStyle 合并单个打卡样式（键 id）。
func mergeBookletStyle(ctx context.Context, tx *sql.Tx, s model.BookletStyle) (bool, error) {
	updated, created := mergeStamps(s.UpdatedAt, s.CreatedAt)
	stored, exists, err := storedUpdatedAt(ctx, tx,
		`SELECT updated_at FROM user_data_booklet_styles WHERE id = ?`, s.ID)
	if err != nil {
		return false, err
	}
	if exists && !newerThan(updated, stored) {
		return false, nil
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_data_booklet_styles
			(id, start_date, valid_check_in, fully_done, longest_streak, longest_fully_streak,
			 tasks, deleted_at, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (id) DO UPDATE SET
			start_date = excluded.start_date, valid_check_in = excluded.valid_check_in,
			fully_done = excluded.fully_done, longest_streak = excluded.longest_streak,
			longest_fully_streak = excluded.longest_fully_streak, tasks = excluded.tasks,
			deleted_at = excluded.deleted_at, updated_at = excluded.updated_at
	`, s.ID, model.FormatDate(s.StartDate), s.ValidCheckIn, s.FullyDone,
		s.LongestStreak, s.LongestFullyStreak, jsonText(s.Tasks, "[]"),
		nullableTime(s.DeletedAt), created, updated)
	return true, err
}

// mergeBookletRecord 合并单条打卡记录（业务键 style_id + date，冲突时采纳传入 id）。
func mergeBookletRecord(ctx context.Context, tx *sql.Tx, r model.BookletRecord) (bool, error) {
	updated, created := mergeStamps(r.UpdatedAt, r.CreatedAt)
	date := model.FormatDate(r.Date)
	stored, exists, err := storedUpdatedAt(ctx, tx,
		`SELECT updated_at FROM user_data_booklet_records WHERE style_id = ? AND date = ?`, r.StyleID, date)
	if err != nil {
		return false, err
	}
	if exists && !newerThan(updated, stored) {
		return false, nil
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_data_booklet_records
			(id, style_id, date, message, task_completion, mood, deleted_at, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (style_id, date) DO UPDATE SET
			id = excluded.id, message = excluded.message,
			task_completion = excluded.task_completion, mood = excluded.mood,
			deleted_at = excluded.deleted_at, updated_at = excluded.updated_at
	`, r.ID, r.StyleID, date, r.Message, jsonText(r.TaskCompletion, "{}"),
		r.Mood, nullableTime(r.DeletedAt), created, updated)
	return true, err
}

// storedUpdatedAt 按合并键读取已存行的 updated_at；行不存在时 exists=false。
func storedUpdatedAt(ctx context.Context, tx *sql.Tx, query string, args ...any) (string, bool, error) {
	var updated string
	err := tx.QueryRowContext(ctx, query, args...).Scan(&updated)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		return "", false, nil
	case err != nil:
		return "", false, fmt.Errorf("读取已存行失败: %w", err)
	}
	return updated, true, nil
}

// newerThan 判断 incoming 是否严格晚于 stored；等值视为不更新（重复提交幂等）。
func newerThan(incoming, stored string) bool {
	if stored == "" {
		return incoming != ""
	}
	in, inErr := model.ParseTime(incoming)
	old, oldErr := model.ParseTime(stored)
	if inErr == nil && oldErr == nil {
		return in.After(old)
	}
	return incoming > stored // 格式定宽时字典序即时序
}

// mergeStamps 归一化合并用的两个时间戳。客户端未上报 updated_at 时退回服务端当前时间，
// 否则旧客户端提交的行会被永久判定为"不更新"而静默丢弃。
func mergeStamps(updated, created time.Time) (string, string) {
	now := model.Now()
	u, c := model.FormatTime(updated), model.FormatTime(created)
	if u == "" {
		u = now
	}
	if c == "" {
		c = now
	}
	return u, c
}

// distinctStamp 归一化只有 updated_at 的表的合并时间戳。
func distinctStamp(updated time.Time) string {
	if s := model.FormatTime(updated); s != "" {
		return s
	}
	return model.Now()
}

// nullableTime 把墓碑时间转成可空列参数；空值写 NULL。
func nullableTime(t *time.Time) any {
	if t == nil || t.IsZero() {
		return nil
	}
	return model.FormatTime(*t)
}

// tombstone 把可空的时间列读成墓碑指针；空值返回 nil。
func tombstone(ft model.FlexTime) *time.Time {
	t := ft.Time()
	if t.IsZero() {
		return nil
	}
	return &t
}

// jsonStringArray 把字符串数组序列化为 JSON 文本，空值统一为 "[]"。
func jsonStringArray(v []string) string {
	if len(v) == 0 {
		return "[]"
	}
	b, err := json.Marshal(v)
	if err != nil {
		return "[]"
	}
	return string(b)
}

// decodeStringArray 解析 JSON 文本数组列，空值返回空切片。
func decodeStringArray(raw, field string) ([]string, error) {
	s := strings.TrimSpace(raw)
	if s == "" || s == "null" {
		return []string{}, nil
	}
	var out []string
	if err := json.Unmarshal([]byte(s), &out); err != nil {
		return nil, fmt.Errorf("解析%s失败: %w", field, err)
	}
	if out == nil {
		return []string{}, nil
	}
	return out, nil
}

// jsonText 校验 JSON 文本列，空值或非法 JSON 回退为列默认值。
func jsonText(raw json.RawMessage, def string) string {
	s := strings.TrimSpace(string(raw))
	if s == "" || s == "null" || !json.Valid([]byte(s)) {
		return def
	}
	return s
}

// rawJSON 把 TEXT 列读成 json.RawMessage；空值回退为列默认值。
// 注意 json.RawMessage 不是 sql.Scanner，必须先扫进 string。
func rawJSON(s, def string) json.RawMessage {
	t := strings.TrimSpace(s)
	if t == "" || t == "null" {
		return json.RawMessage(def)
	}
	return json.RawMessage(t)
}

// ============================================================================
// 图片孤儿清理
// ============================================================================

// CleanOrphanImages 删除图片目录中不被引用的文件
// referencedFiles 是包含所有被引用文件名的集合（不含路径，仅文件名）
func CleanOrphanImages(imageDir string, referencedFiles map[string]bool) (int, error) {
	entries, err := os.ReadDir(imageDir)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return 0, nil
		}
		return 0, fmt.Errorf("读取图片目录失败: %w", err)
	}

	deleted := 0
	for _, entry := range entries {
		if entry.IsDir() || referencedFiles[entry.Name()] {
			continue
		}
		fullPath := filepath.Join(imageDir, entry.Name())
		if err := os.Remove(fullPath); err != nil {
			fmt.Printf("删除孤儿图片失败: %s: %v\n", fullPath, err)
		} else {
			deleted++
		}
	}
	return deleted, nil
}
