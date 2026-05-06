package model

import (
	"time"
)

// 漫画总元数据（实时计算，不再依赖 comic_summary 表）
type ComicTotalMetaData struct {
	BookCount         int       `json:"book_count"`
	TotalChapterCount int       `json:"total_chapter_count"`
	TotalImageCount   int       `json:"total_image_count"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// 漫画数据类
// chapter_count 和 image_count 由 SQL 实时聚合，不再存储冗余字段
type ComicInfo struct {
	Id           string `json:"id"`
	Title        string `json:"title"`
	ChapterCount int    `json:"chapter_count"`
	ImageCount   int    `json:"image_count"`
	CoverImage   string `json:"cover_image"`
	IsPublic     bool   `json:"is_public"`
	Readed       bool   `json:"readed"`
}

// 章节数据类
// image_count 由 SQL 实时聚合，不再存储冗余字段
type ChapterInfo struct {
	Id           string      `json:"id"`
	ComicId      string      `json:"comic_id"`
	DirName      string      `json:"dir_name"`
	ChapterIndex int         `json:"chapter_index"`
	ImageCount   int         `json:"image_count"`
	Images       []ImageInfo `json:"images,omitempty"`
}

// 图片信息数据类
type ImageInfo struct {
	Path   string `json:"path"`
	Width  int32  `json:"width"`
	Height int32  `json:"height"`
}

// SyncReadedRequest 同步已读状态请求
type SyncReadedRequest struct {
	ReadedIds []string `json:"readed_ids"` // 标记为已读的漫画ID列表
}

// SyncReadedResponse 同步已读状态响应
type SyncReadedResponse struct {
	UpdatedCount int            `json:"updated_count"`
	NewChapters  map[string]int `json:"new_chapters"` // comic_id → 服务器新增章节数
}

// UpdateComicRequest 更新漫画元数据请求
type UpdateComicRequest struct {
	IsPublic   *bool   `json:"is_public,omitempty"`
	Readed     *bool   `json:"readed,omitempty"`
	CoverImage *string `json:"cover_image,omitempty"`
}
