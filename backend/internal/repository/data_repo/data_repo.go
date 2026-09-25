// Package data_repo 提供 user_data schema 的读写：随笔(essay)与打卡(booklet)。
//
// 写入统一走"事务内全量替换"：客户端提交完整数据集，服务端在同一事务里
// 删除多余行并 upsert 新行，因此失败必定整体回滚，不会留下半套数据。
package data_repo

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// ============================================================================
// 读取
// ============================================================================

// FetchAllEssayArticles 获取所有随笔
func FetchAllEssayArticles() ([]model.EssayArticle, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `
		SELECT id, date, word_count, content, imgs, labels, messages, mood, created_at, updated_at
		FROM user_data.essay_articles
		ORDER BY date DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("查询随笔列表失败: %w", err)
	}
	defer rows.Close()

	var articles []model.EssayArticle
	for rows.Next() {
		var a model.EssayArticle
		if err := rows.Scan(
			&a.ID, &a.Date, &a.WordCount, &a.Content,
			&a.Imgs, &a.Labels, &a.Messages, &a.Mood,
			&a.CreatedAt, &a.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("扫描随笔行失败: %w", err)
		}
		articles = append(articles, a)
	}
	return articles, rows.Err()
}

// FetchAllEssayLabels 获取所有随笔标签
func FetchAllEssayLabels() ([]model.EssayLabel, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx,
		`SELECT id, name, essay_count, created_at, updated_at FROM user_data.essay_labels ORDER BY essay_count DESC`)
	if err != nil {
		return nil, fmt.Errorf("查询标签列表失败: %w", err)
	}
	defer rows.Close()

	var labels []model.EssayLabel
	for rows.Next() {
		var l model.EssayLabel
		if err := rows.Scan(&l.ID, &l.Name, &l.EssayCount, &l.CreatedAt, &l.UpdatedAt); err != nil {
			return nil, fmt.Errorf("扫描标签行失败: %w", err)
		}
		labels = append(labels, l)
	}
	return labels, rows.Err()
}

// FetchAllEssayYearSummaries 获取所有年度汇总
func FetchAllEssayYearSummaries() ([]model.EssayYearSummary, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx,
		`SELECT year, essay_count, word_count, month_summaries, updated_at FROM user_data.essay_year_summaries ORDER BY year DESC`)
	if err != nil {
		return nil, fmt.Errorf("查询年度汇总失败: %w", err)
	}
	defer rows.Close()

	var summaries []model.EssayYearSummary
	for rows.Next() {
		var s model.EssayYearSummary
		if err := rows.Scan(&s.Year, &s.EssayCount, &s.WordCount, &s.MonthSummaries, &s.UpdatedAt); err != nil {
			return nil, fmt.Errorf("扫描年度汇总行失败: %w", err)
		}
		summaries = append(summaries, s)
	}
	return summaries, rows.Err()
}

// FetchAllBookletStyles 获取所有打卡样式
func FetchAllBookletStyles() ([]model.BookletStyle, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `
		SELECT id, start_date, valid_check_in, fully_done, longest_streak, longest_fully_streak, tasks, created_at, updated_at
		FROM user_data.booklet_styles
		ORDER BY start_date DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("查询打卡样式列表失败: %w", err)
	}
	defer rows.Close()

	var styles []model.BookletStyle
	for rows.Next() {
		var s model.BookletStyle
		if err := rows.Scan(
			&s.ID, &s.StartDate, &s.ValidCheckIn, &s.FullyDone,
			&s.LongestStreak, &s.LongestFullyStreak, &s.Tasks,
			&s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("扫描打卡样式行失败: %w", err)
		}
		styles = append(styles, s)
	}
	return styles, rows.Err()
}

// FetchAllBookletRecords 获取所有打卡记录
func FetchAllBookletRecords() ([]model.BookletRecord, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `
		SELECT id, style_id, date, message, task_completion, mood, created_at, updated_at
		FROM user_data.booklet_records
		ORDER BY date DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("查询打卡记录列表失败: %w", err)
	}
	defer rows.Close()

	var records []model.BookletRecord
	for rows.Next() {
		var r model.BookletRecord
		if err := rows.Scan(
			&r.ID, &r.StyleID, &r.Date, &r.Message,
			&r.TaskCompletion, &r.Mood,
			&r.CreatedAt, &r.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("扫描打卡记录行失败: %w", err)
		}
		records = append(records, r)
	}
	return records, rows.Err()
}

// CollectEssayReferencedImages 收集随笔引用的图片文件名（仅文件名，不含路径）
func CollectEssayReferencedImages() (map[string]bool, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `SELECT imgs FROM user_data.essay_articles`)
	if err != nil {
		return nil, fmt.Errorf("查询随笔图片引用失败: %w", err)
	}
	defer rows.Close()

	refs := make(map[string]bool)
	for rows.Next() {
		var imgs []string
		if err := rows.Scan(&imgs); err != nil {
			return nil, fmt.Errorf("扫描图片列表失败: %w", err)
		}
		for _, img := range imgs {
			if img != "" {
				refs[filepath.Base(img)] = true
			}
		}
	}
	return refs, rows.Err()
}

// CollectBookletReferencedImages 收集打卡任务引用的图片文件名
func CollectBookletReferencedImages() (map[string]bool, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.GetPool().Query(ctx, `SELECT tasks FROM user_data.booklet_styles`)
	if err != nil {
		return nil, fmt.Errorf("查询打卡任务图片引用失败: %w", err)
	}
	defer rows.Close()

	refs := make(map[string]bool)
	for rows.Next() {
		var tasksJSON json.RawMessage
		if err := rows.Scan(&tasksJSON); err != nil {
			return nil, fmt.Errorf("扫描任务JSON失败: %w", err)
		}
		var tasks []map[string]any
		if err := json.Unmarshal(tasksJSON, &tasks); err != nil {
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
// 事务性全量替换
// ============================================================================

// EssayBackupData 随笔备份的完整数据集
type EssayBackupData struct {
	Articles      []model.EssayArticle
	Labels        []model.EssayLabel
	YearSummaries []model.EssayYearSummary
	ArticleIDs    []uuid.UUID
	LabelIDs      []uuid.UUID
	YearIDs       []int
}

// BookletBackupData 打卡备份的完整数据集
type BookletBackupData struct {
	Styles    []model.BookletStyle
	Records   []model.BookletRecord
	StyleIDs  []uuid.UUID
	RecordIDs []uuid.UUID
}

// ReplaceEssayData 在事务中替换全部随笔数据
func ReplaceEssayData(data EssayBackupData) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return fmt.Errorf("开始事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	if err := deleteNotIn(ctx, tx, "user_data.essay_articles", "id", data.ArticleIDs); err != nil {
		return fmt.Errorf("清理旧随笔失败: %w", err)
	}
	if err := deleteNotIn(ctx, tx, "user_data.essay_labels", "id", data.LabelIDs); err != nil {
		return fmt.Errorf("清理旧标签失败: %w", err)
	}
	if err := deleteNotIn(ctx, tx, "user_data.essay_year_summaries", "year", data.YearIDs); err != nil {
		return fmt.Errorf("清理旧年度汇总失败: %w", err)
	}

	for _, a := range data.Articles {
		if _, err := tx.Exec(ctx, `
			INSERT INTO user_data.essay_articles (id, date, word_count, content, imgs, labels, messages, mood)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			ON CONFLICT (id) DO UPDATE SET
				date = EXCLUDED.date, word_count = EXCLUDED.word_count,
				content = EXCLUDED.content, imgs = EXCLUDED.imgs,
				labels = EXCLUDED.labels, messages = EXCLUDED.messages, mood = EXCLUDED.mood
		`, a.ID, a.Date, a.WordCount, a.Content, a.Imgs, a.Labels, a.Messages, a.Mood); err != nil {
			return fmt.Errorf("写入随笔 %s 失败: %w", a.ID, err)
		}
	}

	for _, l := range data.Labels {
		if _, err := tx.Exec(ctx, `
			INSERT INTO user_data.essay_labels (id, name, essay_count)
			VALUES ($1, $2, $3)
			ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, essay_count = EXCLUDED.essay_count
		`, l.ID, l.Name, l.EssayCount); err != nil {
			return fmt.Errorf("写入标签 %s 失败: %w", l.ID, err)
		}
	}

	for _, s := range data.YearSummaries {
		if _, err := tx.Exec(ctx, `
			INSERT INTO user_data.essay_year_summaries (year, essay_count, word_count, month_summaries)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (year) DO UPDATE SET
				essay_count = EXCLUDED.essay_count, word_count = EXCLUDED.word_count,
				month_summaries = EXCLUDED.month_summaries
		`, int(s.Year), s.EssayCount, s.WordCount, s.MonthSummaries); err != nil {
			return fmt.Errorf("写入年度汇总 %d 失败: %w", s.Year, err)
		}
	}

	return tx.Commit(ctx)
}

// ReplaceBookletData 在事务中替换全部打卡数据
func ReplaceBookletData(data BookletBackupData) error {
	ctx, cancel := db.GetLongCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return fmt.Errorf("开始事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	// records 有指向 styles 的外键，先删 records 再删 styles
	if err := deleteNotIn(ctx, tx, "user_data.booklet_records", "id", data.RecordIDs); err != nil {
		return fmt.Errorf("清理旧打卡记录失败: %w", err)
	}
	if err := deleteNotIn(ctx, tx, "user_data.booklet_styles", "id", data.StyleIDs); err != nil {
		return fmt.Errorf("清理旧打卡样式失败: %w", err)
	}

	for _, s := range data.Styles {
		if _, err := tx.Exec(ctx, `
			INSERT INTO user_data.booklet_styles (id, start_date, valid_check_in, fully_done, longest_streak, longest_fully_streak, tasks)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (id) DO UPDATE SET
				start_date = EXCLUDED.start_date, valid_check_in = EXCLUDED.valid_check_in,
				fully_done = EXCLUDED.fully_done, longest_streak = EXCLUDED.longest_streak,
				longest_fully_streak = EXCLUDED.longest_fully_streak, tasks = EXCLUDED.tasks
		`, s.ID, s.StartDate, s.ValidCheckIn, s.FullyDone, s.LongestStreak, s.LongestFullyStreak, s.Tasks); err != nil {
			return fmt.Errorf("写入打卡样式 %s 失败: %w", s.ID, err)
		}
	}

	for _, r := range data.Records {
		if _, err := tx.Exec(ctx, `
			INSERT INTO user_data.booklet_records (id, style_id, date, message, task_completion, mood)
			VALUES ($1, $2, $3, $4, $5, $6)
			ON CONFLICT (style_id, date) DO UPDATE SET
				id = EXCLUDED.id, message = EXCLUDED.message,
				task_completion = EXCLUDED.task_completion, mood = EXCLUDED.mood
		`, r.ID, r.StyleID, r.Date.Format("2006-01-02"), r.Message, r.TaskCompletion, r.Mood); err != nil {
			return fmt.Errorf("写入打卡记录 %s 失败: %w", r.ID, err)
		}
	}

	return tx.Commit(ctx)
}

// deleteNotIn 删除列值不在 keep 集合中的行；keep 为空表示清空整表。
// table/column 只接受本包内的字面量，不拼接外部输入。
func deleteNotIn[T any](ctx context.Context, tx pgx.Tx, table, column string, keep []T) error {
	if len(keep) == 0 {
		_, err := tx.Exec(ctx, "DELETE FROM "+table)
		return err
	}
	_, err := tx.Exec(ctx, "DELETE FROM "+table+" WHERE "+column+" != ALL($1)", keep)
	return err
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
