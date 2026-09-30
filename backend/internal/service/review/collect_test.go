package review

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"

	"monarch/internal/config"
	"monarch/internal/dbutil"
	"monarch/internal/service/db"
)

// 统计口径必须落到真实 SQLite 上验证：essay.date 与 booklet.date 的存储形态不同，
// 只在内存里造 time.Time 是测不出归日错误的。
const testSchema = "../../../references/db/sqlite.sql"

func TestMain(m *testing.M) {
	if _, err := os.Stat(testSchema); err != nil {
		fmt.Fprintf(os.Stderr, "跳过回顾统计验收：未找到建表脚本 %s\n", testSchema)
		os.Exit(0)
	}
	dir, err := os.MkdirTemp("", "monarch-review")
	if err != nil {
		fmt.Fprintf(os.Stderr, "创建临时目录失败: %v\n", err)
		os.Exit(1)
	}
	db.Init(config.DbConfig{File: filepath.Join(dir, "review_test.db"), SchemaFile: testSchema})

	code := m.Run()

	db.Close()
	os.RemoveAll(dir)
	os.Exit(code)
}

// seedRange 写入一批固定数据（范围 2026-03-01 ~ 2026-03-05）。
type seed struct {
	labelReading uuid.UUID
	labelThought uuid.UUID
	styleID      uuid.UUID
}

func seedData(t *testing.T) seed {
	t.Helper()
	ctx := context.Background()
	ids := seed{
		labelReading: uuid.New(),
		labelThought: uuid.New(),
		styleID:      uuid.New(),
	}

	exec := func(query string, args ...any) {
		t.Helper()
		if _, err := db.Exec(ctx, query, args...); err != nil {
			t.Fatalf("写入测试数据失败: %v", err)
		}
	}

	// 各用例共用同一个临时库，先清空保证每次种子一致。
	for _, table := range []string{"essay_articles", "essay_labels", "booklet_records", "booklet_styles"} {
		exec("DELETE FROM " + table)
	}

	exec(`INSERT INTO essay_labels (id, name, essay_count) VALUES (?, ?, ?)`, ids.labelReading.String(), "读书", 3)
	exec(`INSERT INTO essay_labels (id, name, essay_count) VALUES (?, ?, ?)`, ids.labelThought.String(), "随想", 2)

	essay := func(at time.Time, words int, labels []string, mood string) {
		if labels == nil {
			labels = []string{}
		}
		raw, err := json.Marshal(labels)
		if err != nil {
			t.Fatalf("序列化标签失败: %v", err)
		}
		exec(`INSERT INTO essay_articles (id, date, word_count, content, imgs, labels, messages, mood)
		      VALUES (?, ?, ?, ?, '[]', ?, '[]', ?)`,
			uuid.NewString(), dbutil.TS(at), words, "正文", string(raw), mood)
	}
	// 范围内：3 篇、共 3000 字、最长连续 2 天、最长一篇 1500 字。
	essay(time.Date(2026, 3, 1, 21, 30, 0, 0, time.Local), 1000, []string{ids.labelReading.String()}, "happy")
	essay(time.Date(2026, 3, 2, 22, 0, 0, 0, time.Local), 500, []string{ids.labelReading.String(), ids.labelThought.String()}, "calm")
	essay(time.Date(2026, 3, 4, 9, 0, 0, 0, time.Local), 1500, []string{ids.labelThought.String()}, "calm")
	// 范围外：不得计入。
	essay(time.Date(2026, 2, 20, 10, 0, 0, 0, time.Local), 9999, []string{ids.labelReading.String()}, "happy")
	essay(time.Date(2026, 3, 20, 10, 0, 0, 0, time.Local), 9999, nil, "")

	exec(`INSERT INTO booklet_styles (id, start_date, tasks) VALUES (?, ?, ?)`,
		ids.styleID.String(), "2026-03-01 00:00:00.000",
		`[{"id":"t1","title":"早起"},{"id":"t2","title":"跑步"}]`)

	record := func(day string, completion string, mood string, message string) {
		exec(`INSERT INTO booklet_records (id, style_id, date, message, task_completion, mood)
		      VALUES (?, ?, ?, ?, ?, ?)`,
			uuid.NewString(), ids.styleID.String(), day, message, completion, mood)
	}
	record("2026-03-01", `{"t1":true,"t2":true}`, "calm", "")
	record("2026-03-02", `{"t1":true,"t2":false}`, "", "有点累")
	record("2026-03-03", `{"t1":true}`, "happy", "")
	record("2026-02-25", `{"t1":true,"t2":true}`, "happy", "范围外")

	return ids
}

func TestCollectStats(t *testing.T) {
	seedData(t)

	data, err := Collect(Range{From: day("2026-03-01"), To: day("2026-03-05")}, 0, 0)
	if err != nil {
		t.Fatalf("Collect 失败: %v", err)
	}
	stats := data.Stats
	if stats.Days != 5 || stats.From != "2026-03-01" || stats.To != "2026-03-05" {
		t.Fatalf("范围不符: %+v", stats)
	}

	essay := stats.Essay
	if essay.Count != 3 || essay.WordCount != 3000 {
		t.Fatalf("随笔篇数/字数不符: %+v", essay)
	}
	if essay.ActiveDays != 3 || essay.LongestStreak != 2 {
		t.Fatalf("写作天数/连续天数不符: %+v", essay)
	}
	if essay.LongestWords != 1500 || essay.LongestDate != "2026-03-04" {
		t.Fatalf("最长一篇不符: %+v", essay)
	}
	if len(essay.TopLabels) != 2 || essay.TopLabels[0].Name != "读书" || essay.TopLabels[0].Count != 2 {
		t.Fatalf("标签分布不符: %+v", essay.TopLabels)
	}
	if len(essay.Moods) != 2 || essay.Moods[0].Name != "平静" || essay.Moods[0].Count != 2 {
		t.Fatalf("随笔心情分布不符: %+v", essay.Moods)
	}

	booklet := stats.Booklet
	if booklet.RecordCount != 3 || booklet.ActiveDays != 3 || booklet.LongestStreak != 3 {
		t.Fatalf("打卡计数不符: %+v", booklet)
	}
	if booklet.FullyDoneDays != 1 || booklet.MessageDays != 1 {
		t.Fatalf("全勤/留言天数不符: %+v", booklet)
	}
	if len(booklet.Groups) != 1 {
		t.Fatalf("任务组数量不符: %+v", booklet.Groups)
	}
	group := booklet.Groups[0]
	if group.RecordCount != 3 || group.FullyDoneDays != 1 {
		t.Fatalf("任务组计数不符: %+v", group)
	}
	// 已完成 2 + 1 + 1 = 4，应完成 3 天 × 2 项 = 6。
	if want := 4.0 / 6.0; group.DoneRate < want-0.001 || group.DoneRate > want+0.001 {
		t.Fatalf("完成率 = %v, want %v", group.DoneRate, want)
	}
}

func TestCollectSamplesStayInRange(t *testing.T) {
	seedData(t)

	data, err := Collect(Range{From: day("2026-03-01"), To: day("2026-03-05")}, 5, 5)
	if err != nil {
		t.Fatalf("Collect 失败: %v", err)
	}
	if len(data.Essays) != 3 || len(data.Records) != 3 {
		t.Fatalf("抽样应受范围内条数限制: essays=%d records=%d", len(data.Essays), len(data.Records))
	}
	for _, item := range data.Essays {
		if item.Date < "2026-03-01" || item.Date > "2026-03-05" {
			t.Fatalf("抽到范围外的随笔: %+v", item)
		}
	}
	for _, item := range data.Records {
		if item.Date < "2026-03-01" || item.Date > "2026-03-05" {
			t.Fatalf("抽到范围外的打卡记录: %+v", item)
		}
	}

	// 不抽样时只给统计，不给材料。
	bare, err := Collect(Range{From: day("2026-03-01"), To: day("2026-03-05")}, 0, 0)
	if err != nil {
		t.Fatalf("Collect 失败: %v", err)
	}
	if len(bare.Essays) != 0 || len(bare.Records) != 0 {
		t.Fatal("抽样条数为 0 时不应返回素材")
	}
}

// 空范围（没有任何数据）必须如实呈现，而不是报错或伪造数字。
func TestCollectEmptyRange(t *testing.T) {
	seedData(t)

	data, err := Collect(Range{From: day("2025-01-01"), To: day("2025-01-31")}, 3, 3)
	if err != nil {
		t.Fatalf("Collect 失败: %v", err)
	}
	if data.Stats.Essay.Count != 0 || data.Stats.Booklet.RecordCount != 0 {
		t.Fatalf("空范围不应有数据: %+v", data.Stats)
	}
	if len(data.Essays) != 0 || len(data.Records) != 0 {
		t.Fatal("空范围不应有素材")
	}
}
