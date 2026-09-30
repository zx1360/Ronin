// Package dbutil 提供 SQLite 存储层的取值约定（与 Monarch 侧 internal/dbutil 同源，
// gizmos 为独立 Go module，故各持一份）。
//
// 时间列统一存本机本地时区的定宽文本 'YYYY-MM-DD HH:MM:SS.mmm'（毫秒，无时区后缀）。
package dbutil

import (
	"strings"
	"time"
)

// TimeLayout 时间列的存储格式（定宽毫秒）。
const TimeLayout = "2006-01-02 15:04:05.000"

var parseLayouts = []string{
	TimeLayout,
	"2006-01-02 15:04:05.000000",
	"2006-01-02 15:04:05",
}

// TS 把时间格式化为存储文本。
func TS(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.Local().Format(TimeLayout)
}

// Time 解析存储文本为本地时间；非法内容返回零值。
func Time(raw string) time.Time {
	s := strings.TrimSpace(raw)
	if s == "" {
		return time.Time{}
	}
	for _, layout := range parseLayouts {
		if t, err := time.ParseInLocation(layout, s, time.Local); err == nil {
			return t
		}
	}
	return time.Time{}
}

// Placeholders 生成 n 个逗号分隔的 `?`（n<=0 时返回 NULL）。
func Placeholders(n int) string {
	if n <= 0 {
		return "NULL"
	}
	return strings.TrimSuffix(strings.Repeat("?,", n), ",")
}
