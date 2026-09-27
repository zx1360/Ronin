package model

import (
	"database/sql/driver"
	"fmt"
	"time"
)

// 数据库时间列的统一格式：UTC、毫秒精度、定宽，因此字典序即时序，可直接用于比较与排序。
const (
	TimeFormat = "2006-01-02T15:04:05.000Z"
	DateFormat = "2006-01-02"
)

// FormatTime 把时间归一化为存储格式。
func FormatTime(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.UTC().Format(TimeFormat)
}

// FormatDate 把时间归一化为日期列格式。
func FormatDate(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.UTC().Format(DateFormat)
}

// Now 返回当前时间的存储格式。
func Now() string { return FormatTime(time.Now()) }

// ParseTime 解析数据库中的时间文本，兼容历史上写过的 RFC3339 变体。
func ParseTime(s string) (time.Time, error) {
	if s == "" {
		return time.Time{}, nil
	}
	for _, layout := range []string{
		TimeFormat,
		time.RFC3339Nano,
		time.RFC3339,
		DateFormat,
		"2006-01-02 15:04:05",
	} {
		if t, err := time.Parse(layout, s); err == nil {
			return t.UTC(), nil
		}
	}
	return time.Time{}, fmt.Errorf("无法解析时间: %q", s)
}

// Ptr 返回 v 的指针，便于构造可空列参数。
func Ptr[T any](v T) *T { return &v }

// FlexTime 包装 time.Time：JSON 侧兼容多种时间格式，数据库侧负责与存储格式互转。
type FlexTime time.Time

// Time 返回底层 time.Time。
func (ft FlexTime) Time() time.Time { return time.Time(ft) }

// UnmarshalJSON 实现 JSON 反序列化，支持多种时间格式（客户端序列化格式不统一）。
func (ft *FlexTime) UnmarshalJSON(data []byte) error {
	s := trimJSONString(data)
	if s == "null" || s == "" {
		return nil
	}
	t, err := ParseTime(s)
	if err != nil {
		return err
	}
	*ft = FlexTime(t)
	return nil
}

// MarshalJSON 实现 JSON 序列化，统一输出为存储格式。
func (ft FlexTime) MarshalJSON() ([]byte, error) {
	t := time.Time(ft)
	if t.IsZero() {
		return []byte("null"), nil
	}
	return []byte(`"` + FormatTime(t) + `"`), nil
}

// Scan 实现 sql.Scanner：SQLite 返回 TEXT，迁移路径上可能仍是 time.Time。
func (ft *FlexTime) Scan(value interface{}) error {
	switch v := value.(type) {
	case nil:
		*ft = FlexTime(time.Time{})
		return nil
	case time.Time:
		*ft = FlexTime(v.UTC())
		return nil
	case string:
		t, err := ParseTime(v)
		if err != nil {
			return err
		}
		*ft = FlexTime(t)
		return nil
	case []byte:
		t, err := ParseTime(string(v))
		if err != nil {
			return err
		}
		*ft = FlexTime(t)
		return nil
	default:
		return fmt.Errorf("FlexTime 不支持的类型: %T", value)
	}
}

// Value 实现 driver.Valuer：写库统一为存储格式的 TEXT。
func (ft FlexTime) Value() (driver.Value, error) {
	t := time.Time(ft)
	if t.IsZero() {
		return nil, nil
	}
	return FormatTime(t), nil
}

// trimJSONString 去掉 JSON 字符串两侧的引号。
func trimJSONString(data []byte) string {
	s := string(data)
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		return s[1 : len(s)-1]
	}
	return s
}
