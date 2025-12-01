package tuntun

import (
	"github.com/google/uuid"
)

// MediaGroup 媒体组模型
type MediaGroup struct {
	ID     uuid.UUID `db:"id"`
	Remark string    `db:"remark"`
}

// Tag 标签模型
type Tag struct {
	ID          uuid.UUID `db:"id"`
	Name        string    `db:"name"`
	Description string    `db:"description"`
}

// GroupTag 组-标签关联模型
type GroupTag struct {
	GroupID uuid.UUID `db:"group_id"`
	TagID   uuid.UUID `db:"tag_id"`
}

// MediaFile 媒体文件模型
type MediaFile struct {
	ID         uuid.UUID `db:"id"`
	FilePath   string    `db:"file_path"`
	Ext        string    `db:"ext"`
	FileSize   int64     `db:"file_size"`
	CreateTime int64     `db:"create_time"` // 时间戳（秒）
	DateRange  string    `db:"date_range"`  // 格式：YYYY_MM
	MimeType   string    `db:"mime_type"`
	GroupID    uuid.UUID `db:"group_id"`
}
