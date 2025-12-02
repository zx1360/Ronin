package comics

import (
	"time"

	"github.com/google/uuid"
)

// ComicImage 漫画图片信息
type ComicImage struct {
	ID        string
	ChapterID string
	ImagePath string
	SortNum   int
	Width     int
	Height    int
}

// ComicChapter 漫画章节信息
type ComicChapter struct {
	ID           string
	ComicID      string
	DirName      string
	ChapterIndex int
	ImageCount   int
	Images       []ComicImage
}

// ComicBook 漫画书籍信息
type ComicBook struct {
	ID           string
	Title        string
	ChapterCount int
	ImageCount   int
	CoverImage   string
	Chapters     []ComicChapter
}

// ComicSummary 漫画汇总信息
type ComicSummary struct {
	ID                string
	Title             string
	BookCount         int
	TotalChapterCount int
	TotalImageCount   int
	UpdatedAt         time.Time
}

// NewComicBook创建新漫画实例
func NewComicBook(title string) *ComicBook {
	return &ComicBook{
		ID:    uuid.New().String(),
		Title: title,
	}
}

// NewComicChapter 创建新章节实例
func NewComicChapter(comicID, dirName string, index int) *ComicChapter {
	return &ComicChapter{
		ID:           uuid.NewString(),
		ComicID:      comicID,
		DirName:      dirName,
		ChapterIndex: index,
	}
}

// NewComicImage 创建新图片实例
func NewComicImage(chapterID, imagePath string, sortNum int, width, height int) *ComicImage {
	return &ComicImage{
		ID:        uuid.NewString(),
		ChapterID: chapterID,
		ImagePath: imagePath,
		SortNum:   sortNum,
		Width:     width,
		Height:    height,
	}
}
