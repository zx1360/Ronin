package ai_handler

import (
	"testing"
	"time"
)

func TestReviewScope(t *testing.T) {
	today := time.Now().In(time.Local).Format("2006-01-02")

	t.Run("全缺省取最近30天到今天", func(t *testing.T) {
		scope, err := reviewScope(reviewRequest{})
		if err != nil {
			t.Fatalf("默认范围应合法: %v", err)
		}
		if scope.Days() != reviewDefaultDays {
			t.Fatalf("Days = %d, want %d", scope.Days(), reviewDefaultDays)
		}
		if got := scope.To.Format("2006-01-02"); got != today {
			t.Fatalf("To = %s, want %s", got, today)
		}
	})

	t.Run("只给to时按days回溯", func(t *testing.T) {
		scope, err := reviewScope(reviewRequest{To: "2026-03-10", Days: 7})
		if err != nil {
			t.Fatalf("应合法: %v", err)
		}
		if got := scope.From.Format("2006-01-02"); got != "2026-03-04" {
			t.Fatalf("From = %s, want 2026-03-04", got)
		}
	})

	t.Run("显式from优先于days", func(t *testing.T) {
		scope, err := reviewScope(reviewRequest{From: "2026-01-01", To: "2026-03-10", Days: 7})
		if err != nil {
			t.Fatalf("应合法: %v", err)
		}
		if got := scope.From.Format("2006-01-02"); got != "2026-01-01" {
			t.Fatalf("From = %s, want 2026-01-01", got)
		}
	})

	t.Run("非法输入", func(t *testing.T) {
		cases := map[string]reviewRequest{
			"日期格式错":  {From: "2026/01/01"},
			"from晚于to": {From: "2026-03-10", To: "2026-03-01"},
			"days超上限": {Days: reviewMaxDays + 1},
			"days为负":  {Days: -1},
		}
		for name, req := range cases {
			if _, err := reviewScope(req); err == nil {
				t.Fatalf("%s 应被拒绝", name)
			}
		}
	})
}

func TestSampleCount(t *testing.T) {
	three := 3
	if got, err := sampleCount("sample_essays", &three, 1, 20); err != nil || got != 3 {
		t.Fatalf("正常取值失败: %v %d", err, got)
	}
	if got, err := sampleCount("sample_essays", nil, 1, 20); err != nil || got != 1 {
		t.Fatalf("缺省应取默认值: %v %d", err, got)
	}
	zero := 0
	if got, err := sampleCount("sample_essays", &zero, 1, 20); err != nil || got != 0 {
		t.Fatalf("0 表示不抽样，应被接受: %v %d", err, got)
	}
	over, negative := 21, -1
	if _, err := sampleCount("sample_essays", &over, 1, 20); err == nil {
		t.Fatal("超上限应报错而不是静默夹取")
	}
	if _, err := sampleCount("sample_essays", &negative, 1, 20); err == nil {
		t.Fatal("负数应报错")
	}
}
