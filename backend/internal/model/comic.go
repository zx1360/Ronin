package model

import (
	"time"
)

// 漫画总元数据
type ComicTotalMetaData struct {
	BookCount         int       `json:"book_count"`
	TotalChapterCount int       `json:"total_chapter_count"`
	TotalImageCount   int       `json:"total_image_count"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// 漫画数据类
type ComicInfo struct {
	Id           string `json:"id"`
	Title        string `json:"title"`
	ChapterCount int    `json:"chapter_count"`
	ImageCount   int    `json:"image_count"`
	CoverImage   string `json:"cover_image"`
}

// 章节数据类
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
