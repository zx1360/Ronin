package model

import (
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
)

// ============================================================================
// 自定义类型
// ============================================================================

// FlexYear 兼容 JSON 中字符串和整数形式的年份
// 反序列化时接受 "2024" 或 2024，序列化时输出字符串（兼容 Android）
type FlexYear int

func (y FlexYear) MarshalJSON() ([]byte, error) {
	return []byte(fmt.Sprintf(`"%d"`, y)), nil
}

func (y *FlexYear) UnmarshalJSON(data []byte) error {
	// 尝试字符串
	var s string
	if err := json.Unmarshal(data, &s); err == nil {
		n, err := strconv.Atoi(s)
		if err != nil {
			return fmt.Errorf("无效的年份字符串: %s", s)
		}
		*y = FlexYear(n)
		return nil
	}
	// 尝试整数
	var n int
	if err := json.Unmarshal(data, &n); err != nil {
		return fmt.Errorf("无效的年份值: %s", string(data))
	}
	*y = FlexYear(n)
	return nil
}

// ============================================================================
// Essay 相关模型
// ============================================================================

// EssayArticle 对应 user_data.essay_articles 表
type EssayArticle struct {
	ID        uuid.UUID       `json:"id"`
	Date      time.Time       `json:"date"`
	WordCount int             `json:"word_count"`
	Content   string          `json:"content"`
	Imgs      []string        `json:"imgs"`
	Labels    []string        `json:"labels"`
	Messages  json.RawMessage `json:"messages"` // JSONB
	Mood      *string         `json:"mood"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`
}

// EssayLabel 对应 user_data.essay_labels 表
type EssayLabel struct {
	ID         uuid.UUID `json:"id"`
	Name       string    `json:"name"`
	EssayCount int       `json:"essay_count"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// EssayYearSummary 对应 user_data.essay_year_summaries 表
type EssayYearSummary struct {
	Year           FlexYear        `json:"year"`
	EssayCount     int             `json:"essay_count"`
	WordCount      int             `json:"word_count"`
	MonthSummaries json.RawMessage `json:"month_summaries"` // JSONB
	UpdatedAt      time.Time       `json:"updated_at"`
}

// ============================================================================
// Booklet 相关模型
// ============================================================================

// BookletStyle 对应 user_data.booklet_styles 表
type BookletStyle struct {
	ID                 uuid.UUID       `json:"id"`
	StartDate          time.Time       `json:"start_date"`
	ValidCheckIn       int             `json:"valid_check_in"`
	FullyDone          int             `json:"fully_done"`
	LongestStreak      int             `json:"longest_streak"`
	LongestFullyStreak int             `json:"longest_fully_streak"`
	Tasks              json.RawMessage `json:"tasks"` // JSONB
	CreatedAt          time.Time       `json:"created_at"`
	UpdatedAt          time.Time       `json:"updated_at"`
}

// BookletRecord 对应 user_data.booklet_records 表
type BookletRecord struct {
	ID             uuid.UUID       `json:"id"`
	StyleID        uuid.UUID       `json:"style_id"`
	Date           time.Time       `json:"date"`
	Message        string          `json:"message"`
	TaskCompletion json.RawMessage `json:"task_completion"` // JSONB
	Mood           *string         `json:"mood"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
}
