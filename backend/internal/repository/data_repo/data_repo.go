package data_repo

import (
	"encoding/json"
	"fmt"
	"monarch/internal/model"
	"monarch/internal/service/db"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ============================================================================
// Essay Articles
// ============================================================================

// UpsertEssayArticle 按 ID 插入或更新随笔
func UpsertEssayArticle(article model.EssayArticle) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		INSERT INTO user_data.essay_articles (id, date, word_count, content, imgs, labels, messages, mood)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (id) DO UPDATE SET
			date = EXCLUDED.date,
			word_count = EXCLUDED.word_count,
			content = EXCLUDED.content,
			imgs = EXCLUDED.imgs,
			labels = EXCLUDED.labels,
			messages = EXCLUDED.messages,
			mood = EXCLUDED.mood
	`

	_, err := db.GetPool().Exec(ctx, query,
		article.ID,
		article.Date,
		article.WordCount,
		article.Content,
		article.Imgs,
		article.Labels,
		article.Messages,
		article.Mood,
	)
	if err != nil {
		return fmt.Errorf("upsert essay_article %s: %w", article.ID, err)
	}
	return nil
}

// DeleteEssayArticlesNotIn 删除不在给定 ID 列表中的随笔
func DeleteEssayArticlesNotIn(ids []uuid.UUID) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `DELETE FROM user_data.essay_articles WHERE id != ALL($1)`
	_, err := db.GetPool().Exec(ctx, query, ids)
	if err != nil {
		return fmt.Errorf("delete essay_articles not in set: %w", err)
	}
	return nil
}

// FetchAllEssayArticles 获取所有随笔
func FetchAllEssayArticles() ([]model.EssayArticle, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		SELECT id, date, word_count, content, imgs, labels, messages, mood, created_at, updated_at
		FROM user_data.essay_articles
		ORDER BY date DESC
	`

	rows, err := db.GetPool().Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("查询随笔列表失败: %w", err)
	}
	defer rows.Close()

	var articles []model.EssayArticle
	for rows.Next() {
		var a model.EssayArticle
		err := rows.Scan(
			&a.ID, &a.Date, &a.WordCount, &a.Content,
			&a.Imgs, &a.Labels, &a.Messages, &a.Mood,
			&a.CreatedAt, &a.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("扫描随笔行失败: %w", err)
		}
		articles = append(articles, a)
	}
	return articles, rows.Err()
}

// CollectEssayReferencedImages 收集所有随笔引用的图片文件名（仅文件名，不含路径）
func CollectEssayReferencedImages() (map[string]bool, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `SELECT imgs FROM user_data.essay_articles`
	rows, err := db.GetPool().Query(ctx, query)
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

// ============================================================================
// Essay Labels
// ============================================================================

// UpsertEssayLabel 按 ID 插入或更新标签
func UpsertEssayLabel(label model.EssayLabel) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		INSERT INTO user_data.essay_labels (id, name, essay_count)
		VALUES ($1, $2, $3)
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name,
			essay_count = EXCLUDED.essay_count
	`

	_, err := db.GetPool().Exec(ctx, query, label.ID, label.Name, label.EssayCount)
	if err != nil {
		return fmt.Errorf("upsert essay_label %s: %w", label.ID, err)
	}
	return nil
}

// DeleteEssayLabelsNotIn 删除不在给定 ID 列表中的标签
func DeleteEssayLabelsNotIn(ids []uuid.UUID) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	if len(ids) == 0 {
		query := `DELETE FROM user_data.essay_labels`
		_, err := db.GetPool().Exec(ctx, query)
		return err
	}
	query := `DELETE FROM user_data.essay_labels WHERE id != ALL($1)`
	_, err := db.GetPool().Exec(ctx, query, ids)
	if err != nil {
		return fmt.Errorf("delete essay_labels not in set: %w", err)
	}
	return nil
}

// FetchAllEssayLabels 获取所有标签
func FetchAllEssayLabels() ([]model.EssayLabel, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `SELECT id, name, essay_count, created_at, updated_at FROM user_data.essay_labels ORDER BY essay_count DESC`
	rows, err := db.GetPool().Query(ctx, query)
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

// ============================================================================
// Essay Year Summaries
// ============================================================================

// UpsertEssayYearSummary 按年份插入或更新年度汇总
func UpsertEssayYearSummary(summary model.EssayYearSummary) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		INSERT INTO user_data.essay_year_summaries (year, essay_count, word_count, month_summaries)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (year) DO UPDATE SET
			essay_count = EXCLUDED.essay_count,
			word_count = EXCLUDED.word_count,
			month_summaries = EXCLUDED.month_summaries
	`

	_, err := db.GetPool().Exec(ctx, query,
		int(summary.Year),
		summary.EssayCount,
		summary.WordCount,
		summary.MonthSummaries,
	)
	if err != nil {
		return fmt.Errorf("upsert essay_year_summary %d: %w", summary.Year, err)
	}
	return nil
}

// DeleteEssayYearSummariesNotIn 删除不在给定年份列表中的年度汇总
func DeleteEssayYearSummariesNotIn(years []int) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	if len(years) == 0 {
		query := `DELETE FROM user_data.essay_year_summaries`
		_, err := db.GetPool().Exec(ctx, query)
		return err
	}
	query := `DELETE FROM user_data.essay_year_summaries WHERE year != ALL($1)`
	_, err := db.GetPool().Exec(ctx, query, years)
	if err != nil {
		return fmt.Errorf("delete essay_year_summaries not in set: %w", err)
	}
	return nil
}

// FetchAllEssayYearSummaries 获取所有年度汇总
func FetchAllEssayYearSummaries() ([]model.EssayYearSummary, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `SELECT year, essay_count, word_count, month_summaries, updated_at FROM user_data.essay_year_summaries ORDER BY year DESC`
	rows, err := db.GetPool().Query(ctx, query)
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

// ============================================================================
// Booklet Styles
// ============================================================================

// UpsertBookletStyle 按 ID 插入或更新打卡样式
func UpsertBookletStyle(style model.BookletStyle) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		INSERT INTO user_data.booklet_styles (id, start_date, valid_check_in, fully_done, longest_streak, longest_fully_streak, tasks)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (id) DO UPDATE SET
			start_date = EXCLUDED.start_date,
			valid_check_in = EXCLUDED.valid_check_in,
			fully_done = EXCLUDED.fully_done,
			longest_streak = EXCLUDED.longest_streak,
			longest_fully_streak = EXCLUDED.longest_fully_streak,
			tasks = EXCLUDED.tasks
	`

	_, err := db.GetPool().Exec(ctx, query,
		style.ID,
		style.StartDate,
		style.ValidCheckIn,
		style.FullyDone,
		style.LongestStreak,
		style.LongestFullyStreak,
		style.Tasks,
	)
	if err != nil {
		return fmt.Errorf("upsert booklet_style %s: %w", style.ID, err)
	}
	return nil
}

// DeleteBookletStylesNotIn 删除不在给定 ID 列表中的打卡样式（级联删除关联 records）
func DeleteBookletStylesNotIn(ids []uuid.UUID) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	if len(ids) == 0 {
		query := `DELETE FROM user_data.booklet_styles`
		_, err := db.GetPool().Exec(ctx, query)
		return err
	}
	query := `DELETE FROM user_data.booklet_styles WHERE id != ALL($1)`
	_, err := db.GetPool().Exec(ctx, query, ids)
	if err != nil {
		return fmt.Errorf("delete booklet_styles not in set: %w", err)
	}
	return nil
}

// FetchAllBookletStyles 获取所有打卡样式
func FetchAllBookletStyles() ([]model.BookletStyle, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		SELECT id, start_date, valid_check_in, fully_done, longest_streak, longest_fully_streak, tasks, created_at, updated_at
		FROM user_data.booklet_styles
		ORDER BY start_date DESC
	`

	rows, err := db.GetPool().Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("查询打卡样式列表失败: %w", err)
	}
	defer rows.Close()

	var styles []model.BookletStyle
	for rows.Next() {
		var s model.BookletStyle
		err := rows.Scan(
			&s.ID, &s.StartDate, &s.ValidCheckIn, &s.FullyDone,
			&s.LongestStreak, &s.LongestFullyStreak, &s.Tasks,
			&s.CreatedAt, &s.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("扫描打卡样式行失败: %w", err)
		}
		styles = append(styles, s)
	}
	return styles, rows.Err()
}

// CollectBookletReferencedImages 收集所有打卡任务引用的图片文件名
func CollectBookletReferencedImages() (map[string]bool, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `SELECT tasks FROM user_data.booklet_styles`
	rows, err := db.GetPool().Query(ctx, query)
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
		var tasks []map[string]interface{}
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
// Booklet Records
// ============================================================================

// UpsertBookletRecord 按 ID 插入或更新打卡记录
func UpsertBookletRecord(record model.BookletRecord) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		INSERT INTO user_data.booklet_records (id, style_id, date, message, task_completion, mood)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (style_id, date) DO UPDATE SET
			id = EXCLUDED.id,
			message = EXCLUDED.message,
			task_completion = EXCLUDED.task_completion,
			mood = EXCLUDED.mood
	`

	_, err := db.GetPool().Exec(ctx, query,
		record.ID,
		record.StyleID,
		record.Date.Format("2006-01-02"),
		record.Message,
		record.TaskCompletion,
		record.Mood,
	)
	if err != nil {
		return fmt.Errorf("upsert booklet_record %s: %w", record.ID, err)
	}
	return nil
}

// DeleteBookletRecordsNotIn 删除不在给定 ID 列表中的打卡记录
func DeleteBookletRecordsNotIn(ids []uuid.UUID) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	if len(ids) == 0 {
		query := `DELETE FROM user_data.booklet_records`
		_, err := db.GetPool().Exec(ctx, query)
		return err
	}
	query := `DELETE FROM user_data.booklet_records WHERE id != ALL($1)`
	_, err := db.GetPool().Exec(ctx, query, ids)
	if err != nil {
		return fmt.Errorf("delete booklet_records not in set: %w", err)
	}
	return nil
}

// FetchAllBookletRecords 获取所有打卡记录
func FetchAllBookletRecords() ([]model.BookletRecord, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	query := `
		SELECT id, style_id, date, message, task_completion, mood, created_at, updated_at
		FROM user_data.booklet_records
		ORDER BY date DESC
	`

	rows, err := db.GetPool().Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("查询打卡记录列表失败: %w", err)
	}
	defer rows.Close()

	var records []model.BookletRecord
	for rows.Next() {
		var r model.BookletRecord
		err := rows.Scan(
			&r.ID, &r.StyleID, &r.Date, &r.Message,
			&r.TaskCompletion, &r.Mood,
			&r.CreatedAt, &r.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("扫描打卡记录行失败: %w", err)
		}
		records = append(records, r)
	}
	return records, rows.Err()
}

// ============================================================================
// 事务性批量备份
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
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return fmt.Errorf("开始事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	// 1. 删除不在新数据中的记录
	if len(data.ArticleIDs) > 0 {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.essay_articles WHERE id != ALL($1)`, data.ArticleIDs)
	} else {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.essay_articles`)
	}
	if err != nil {
		return fmt.Errorf("清理旧随笔失败: %w", err)
	}

	if len(data.LabelIDs) > 0 {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.essay_labels WHERE id != ALL($1)`, data.LabelIDs)
	} else {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.essay_labels`)
	}
	if err != nil {
		return fmt.Errorf("清理旧标签失败: %w", err)
	}

	if len(data.YearIDs) > 0 {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.essay_year_summaries WHERE year != ALL($1)`, data.YearIDs)
	} else {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.essay_year_summaries`)
	}
	if err != nil {
		return fmt.Errorf("清理旧年度汇总失败: %w", err)
	}

	// 2. Upsert 新数据
	for _, a := range data.Articles {
		_, err = tx.Exec(ctx, `
			INSERT INTO user_data.essay_articles (id, date, word_count, content, imgs, labels, messages, mood)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			ON CONFLICT (id) DO UPDATE SET
				date = EXCLUDED.date, word_count = EXCLUDED.word_count,
				content = EXCLUDED.content, imgs = EXCLUDED.imgs,
				labels = EXCLUDED.labels, messages = EXCLUDED.messages, mood = EXCLUDED.mood
		`, a.ID, a.Date, a.WordCount, a.Content, a.Imgs, a.Labels, a.Messages, a.Mood)
		if err != nil {
			return fmt.Errorf("upsert essay_article %s: %w", a.ID, err)
		}
	}

	for _, l := range data.Labels {
		_, err = tx.Exec(ctx, `
			INSERT INTO user_data.essay_labels (id, name, essay_count)
			VALUES ($1, $2, $3)
			ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, essay_count = EXCLUDED.essay_count
		`, l.ID, l.Name, l.EssayCount)
		if err != nil {
			return fmt.Errorf("upsert essay_label %s: %w", l.ID, err)
		}
	}

	for _, s := range data.YearSummaries {
		_, err = tx.Exec(ctx, `
			INSERT INTO user_data.essay_year_summaries (year, essay_count, word_count, month_summaries)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (year) DO UPDATE SET
				essay_count = EXCLUDED.essay_count, word_count = EXCLUDED.word_count,
				month_summaries = EXCLUDED.month_summaries
		`, int(s.Year), s.EssayCount, s.WordCount, s.MonthSummaries)
		if err != nil {
			return fmt.Errorf("upsert essay_year_summary %d: %w", s.Year, err)
		}
	}

	return tx.Commit(ctx)
}

// ReplaceBookletData 在事务中替换全部打卡数据
func ReplaceBookletData(data BookletBackupData) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return fmt.Errorf("开始事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	// 1. 删除不在新数据中的记录（先删 records，因为有外键依赖）
	if len(data.RecordIDs) > 0 {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.booklet_records WHERE id != ALL($1)`, data.RecordIDs)
	} else {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.booklet_records`)
	}
	if err != nil {
		return fmt.Errorf("清理旧打卡记录失败: %w", err)
	}

	if len(data.StyleIDs) > 0 {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.booklet_styles WHERE id != ALL($1)`, data.StyleIDs)
	} else {
		_, err = tx.Exec(ctx, `DELETE FROM user_data.booklet_styles`)
	}
	if err != nil {
		return fmt.Errorf("清理旧打卡样式失败: %w", err)
	}

	// 2. Upsert 新数据（先 styles，后 records，因为 records 有外键）
	for _, s := range data.Styles {
		_, err = tx.Exec(ctx, `
			INSERT INTO user_data.booklet_styles (id, start_date, valid_check_in, fully_done, longest_streak, longest_fully_streak, tasks)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (id) DO UPDATE SET
				start_date = EXCLUDED.start_date, valid_check_in = EXCLUDED.valid_check_in,
				fully_done = EXCLUDED.fully_done, longest_streak = EXCLUDED.longest_streak,
				longest_fully_streak = EXCLUDED.longest_fully_streak, tasks = EXCLUDED.tasks
		`, s.ID, s.StartDate, s.ValidCheckIn, s.FullyDone, s.LongestStreak, s.LongestFullyStreak, s.Tasks)
		if err != nil {
			return fmt.Errorf("upsert booklet_style %s: %w", s.ID, err)
		}
	}

	for _, r := range data.Records {
		_, err = tx.Exec(ctx, `
			INSERT INTO user_data.booklet_records (id, style_id, date, message, task_completion, mood)
			VALUES ($1, $2, $3, $4, $5, $6)
			ON CONFLICT (style_id, date) DO UPDATE SET
				id = EXCLUDED.id, message = EXCLUDED.message,
				task_completion = EXCLUDED.task_completion, mood = EXCLUDED.mood
		`, r.ID, r.StyleID, r.Date.Format("2006-01-02"), r.Message, r.TaskCompletion, r.Mood)
		if err != nil {
			return fmt.Errorf("upsert booklet_record %s: %w", r.ID, err)
		}
	}

	return tx.Commit(ctx)
}

// ============================================================================
// 图片孤儿清理
// ============================================================================

// CleanOrphanImages 删除图片目录中不被引用的文件
// referencedFiles 是包含所有被引用文件名的集合（不含路径，仅文件名）
func CleanOrphanImages(imageDir string, referencedFiles map[string]bool) (int, error) {
	entries, err := os.ReadDir(imageDir)
	if err != nil {
		if os.IsNotExist(err) {
			return 0, nil
		}
		return 0, fmt.Errorf("读取图片目录失败: %w", err)
	}

	deleted := 0
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if !referencedFiles[entry.Name()] {
			fullPath := filepath.Join(imageDir, entry.Name())
			if err := os.Remove(fullPath); err != nil {
				fmt.Printf("删除孤儿图片失败: %s: %v\n", fullPath, err)
			} else {
				deleted++
			}
		}
	}
	return deleted, nil
}

// ============================================================================
// 辅助函数
// ============================================================================

// ParseUUID 安全解析 UUID 字符串，失败返回错误
func ParseUUID(s string) (uuid.UUID, error) {
	return uuid.Parse(s)
}

// EnsureSchemas 确保 user_data schema 存在
func EnsureSchemas() error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	_, err := db.GetPool().Exec(ctx, `CREATE SCHEMA IF NOT EXISTS user_data`)
	if err != nil {
		return fmt.Errorf("创建 user_data schema 失败: %w", err)
	}
	return nil
}

// suppress unused import warnings
var _ = time.Time{}
var _ = pgx.ErrNoRows
