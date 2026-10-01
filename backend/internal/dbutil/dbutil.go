// Package dbutil 收纳 SQLite 存储层的取值约定：时间文本、占位符与忙等判定。
//
// 时间列统一存本机本地时区的定宽文本 'YYYY-MM-DD HH:MM:SS.mmm'（毫秒，无时区后缀）：
// 字典序即时间序，SQLite 的 date()/strftime() 可直接解析。
package dbutil

import (
	"fmt"
	"strings"
	"time"
)

// TimeLayout 时间列的存储格式（定宽毫秒）。
const TimeLayout = "2006-01-02 15:04:05.000"

// 兼容解析：SQLite 默认时间函数（strftime/date）产生的格式与历史数据。
var parseLayouts = []string{
	TimeLayout,
	"2006-01-02 15:04:05.000000",
	"2006-01-02 15:04:05",
	"2006-01-02T15:04:05.000Z07:00",
	time.RFC3339Nano,
}

// TS 把时间格式化为存储文本（零值返回空串，由调用方决定是否写 NULL）。
func TS(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.Local().Format(TimeLayout)
}

// ParseTS 解析存储文本为本地时间；空串返回零值。
func ParseTS(raw string) (time.Time, error) {
	s := strings.TrimSpace(raw)
	if s == "" {
		return time.Time{}, nil
	}
	for _, layout := range parseLayouts {
		if t, err := time.ParseInLocation(layout, s, time.Local); err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("时间格式无法解析: %q", raw)
}

// Time 解析存储文本；失败时返回零值（用于 Scan，避免整行读取失败）。
func Time(raw string) time.Time {
	t, err := ParseTS(raw)
	if err != nil {
		return time.Time{}
	}
	return t
}

// Date 解析日期列（存储为 'YYYY-MM-DD'），返回 UTC 零点。
//
// 固定 UTC 零点是个不变量：上游据此用 .UTC().Format("2006-01-02") 还原日历日期，
// 改成本地零点会让所有按日聚合的结果整体错一天。
func Date(raw string) time.Time {
	s := strings.TrimSpace(raw)
	if s == "" {
		return time.Time{}
	}
	if t, err := time.ParseInLocation("2006-01-02", s, time.UTC); err == nil {
		return t
	}
	return Time(s)
}

// Placeholders 生成 n 个逗号分隔的 `?` 占位符（n<=0 时返回 NULL，使 IN 子句恒为空集）。
func Placeholders(n int) string {
	if n <= 0 {
		return "NULL"
	}
	return strings.TrimSuffix(strings.Repeat("?,", n), ",")
}

// IsBusy 报告错误是否为 SQLite 写锁竞争（单写者模型下需退避重试）。
func IsBusy(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "database is locked") ||
		strings.Contains(msg, "database table is locked") ||
		strings.Contains(msg, "sqlite_busy") ||
		strings.Contains(msg, "database is busy")
}
