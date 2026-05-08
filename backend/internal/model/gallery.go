package model

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

// FlexTime 自定义时间类型，兼容多种时间格式
type FlexTime time.Time

// UnmarshalJSON 实现 JSON 反序列化，支持多种时间格式
func (ft *FlexTime) UnmarshalJSON(data []byte) error {
	s := strings.Trim(string(data), "\"")
	if s == "null" || s == "" {
		return nil
	}

	// 尝试多种时间格式
	formats := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02T15:04:05.999999999",
		"2006-01-02T15:04:05.999999",
		"2006-01-02T15:04:05",
		"2006-01-02 15:04:05",
	}

	var err error
	var t time.Time
	for _, format := range formats {
		t, err = time.Parse(format, s)
		if err == nil {
			*ft = FlexTime(t)
			return nil
		}
	}
	return err
}

// MarshalJSON 实现 JSON 序列化
func (ft FlexTime) MarshalJSON() ([]byte, error) {
	t := time.Time(ft)
	if t.IsZero() {
		return []byte("null"), nil
	}
	return []byte("\"" + t.Format(time.RFC3339Nano) + "\""), nil
}

// Time 转换为标准 time.Time
func (ft FlexTime) Time() time.Time {
	return time.Time(ft)
}

// Scan 实现 sql.Scanner 接口，用于从数据库读取
func (ft *FlexTime) Scan(value interface{}) error {
	if value == nil {
		*ft = FlexTime(time.Time{})
		return nil
	}
	if t, ok := value.(time.Time); ok {
		*ft = FlexTime(t)
		return nil
	}
	return nil
}

// Value 实现 driver.Valuer 接口，用于写入数据库
func (ft FlexTime) Value() (interface{}, error) {
	t := time.Time(ft)
	if t.IsZero() {
		return nil, nil
	}
	return t, nil
}

// MediaAsset 对应数据库的 media_assets 表
type MediaAsset struct {
	ID          uuid.UUID  `json:"id"`
	CreatedAt   FlexTime   `json:"created_at"`
	UpdatedAt   FlexTime   `json:"updated_at"`
	CapturedAt  FlexTime   `json:"captured_at"`
	FilePath    string     `json:"file_path"`
	ThumbPath   *string    `json:"thumb_path"`
	PreviewPath *string    `json:"preview_path"`
	Hash        []byte     `json:"hash"`
	SizeBytes   int64      `json:"size_bytes"`
	MimeType    *string    `json:"mime_type"`
	IsDeleted   bool       `json:"is_deleted"`
	SyncCount   int        `json:"sync_count"`
	GroupID     *uuid.UUID `json:"group_id"`
	Message     string     `json:"message"`
	EditParams  *string    `json:"edit_params"`
}

// Tag 对应数据库的 tags 表（树状结构）
type Tag struct {
	ID        uuid.UUID  `json:"id"`
	CreatedAt FlexTime   `json:"created_at"`
	UpdatedAt FlexTime   `json:"updated_at"`
	Name      string     `json:"name"`
	ParentID  *uuid.UUID `json:"parent_id"`
	FullPath  string     `json:"full_path"`
}

// MediaTagLink 对应数据库的 media_tag_links 表
type MediaTagLink struct {
	MediaID uuid.UUID `json:"media_id"`
	TagID   uuid.UUID `json:"tag_id"`
}

// GalleryBatchResponse /api/gallery/batch 响应结构
type BatchData struct {
	MediaAssets   []MediaAsset   `json:"media_assets"`
	Tags          []Tag          `json:"tags"`
	MediaTagLinks []MediaTagLink `json:"media_tag_links"`
}

// TagsResponse /api/gallery/tags 响应结构
type TagsResponse struct {
	Tags []Tag `json:"tags"`
}

// PushResponse /api/gallery/push 响应结构
type PushResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}
