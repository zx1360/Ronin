package data_repo

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"

	"monarch/internal/dbutil"
	"monarch/internal/model"
	"monarch/internal/service/db"
)

const SyncVersion = 2

type Tombstone struct {
	Collection string         `json:"collection"`
	ID         string         `json:"id"`
	UpdatedAt  model.FlexTime `json:"updated_at"`
}

type SyncData struct {
	SyncVersion int                   `json:"sync_version"`
	Essays      []model.EssayArticle  `json:"essays,omitempty"`
	Labels      []model.EssayLabel    `json:"labels,omitempty"`
	Styles      []model.BookletStyle  `json:"styles,omitempty"`
	Records     []model.BookletRecord `json:"records,omitempty"`
	Tombstones  []Tombstone           `json:"tombstones,omitempty"`
}

type collection struct {
	name, table, columns string
	jsonColumns          string
}

var collections = map[string][]collection{
	"essay": {
		{"labels", "essay_labels", "id,name,essay_count,parent_id,created_at,updated_at", ""},
		{"essays", "essay_articles", "id,date,word_count,content,title,imgs,labels,messages,mood,created_at,updated_at", ",imgs,labels,messages,"},
	},
	"booklet": {
		{"styles", "booklet_styles", "id,start_date,valid_check_in,fully_done,longest_streak,longest_fully_streak,tasks,created_at,updated_at", ",tasks,"},
		{"records", "booklet_records", "id,style_id,date,message,task_completion,mood,created_at,updated_at", ",task_completion,"},
	},
}

func findCollection(module, name string) (collection, error) {
	for _, spec := range collections[module] {
		if spec.name == name {
			return spec, nil
		}
	}
	return collection{}, fmt.Errorf("无效的数据集合: %s/%s", module, name)
}

// ReadSync 在同一读快照中取游标、行和 tombstone，避免分页边界漏掉并发写入。
func ReadSync(module string, after int64) (map[string]any, error) {
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	tx, err := db.Read().BeginTx(ctx, &sql.TxOptions{ReadOnly: true})
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	var cursor int64
	if err := tx.QueryRowContext(ctx, `SELECT COALESCE(MAX(revision),0) FROM user_data_changes WHERE module=?`, module).Scan(&cursor); err != nil {
		return nil, err
	}
	if after > cursor {
		return nil, fmt.Errorf("同步游标已失效，请重新完整合并")
	}
	result := map[string]any{"sync_version": SyncVersion, "cursor": cursor, "tombstones": []Tombstone{}}
	for _, spec := range collections[module] {
		columns := strings.Split(spec.columns, ",")
		query := "SELECT r." + strings.Join(columns, ",r.") + " FROM " + spec.table + " r"
		args := []any{}
		if after > 0 {
			query += ` JOIN user_data_changes c ON c.module=? AND c.collection=? AND c.row_id=r.id WHERE c.revision>? AND c.deleted=0`
			args = []any{module, spec.name, after}
		}
		rows, err := tx.QueryContext(ctx, query+" ORDER BY r.id", args...)
		if err != nil {
			return nil, err
		}
		items := []map[string]any{}
		for rows.Next() {
			values, ptrs := make([]any, len(columns)), make([]any, len(columns))
			for i := range values {
				ptrs[i] = &values[i]
			}
			if err := rows.Scan(ptrs...); err != nil {
				rows.Close()
				return nil, err
			}
			item := map[string]any{}
			for i, column := range columns {
				value := values[i]
				if raw, ok := value.([]byte); ok {
					value = string(raw)
				}
				if raw, ok := value.(string); ok {
					switch {
					case strings.Contains(spec.jsonColumns, ","+column+","):
						value = json.RawMessage(raw)
					case column == "created_at" || column == "updated_at" || (column == "date" && module == "essay"):
						value = model.FlexTime(dbutil.Time(raw))
					case column == "start_date":
						value = dbutil.Time(raw).UTC().Format("2006-01-02")
					}
				}
				item[column] = value
			}
			items = append(items, item)
		}
		if err := rows.Err(); err != nil {
			rows.Close()
			return nil, err
		}
		rows.Close()
		result[spec.name] = items
	}
	rows, err := tx.QueryContext(ctx, `SELECT collection,row_id,updated_at FROM user_data_changes WHERE module=? AND deleted=1 AND revision>? ORDER BY revision`, module, after)
	if err != nil {
		return nil, err
	}
	deleted := []Tombstone{}
	for rows.Next() {
		var item Tombstone
		if err := rows.Scan(&item.Collection, &item.ID, &item.UpdatedAt); err != nil {
			rows.Close()
			return nil, err
		}
		deleted = append(deleted, item)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return nil, err
	}
	result["tombstones"] = deleted
	if module == "essay" {
		result["essay_schema_version"] = model.EssaySchemaVersion
		summaries := []model.EssayYearSummary{}
		rows, err := tx.QueryContext(ctx, `SELECT year,essay_count,word_count,month_summaries,updated_at FROM essay_year_summaries ORDER BY year DESC`)
		if err != nil {
			return nil, err
		}
		for rows.Next() {
			var summary model.EssayYearSummary
			var monthly []byte
			if err := rows.Scan(&summary.Year, &summary.EssayCount, &summary.WordCount, &monthly, &summary.UpdatedAt); err != nil {
				rows.Close()
				return nil, err
			}
			summary.MonthSummaries = json.RawMessage(monthly)
			summaries = append(summaries, summary)
		}
		err = rows.Err()
		rows.Close()
		if err != nil {
			return nil, err
		}
		result["year_summaries"] = summaries
	}
	return result, tx.Commit()
}

// Images 同时校验路径；合并时不清理未引用文件，离线端仍可能引用它们。
func (data SyncData) Images(module string) (map[string]bool, error) {
	refs := map[string]bool{}
	add := func(path string) error {
		if path == "" {
			return nil
		}
		prefix := "img_storage/" + module + "/"
		if strings.Contains(path, "\\") || !strings.HasPrefix(path, prefix) || strings.TrimPrefix(path, prefix) != filepath.Base(path) {
			return fmt.Errorf("图片路径不在模块目录内: %s", path)
		}
		refs[filepath.Base(path)] = true
		return nil
	}
	for _, essay := range data.Essays {
		for _, image := range essay.Imgs {
			if err := add(image); err != nil {
				return nil, err
			}
		}
	}
	for _, style := range data.Styles {
		var tasks []struct {
			Image string `json:"image"`
		}
		if err := json.Unmarshal(style.Tasks, &tasks); err != nil {
			return nil, fmt.Errorf("无效的打卡任务: %w", err)
		}
		for _, task := range tasks {
			if err := add(task.Image); err != nil {
				return nil, err
			}
		}
	}
	return refs, nil
}

func MergeSync(module string, data SyncData) error {
	if data.SyncVersion != SyncVersion {
		return fmt.Errorf("请更新客户端：用户数据需要 sync_version=%d 的增量合并协议", SyncVersion)
	}
	if _, ok := collections[module]; !ok {
		return fmt.Errorf("不支持的模块: %s", module)
	}
	if (module == "essay" && (len(data.Styles)+len(data.Records) > 0)) || (module == "booklet" && (len(data.Essays)+len(data.Labels) > 0)) {
		return fmt.Errorf("提交的数据不属于当前模块")
	}
	ctx, cancel := db.GetLongCtx()
	defer cancel()
	return db.Tx(ctx, func(tx *sql.Tx) error {
		changed := false
		seen := map[string]bool{}
		for _, item := range data.Tombstones {
			if err := validVersion(item.ID, item.UpdatedAt); err != nil {
				return err
			}
			item.ID = uuid.MustParse(item.ID).String()
			spec, err := findCollection(module, item.Collection)
			if err != nil {
				return err
			}
			key := "delete:" + item.Collection + ":" + item.ID
			if seen[key] {
				return fmt.Errorf("数据 ID 重复: %s", key)
			}
			seen[key] = true
			updated, err := deleteRow(ctx, tx, module, spec, item.ID, dbutil.TS(item.UpdatedAt.Time()))
			if err != nil {
				return err
			}
			changed = changed || updated
		}
		merge := func(name string, value any) error {
			raw, err := json.Marshal(value)
			if err != nil {
				return err
			}
			var items []map[string]any
			if err := json.Unmarshal(raw, &items); err != nil {
				return err
			}
			spec, _ := findCollection(module, name)
			for _, row := range items {
				id, _ := row["id"].(string)
				key := "row:" + name + ":" + id
				if seen[key] {
					return fmt.Errorf("数据 ID 重复: %s", key)
				}
				seen[key] = true
				updated, err := mergeRow(ctx, tx, module, spec, row)
				if err != nil {
					return err
				}
				changed = changed || updated
			}
			return nil
		}
		if module == "essay" {
			if err := merge("labels", data.Labels); err != nil {
				return err
			}
			if err := merge("essays", data.Essays); err != nil {
				return err
			}
		} else {
			if err := merge("styles", data.Styles); err != nil {
				return err
			}
			if err := merge("records", data.Records); err != nil {
				return err
			}
		}
		if err := validateRelations(ctx, tx, module); err != nil {
			return err
		}
		if changed {
			return refreshStats(ctx, tx, module)
		}
		return nil
	})
}

func validVersion(id string, updated model.FlexTime) error {
	parsed, err := uuid.Parse(id)
	if err != nil || parsed == uuid.Nil || updated.Time().IsZero() {
		return fmt.Errorf("数据缺少有效的 id 或 updated_at")
	}
	if updated.Time().After(time.Now().Add(5 * time.Minute)) {
		return fmt.Errorf("updated_at 超前超过五分钟，请校准设备时间")
	}
	return nil
}

func rowVersion(ctx context.Context, tx *sql.Tx, module string, spec collection, id string) (string, bool, error) {
	var stamp string
	var deleted bool
	err := tx.QueryRowContext(ctx, `SELECT updated_at,deleted FROM user_data_changes WHERE module=? AND collection=? AND row_id=?`, module, spec.name, id).Scan(&stamp, &deleted)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return "", false, err
	}
	var current string
	err = tx.QueryRowContext(ctx, "SELECT updated_at FROM "+spec.table+" WHERE id=?", id).Scan(&current)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return "", false, err
	}
	if current > stamp {
		return current, false, nil
	}
	return stamp, deleted, nil
}

func trackChange(ctx context.Context, tx *sql.Tx, module string, spec collection, id, stamp string, deleted bool) error {
	_, err := tx.ExecContext(ctx, `INSERT OR REPLACE INTO user_data_changes(module,collection,row_id,updated_at,deleted) VALUES(?,?,?,?,?)`, module, spec.name, id, stamp, deleted)
	return err
}

func deleteRow(ctx context.Context, tx *sql.Tx, module string, spec collection, id, stamp string) (bool, error) {
	current, deleted, err := rowVersion(ctx, tx, module, spec, id)
	if err != nil || current > stamp || (current == stamp && deleted) {
		return false, err
	}
	if spec.name == "labels" {
		var name string
		var parent *string
		_ = tx.QueryRowContext(ctx, `SELECT name,parent_id FROM essay_labels WHERE id=?`, id).Scan(&name, &parent)
		if id == model.HiddenEssayLabelID || (name == "隐藏" && parent == nil) {
			return false, fmt.Errorf("隐藏标签不可删除")
		}
	}
	if spec.name == "styles" {
		rows, err := tx.QueryContext(ctx, `SELECT id,updated_at FROM booklet_records WHERE style_id=?`, id)
		if err != nil {
			return false, err
		}
		ids := []string{}
		for rows.Next() {
			var child, updated string
			if err := rows.Scan(&child, &updated); err != nil {
				rows.Close()
				return false, err
			}
			if updated > stamp {
				rows.Close()
				return false, fmt.Errorf("样式存在更新的打卡记录，请刷新后再删除")
			}
			ids = append(ids, child)
		}
		err = rows.Err()
		rows.Close()
		if err != nil {
			return false, err
		}
		records, _ := findCollection(module, "records")
		for _, child := range ids {
			if _, err := deleteRow(ctx, tx, module, records, child, stamp); err != nil {
				return false, err
			}
		}
	}
	if _, err := tx.ExecContext(ctx, "DELETE FROM "+spec.table+" WHERE id=?", id); err != nil {
		return false, err
	}
	return true, trackChange(ctx, tx, module, spec, id, stamp, true)
}

func mergeRow(ctx context.Context, tx *sql.Tx, module string, spec collection, row map[string]any) (bool, error) {
	id, _ := row["id"].(string)
	var updated model.FlexTime
	raw, _ := json.Marshal(row["updated_at"])
	if err := json.Unmarshal(raw, &updated); err != nil {
		return false, err
	}
	if err := validVersion(id, updated); err != nil {
		return false, err
	}
	stamp := dbutil.TS(updated.Time())
	current, _, err := rowVersion(ctx, tx, module, spec, id)
	if err != nil || current >= stamp {
		return false, err
	}
	if err := validateRow(spec.name, row); err != nil {
		return false, err
	}
	if spec.name == "records" {
		styles, _ := findCollection(module, "styles")
		parent, deleted, err := rowVersion(ctx, tx, module, styles, row["style_id"].(string))
		if err != nil {
			return false, err
		}
		if deleted && parent >= stamp {
			return true, trackChange(ctx, tx, module, spec, id, parent, true)
		}
		var tasksRaw string
		if err := tx.QueryRowContext(ctx, `SELECT tasks FROM booklet_styles WHERE id=?`, row["style_id"]).Scan(&tasksRaw); err != nil {
			return false, fmt.Errorf("打卡样式不存在，请刷新后重试")
		}
		var tasks []struct {
			ID string `json:"id"`
		}
		if err := json.Unmarshal([]byte(tasksRaw), &tasks); err != nil {
			return false, err
		}
		completion := row["task_completion"].(map[string]any)
		if len(completion) != len(tasks) {
			return false, fmt.Errorf("打卡任务与样式不一致")
		}
		for _, task := range tasks {
			if _, ok := completion[task.ID]; !ok {
				return false, fmt.Errorf("打卡任务与样式不一致")
			}
		}
		var other, otherStamp string
		err = tx.QueryRowContext(ctx, `SELECT id,updated_at FROM booklet_records WHERE style_id=? AND date=? AND id<>?`, row["style_id"], row["date"].(string)[:10], id).Scan(&other, &otherStamp)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return false, err
		}
		if other != "" {
			if otherStamp >= stamp {
				return true, trackChange(ctx, tx, module, spec, id, otherStamp, true)
			}
			if _, err := deleteRow(ctx, tx, module, spec, other, stamp); err != nil {
				return false, err
			}
		}
	}
	columns := strings.Split(spec.columns, ",")
	values, assignments := []any{}, []string{}
	for _, column := range columns {
		value := row[column]
		switch {
		case strings.Contains(spec.jsonColumns, ","+column+","):
			if value == nil {
				if column == "task_completion" {
					value = map[string]bool{}
				} else {
					value = []any{}
				}
			}
			raw, _ := json.Marshal(value)
			value = string(raw)
		case column == "updated_at":
			value = stamp
		case column == "created_at":
			value = stamp
			if text, ok := row[column].(string); ok {
				if parsed, err := dbutil.ParseTS(text); err == nil {
					value = dbutil.TS(parsed)
				}
			}
		case column == "start_date":
			value = dbutil.TS(dbutil.Date(row[column].(string)[:10]))
		case column == "date":
			text := row[column].(string)
			if module == "booklet" {
				value = text[:10]
			} else {
				parsed, _ := dbutil.ParseTS(text)
				value = dbutil.TS(parsed)
			}
		}
		values = append(values, value)
		if column != "id" && column != "created_at" {
			assignments = append(assignments, column+"=excluded."+column)
		}
	}
	_, err = tx.ExecContext(ctx, "INSERT INTO "+spec.table+" ("+spec.columns+") VALUES ("+dbutil.Placeholders(len(columns))+") ON CONFLICT(id) DO UPDATE SET "+strings.Join(assignments, ","), values...)
	if err != nil {
		return false, err
	}
	return true, trackChange(ctx, tx, module, spec, id, stamp, false)
}
