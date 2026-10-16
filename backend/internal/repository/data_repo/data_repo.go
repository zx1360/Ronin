// Package data_repo 提供随笔(essay)与打卡(booklet)的读写。
//
// 写入按 updated_at 逐行合并，删除使用持久化 tombstone。
// 数组/对象列统一存 JSON 文本，读写整列。
package data_repo

import (
	"encoding/json"
	"fmt"
	"path/filepath"

	"monarch/internal/dbutil"
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

	rows, err := db.Read().QueryContext(ctx, `
		SELECT id, date, word_count, content, title, imgs, labels, messages, mood, created_at, updated_at
		FROM essay_articles
		ORDER BY date DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("查询随笔列表失败: %w", err)
	}
	defer rows.Close()

	var articles []model.EssayArticle
	for rows.Next() {
		var (
			a        model.EssayArticle
			imgs     string
			labels   string
			messages []byte
		)
		if err := rows.Scan(
			&a.ID, &a.Date, &a.WordCount, &a.Content, &a.Title,
			&imgs, &labels, &messages, &a.Mood,
			&a.CreatedAt, &a.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("扫描随笔行失败: %w", err)
		}
		a.Imgs = decodeStrings(imgs)
		a.Labels = decodeStrings(labels)
		a.Messages = json.RawMessage(messages)
		articles = append(articles, a)
	}
	return articles, rows.Err()
}

// FetchAllEssayLabels 获取所有随笔标签
func FetchAllEssayLabels() ([]model.EssayLabel, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.Read().QueryContext(ctx,
		`SELECT id, name, essay_count, parent_id, created_at, updated_at FROM essay_labels ORDER BY essay_count DESC`)
	if err != nil {
		return nil, fmt.Errorf("查询标签列表失败: %w", err)
	}
	defer rows.Close()

	var labels []model.EssayLabel
	for rows.Next() {
		var l model.EssayLabel
		if err := rows.Scan(&l.ID, &l.Name, &l.EssayCount, &l.ParentID, &l.CreatedAt, &l.UpdatedAt); err != nil {
			return nil, fmt.Errorf("扫描标签行失败: %w", err)
		}
		labels = append(labels, l)
	}
	return model.EnsureHiddenEssayLabel(labels), rows.Err()
}

// FetchAllEssayYearSummaries 获取所有年度汇总
func FetchAllEssayYearSummaries() ([]model.EssayYearSummary, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.Read().QueryContext(ctx,
		`SELECT year, essay_count, word_count, month_summaries, updated_at FROM essay_year_summaries ORDER BY year DESC`)
	if err != nil {
		return nil, fmt.Errorf("查询年度汇总失败: %w", err)
	}
	defer rows.Close()

	var summaries []model.EssayYearSummary
	for rows.Next() {
		var (
			s       model.EssayYearSummary
			monthly []byte
		)
		if err := rows.Scan(&s.Year, &s.EssayCount, &s.WordCount, &monthly, &s.UpdatedAt); err != nil {
			return nil, fmt.Errorf("扫描年度汇总行失败: %w", err)
		}
		s.MonthSummaries = json.RawMessage(monthly)
		summaries = append(summaries, s)
	}
	return summaries, rows.Err()
}

// FetchAllBookletStyles 获取所有打卡样式
func FetchAllBookletStyles() ([]model.BookletStyle, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.Read().QueryContext(ctx, `
		SELECT id, start_date, valid_check_in, fully_done, longest_streak, longest_fully_streak, tasks, created_at, updated_at
		FROM booklet_styles
		ORDER BY start_date DESC, updated_at DESC, id
	`)
	if err != nil {
		return nil, fmt.Errorf("查询打卡样式列表失败: %w", err)
	}
	defer rows.Close()

	var styles []model.BookletStyle
	for rows.Next() {
		var (
			s     model.BookletStyle
			tasks []byte
		)
		if err := rows.Scan(
			&s.ID, &s.StartDate, &s.ValidCheckIn, &s.FullyDone,
			&s.LongestStreak, &s.LongestFullyStreak, &tasks,
			&s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("扫描打卡样式行失败: %w", err)
		}
		s.Tasks = json.RawMessage(tasks)
		styles = append(styles, s)
	}
	return styles, rows.Err()
}

// FetchAllBookletRecords 获取所有打卡记录
func FetchAllBookletRecords() ([]model.BookletRecord, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.Read().QueryContext(ctx, `
		SELECT id, style_id, date, message, task_completion, mood, created_at, updated_at
		FROM booklet_records
		ORDER BY date DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("查询打卡记录列表失败: %w", err)
	}
	defer rows.Close()

	var records []model.BookletRecord
	for rows.Next() {
		var (
			r        model.BookletRecord
			date     string
			complete []byte
		)
		if err := rows.Scan(
			&r.ID, &r.StyleID, &date, &r.Message,
			&complete, &r.Mood,
			&r.CreatedAt, &r.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("扫描打卡记录行失败: %w", err)
		}
		r.Date = model.FlexTime(dbutil.Date(date))
		r.TaskCompletion = json.RawMessage(complete)
		records = append(records, r)
	}
	return records, rows.Err()
}

// CollectEssayReferencedImages 收集随笔引用的图片文件名（仅文件名，不含路径）
func CollectEssayReferencedImages() (map[string]bool, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()

	rows, err := db.Read().QueryContext(ctx, `SELECT imgs FROM essay_articles`)
	if err != nil {
		return nil, fmt.Errorf("查询随笔图片引用失败: %w", err)
	}
	defer rows.Close()

	refs := make(map[string]bool)
	for rows.Next() {
		var imgs string
		if err := rows.Scan(&imgs); err != nil {
			return nil, fmt.Errorf("扫描图片列表失败: %w", err)
		}
		for _, img := range decodeStrings(imgs) {
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

	rows, err := db.Read().QueryContext(ctx, `SELECT tasks FROM booklet_styles`)
	if err != nil {
		return nil, fmt.Errorf("查询打卡任务图片引用失败: %w", err)
	}
	defer rows.Close()

	refs := make(map[string]bool)
	for rows.Next() {
		var raw []byte
		if err := rows.Scan(&raw); err != nil {
			return nil, fmt.Errorf("扫描任务JSON失败: %w", err)
		}
		var tasks []map[string]any
		if err := json.Unmarshal(raw, &tasks); err != nil {
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

// decodeStrings 解析 JSON 文本数组；非法内容按空数组处理。
func decodeStrings(raw string) []string {
	if raw == "" {
		return []string{}
	}
	var values []string
	if err := json.Unmarshal([]byte(raw), &values); err != nil {
		return []string{}
	}
	if values == nil {
		return []string{}
	}
	return values
}
