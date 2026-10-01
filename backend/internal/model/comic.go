package model

// ComicInfo 漫画概览；chapter_count / image_count 由 SQL 实时聚合。
type ComicInfo struct {
	ID           string `json:"id"`
	Title        string `json:"title"`
	ChapterCount int    `json:"chapter_count"`
	ImageCount   int    `json:"image_count"`
	CoverImage   string `json:"cover_image"`
	IsPublic     bool   `json:"is_public"`
	Readed       bool   `json:"readed"`
}

// ChapterInfo 章节；image_count 由 SQL 实时聚合，Images 仅在下载清单中填充。
type ChapterInfo struct {
	ID           string      `json:"id"`
	ComicID      string      `json:"comic_id"`
	DirName      string      `json:"dir_name"`
	ChapterIndex int         `json:"chapter_index"`
	ImageCount   int         `json:"image_count"`
	Images       []ImageInfo `json:"images,omitempty"`
}

// ImageInfo 章节内的单张图片。
type ImageInfo struct {
	Path   string `json:"path"`
	Width  int32  `json:"width"`
	Height int32  `json:"height"`
}

// UpdateComicRequest 更新漫画元数据请求
type UpdateComicRequest struct {
	IsPublic   *bool   `json:"is_public,omitempty"`
	Readed     *bool   `json:"readed,omitempty"`
	CoverImage *string `json:"cover_image,omitempty"`
}
