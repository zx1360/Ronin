package model

import (
	"time"

	"github.com/google/uuid"
)

// ComicImage 表示图片元数据
type ComicImage struct {
	ID        string
	ChapterID string
	ImagePath string
	SortNum   int
	Width     int
	Height    int
}

// ComicChapter 表示一个章节目录
type ComicChapter struct {
	ID           string
	ComicID      string
	DirName      string
	ChapterIndex int
	ImageCount   int
	Images       []ComicImage
}

// ComicBook 表示一本漫画（目录名即标题）
type ComicBook struct {
	ID           string
	Title        string
	ChapterCount int
	ImageCount   int
	CoverImage   string
	Chapters     []ComicChapter
}

// ComicSummary 汇总统计
type ComicSummary struct {
	ID                string
	Title             string
	BookCount         int
	TotalChapterCount int
	TotalImageCount   int
	UpdatedAt         time.Time
}

// NewComicBook 创建漫画
func NewComicBook(title string) *ComicBook {
	return &ComicBook{ID: uuid.New().String(), Title: title}
}

// NewComicChapter 创建章节
func NewComicChapter(comicID, dirName string, index int) *ComicChapter {
	return &ComicChapter{ID: uuid.NewString(), ComicID: comicID, DirName: dirName, ChapterIndex: index}
}

// NewComicImage 创建图片
func NewComicImage(chapterID, imagePath string, sortNum int, width, height int) *ComicImage {
	return &ComicImage{ID: uuid.NewString(), ChapterID: chapterID, ImagePath: imagePath, SortNum: sortNum, Width: width, Height: height}
}
