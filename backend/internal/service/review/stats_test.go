package review

import (
	"strings"
	"testing"
	"time"
)

func day(raw string) time.Time {
	t, err := time.ParseInLocation("2006-01-02", raw, time.UTC)
	if err != nil {
		panic(err)
	}
	return t
}

// localDay 与 markedDay 的口径必须分开：essay 存绝对时刻、booklet 存日历日标记，
// 混用会在非零时区整体错一天。
func TestDayNormalization(t *testing.T) {
	// 绝对时刻（本地 2026-03-05 07:00）归入本地日历日，而不是 UTC 日。
	local := time.Date(2026, 3, 5, 7, 0, 0, 0, time.Local)
	if got := localDay(local); !got.Equal(day("2026-03-05")) {
		t.Fatalf("localDay = %s, want 2026-03-05", got.Format("2006-01-02"))
	}

	// 日历日标记存的是 UTC 零点，即便本机是负偏移时区也必须仍是同一天。
	marked := time.Date(2026, 3, 5, 0, 0, 0, 0, time.UTC)
	if got := markedDay(marked); !got.Equal(day("2026-03-05")) {
		t.Fatalf("markedDay = %s, want 2026-03-05", got.Format("2006-01-02"))
	}
}

func TestRange(t *testing.T) {
	r := Range{From: day("2026-03-01"), To: day("2026-03-10")}
	if r.Days() != 10 {
		t.Fatalf("Days = %d, want 10", r.Days())
	}
	if !r.Contains(day("2026-03-01")) || !r.Contains(day("2026-03-10")) {
		t.Fatal("闭区间首尾都应命中")
	}
	if r.Contains(day("2026-02-28")) || r.Contains(day("2026-03-11")) {
		t.Fatal("范围外的日期不应命中")
	}
	if empty := (Range{From: day("2026-03-10"), To: day("2026-03-01")}); empty.Days() != 0 {
		t.Fatalf("倒置范围的 Days = %d, want 0", empty.Days())
	}
}

func TestLongestStreak(t *testing.T) {
	cases := []struct {
		name string
		days []string
		want int
	}{
		{"空", nil, 0},
		{"单天", []string{"2026-03-02"}, 1},
		{"乱序与重复", []string{"2026-03-03", "2026-03-01", "2026-03-02", "2026-03-02"}, 3},
		{"跨月连续", []string{"2026-02-28", "2026-03-01", "2026-03-02"}, 3},
		{"两段取长", []string{"2026-03-01", "2026-03-02", "2026-03-05"}, 2},
	}
	for _, item := range cases {
		t.Run(item.name, func(t *testing.T) {
			parsed := make([]time.Time, 0, len(item.days))
			for _, raw := range item.days {
				parsed = append(parsed, day(raw))
			}
			if got := longestStreak(parsed); got != item.want {
				t.Fatalf("longestStreak = %d, want %d", got, item.want)
			}
		})
	}
}

// topCounts 必须稳定：同次数按名称排序，否则每次生成的提示词都在抖。
func TestTopCountsStable(t *testing.T) {
	counts := map[string]int{"读书": 2, "工作": 2, "随想": 5}
	items := topCounts(counts, 2)
	if len(items) != 2 || items[0].Name != "随想" || items[1].Name != "工作" {
		t.Fatalf("topCounts = %+v", items)
	}
	all := topCounts(counts, 0)
	if len(all) != 3 {
		t.Fatalf("limit<=0 不应截断，得到 %d 项", len(all))
	}
}

func TestStatsTextEmpty(t *testing.T) {
	text := Stats{From: "2026-03-01", To: "2026-03-30", Days: 30}.Text()
	if !strings.Contains(text, "没有写") || !strings.Contains(text, "没有打卡记录") {
		t.Fatalf("空数据应如实说明，实际:\n%s", text)
	}
}

func TestStatsTextFull(t *testing.T) {
	stats := Stats{
		From: "2026-03-01", To: "2026-03-30", Days: 30,
		Essay: EssayStats{
			Count: 4, WordCount: 3000, ActiveDays: 3, LongestStreak: 2,
			LongestWords: 1200, LongestDate: "2026-03-12",
			TopLabels: []Count{{Name: "读书", Count: 3}},
			Moods:     []Count{{Name: "平静", Count: 2}},
		},
		Booklet: BookletStats{
			RecordCount: 10, ActiveDays: 8, FullyDoneDays: 5, LongestStreak: 4, MessageDays: 3,
			Moods:  []Count{{Name: "开心", Count: 4}},
			Groups: []GroupStats{{Tasks: []string{"早起", "跑步"}, RecordCount: 9, FullyDoneDays: 5, DoneRate: 0.75}},
		},
	}
	text := stats.Text()
	for _, want := range []string{"共 4 篇", "最长连续 2 天", "读书 3", "全勤 5 天", "任务组「早起/跑步」", "75%"} {
		if !strings.Contains(text, want) {
			t.Fatalf("统计文本缺少 %q，实际:\n%s", want, text)
		}
	}
}

func TestPromptsIncludeSamples(t *testing.T) {
	data := &Data{
		Stats: Stats{From: "2026-03-01", To: "2026-03-02", Days: 2},
		Essays: []EssaySample{{
			Date: "2026-03-01", WordCount: 100, Labels: []string{"读书"},
			Mood: "平静", Content: "今天读完了半本书。",
		}},
		Records: []RecordSample{{
			Date: "2026-03-02", Group: "早起", Done: []string{"早起"},
			Missed: []string{"跑步"}, Message: "有点累",
		}},
	}
	system, user := Prompts("你是老友", "温和", "想聊聊读书", data)

	if !strings.Contains(system, "你是老友") || !strings.Contains(system, "语气要求") {
		t.Fatalf("system 缺少角色/语气:\n%s", system)
	}
	for _, want := range []string{"今天读完了半本书。", "未完成 跑步", "有点累", "想聊聊读书"} {
		if !strings.Contains(user, want) {
			t.Fatalf("user 缺少 %q，实际:\n%s", want, user)
		}
	}
}

func TestTruncateRunes(t *testing.T) {
	if got := truncate("你好世界", 2); got != "你好…" {
		t.Fatalf("truncate = %q", got)
	}
	if got := truncate("短", 10); got != "短" {
		t.Fatalf("未超限不应加省略号，得到 %q", got)
	}
}

func TestMoodLabel(t *testing.T) {
	happy := "HAPPY"
	if got := moodLabel(&happy); got != "开心" {
		t.Fatalf("moodLabel = %q", got)
	}
	if got := moodLabel(nil); got != "" {
		t.Fatalf("nil 心情应为空，得到 %q", got)
	}
	unknown := "excited"
	if got := moodLabel(&unknown); got != "" {
		t.Fatalf("未知心情应忽略，得到 %q", got)
	}
}
