package model

import (
	"time"

	"github.com/google/uuid"
)

// MediaAsset 对应数据库的 media_assets 表
type MediaAsset struct {
	ID          uuid.UUID  `json:"id"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	CapturedAt  time.Time  `json:"captured_at"`
	FilePath    string     `json:"file_path"`
	ThumbPath   *string    `json:"thumb_path"`
	PreviewPath *string    `json:"preview_path"`
	Hash        []byte     `json:"hash"`
	SizeBytes   int64      `json:"size_bytes"`
	MimeType    *string    `json:"mime_type"`
	IsDeleted   bool       `json:"is_deleted"`
	SyncCount   int        `json:"sync_count"`
	GroupID     *uuid.UUID `json:"group_id"`
}

// Tag 对应数据库的 tags 表（树状结构）
type Tag struct {
	ID        uuid.UUID  `json:"id"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
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

// PushResponse /api/gallery/push 响应结构
type PushResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}
