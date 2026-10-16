package data_repo

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"
	"unicode/utf16"

	"github.com/google/uuid"

	"monarch/internal/model"
)

func validateRow(name string, row map[string]any) error {
	date := "date"
	if name == "styles" {
		date = "start_date"
	}
	if name != "labels" {
		raw, _ := row[date].(string)
		var parsed model.FlexTime
		encoded, _ := json.Marshal(raw)
		if err := json.Unmarshal(encoded, &parsed); err != nil || parsed.Time().IsZero() {
			return fmt.Errorf("缺少有效的 %s", date)
		}
	}
	if name == "labels" {
		label := model.EssayLabel{ID: uuid.MustParse(row["id"].(string)), Name: row["name"].(string)}
		if parent, ok := row["parent_id"].(string); ok {
			id, err := uuid.Parse(parent)
			if err != nil {
				return fmt.Errorf("无效的上级标签")
			}
			label.ParentID = &id
		}
		if strings.TrimSpace(label.Name) == "" {
			return fmt.Errorf("标签名称不能为空")
		}
		if label.ID.String() == model.HiddenEssayLabelID && (label.Name != "隐藏" || label.ParentID != nil) {
			return fmt.Errorf("隐藏标签必须保留在根级")
		}
	}
	if name == "essays" {
		content := row["content"].(string)
		labels, _ := row["labels"].([]any)
		images, _ := row["imgs"].([]any)
		if (strings.TrimSpace(content) == "" && len(images) == 0) || len(labels) < 1 || len(labels) > 4 {
			return fmt.Errorf("随笔需有正文或图片，且需选择 1 至 4 个标签")
		}
		row["word_count"] = len(utf16.Encode([]rune(strings.TrimSpace(content))))
		if row["messages"] != nil {
			messages, ok := row["messages"].([]any)
			if !ok {
				return fmt.Errorf("随笔留言必须为数组")
			}
			for _, raw := range messages {
				message, ok := raw.(map[string]any)
				if !ok {
					return fmt.Errorf("无效的随笔留言")
				}
				if _, ok := message["content"].(string); !ok {
					return fmt.Errorf("留言内容必须为文本")
				}
				var timestamp model.FlexTime
				encoded, _ := json.Marshal(message["timestamp"])
				if err := json.Unmarshal(encoded, &timestamp); err != nil || timestamp.Time().IsZero() {
					return fmt.Errorf("留言缺少有效时间")
				}
			}
		}
	}
	if name == "styles" {
		tasks, ok := row["tasks"].([]any)
		if !ok || len(tasks) == 0 || len(tasks) > 5 {
			return fmt.Errorf("打卡任务数量应为 1 至 5")
		}
		seen := map[string]bool{}
		for _, raw := range tasks {
			task, ok := raw.(map[string]any)
			if !ok {
				return fmt.Errorf("无效的打卡任务")
			}
			id, _ := task["id"].(string)
			title, _ := task["title"].(string)
			if _, err := uuid.Parse(id); err != nil || seen[id] || strings.TrimSpace(title) == "" {
				return fmt.Errorf("打卡任务 ID 重复或缺少 ID/标题")
			}
			seen[id] = true
			if _, ok := task["description"].(string); !ok {
				return fmt.Errorf("任务说明必须为文本")
			}
			if _, ok := task["image"].(string); !ok {
				return fmt.Errorf("任务图片路径必须为文本")
			}
		}
	}
	if mood, ok := row["mood"].(string); ok {
		switch mood {
		case "happy", "calm", "sad", "angry", "tired":
		default:
			return fmt.Errorf("无效的心情")
		}
	}
	if name == "records" {
		if _, err := uuid.Parse(row["style_id"].(string)); err != nil {
			return fmt.Errorf("无效的打卡样式 ID")
		}
		completion, ok := row["task_completion"].(map[string]any)
		if !ok {
			return fmt.Errorf("task_completion 必须为对象")
		}
		for _, flag := range completion {
			if _, ok := flag.(bool); !ok {
				return fmt.Errorf("打卡完成状态必须为布尔值")
			}
		}
	}
	return nil
}

func validateRelations(ctx context.Context, tx *sql.Tx, module string) error {
	if module == "booklet" {
		return nil
	}
	rows, err := tx.QueryContext(ctx, `SELECT id,name,parent_id FROM essay_labels`)
	if err != nil {
		return err
	}
	labels := []model.EssayLabel{}
	for rows.Next() {
		var label model.EssayLabel
		if err := rows.Scan(&label.ID, &label.Name, &label.ParentID); err != nil {
			rows.Close()
			return err
		}
		labels = append(labels, label)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	if err := model.ValidateEssayLabels(labels); err != nil {
		return err
	}
	var invalid int
	if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM essay_articles a,json_each(a.labels) l WHERE NOT EXISTS (SELECT 1 FROM essay_labels WHERE id=l.value)`).Scan(&invalid); err != nil {
		return err
	}
	if invalid > 0 {
		return fmt.Errorf("随笔引用了不存在的标签，请刷新后重试")
	}
	return nil
}

func refreshStats(ctx context.Context, tx *sql.Tx, module string) error {
	if module == "essay" {
		if _, err := tx.ExecContext(ctx, `UPDATE essay_labels SET essay_count=(SELECT COUNT(*) FROM essay_articles a WHERE EXISTS(SELECT 1 FROM json_each(a.labels) WHERE value=essay_labels.id))`); err != nil {
			return err
		}
		_, err := tx.ExecContext(ctx, `DELETE FROM essay_year_summaries;
			INSERT INTO essay_year_summaries(year,essay_count,word_count,month_summaries)
			SELECT year,SUM(n),SUM(words),json_group_array(json_object('month',month,'essay_count',n,'word_count',words))
			FROM (SELECT substr(date,1,4) year,CAST(CAST(substr(date,6,2) AS INTEGER) AS TEXT) month,COUNT(*) n,SUM(word_count) words FROM essay_articles GROUP BY substr(date,1,7) ORDER BY date) GROUP BY year`)
		return err
	}
	rows, err := tx.QueryContext(ctx, `SELECT style_id,date,task_completion FROM booklet_records ORDER BY style_id,date`)
	if err != nil {
		return err
	}
	type stats struct {
		count, full, streak, fullStreak, longest, longestFull int
		last, lastFull                                        time.Time
	}
	byStyle := map[string]*stats{}
	for rows.Next() {
		var id, date, raw string
		if err := rows.Scan(&id, &date, &raw); err != nil {
			rows.Close()
			return err
		}
		s := byStyle[id]
		if s == nil {
			s = &stats{}
			byStyle[id] = s
		}
		d, _ := time.Parse("2006-01-02", date)
		s.count++
		if d.Sub(s.last) == 24*time.Hour {
			s.streak++
		} else {
			s.streak = 1
		}
		s.last = d
		s.longest = max(s.longest, s.streak)
		completion := map[string]bool{}
		if err := json.Unmarshal([]byte(raw), &completion); err != nil {
			rows.Close()
			return err
		}
		full := true
		for _, flag := range completion {
			full = full && flag
		}
		if full {
			s.full++
			if d.Sub(s.lastFull) == 24*time.Hour {
				s.fullStreak++
			} else {
				s.fullStreak = 1
			}
			s.lastFull = d
			s.longestFull = max(s.longestFull, s.fullStreak)
		}
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE booklet_styles SET valid_check_in=0,fully_done=0,longest_streak=0,longest_fully_streak=0`); err != nil {
		return err
	}
	for id, s := range byStyle {
		if _, err := tx.ExecContext(ctx, `UPDATE booklet_styles SET valid_check_in=?,fully_done=?,longest_streak=?,longest_fully_streak=? WHERE id=?`, s.count, s.full, s.longest, s.longestFull, id); err != nil {
			return err
		}
	}
	return nil
}
