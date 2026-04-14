// Package scanner 负责文件扫描、哈希计算和元信息提取
package scanner

import (
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/rwcarlsen/goexif/exif"

	"gizmos/internal/gallery/model"
)

// Scanner 文件扫描器
type Scanner struct {
	rootDir string
}

// NewScanner 创建新的扫描器
func NewScanner(rootDir string) *Scanner {
	return &Scanner{rootDir: rootDir}
}

// ScanDir 扫描目录，返回所有支持的媒体文件信息通道
func (s *Scanner) ScanDir() (<-chan string, <-chan error) {
	pathChan := make(chan string, 100)
	errChan := make(chan error, 10)

	go func() {
		defer close(pathChan)
		defer close(errChan)

		err := filepath.Walk(s.rootDir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				errChan <- fmt.Errorf("访问路径 %s 失败: %w", path, err)
				return nil // 继续遍历其他文件
			}

			if info.IsDir() {
				return nil
			}

			ext := strings.ToLower(filepath.Ext(path))
			if model.IsSupportedFile(ext) {
				pathChan <- path
			}

			return nil
		})

		if err != nil {
			errChan <- fmt.Errorf("遍历目录失败: %w", err)
		}
	}()

	return pathChan, errChan
}

// ExtractFileInfo 提取文件信息
func (s *Scanner) ExtractFileInfo(filePath string) (*model.FileInfo, error) {
	// 获取文件信息
	stat, err := os.Stat(filePath)
	if err != nil {
		return nil, fmt.Errorf("获取文件信息失败: %w", err)
	}

	ext := strings.ToLower(filepath.Ext(filePath))
	fileName := filepath.Base(filePath)

	// 计算文件哈希
	hash, err := s.calculateHash(filePath)
	if err != nil {
		return nil, fmt.Errorf("计算文件哈希失败: %w", err)
	}

	// 获取文件日期（优先级: EXIF > 修改时间 > 创建时间）
	capturedAt := s.extractCapturedAt(filePath, stat)

	// 判断文件类型
	isVideo := model.IsVideo(ext)
	isAnimated := model.IsAnimatedImage(ext)
	mimeType := model.GetMimeType(ext)

	return &model.FileInfo{
		OriginalPath: filePath,
		FileName:     fileName,
		Extension:    ext,
		SizeBytes:    stat.Size(),
		Hash:         hash,
		MimeType:     mimeType,
		CapturedAt:   capturedAt,
		IsVideo:      isVideo,
		IsAnimated:   isAnimated,
	}, nil
}

// calculateHash 计算文件的 SHA-256 哈希
func (s *Scanner) calculateHash(filePath string) ([]byte, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return nil, err
	}

	return hasher.Sum(nil), nil
}

// extractCapturedAt 提取文件日期
// 优先级: EXIF 拍摄时间 > min(修改时间, 创建时间)
func (s *Scanner) extractCapturedAt(filePath string, stat os.FileInfo) time.Time {
	ext := strings.ToLower(filepath.Ext(filePath))

	// 尝试从 EXIF 提取（仅支持图片）
	if model.SupportedImageExts[ext] && !model.IsVideo(ext) {
		if exifTime, err := s.extractExifTime(filePath); err == nil && !exifTime.IsZero() {
			return exifTime
		}
	}

	// 获取修改时间
	modTime := stat.ModTime()

	// 获取创建时间（Windows 特有）
	createTime := getCreationTime(stat)

	// 返回较早的时间
	if createTime.Before(modTime) && !createTime.IsZero() {
		return createTime
	}
	return modTime
}

// extractExifTime 从 EXIF 数据提取拍摄时间
func (s *Scanner) extractExifTime(filePath string) (time.Time, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return time.Time{}, err
	}
	defer file.Close()

	x, err := exif.Decode(file)
	if err != nil {
		return time.Time{}, err
	}

	// 尝试获取原始拍摄时间
	dt, err := x.DateTime()
	if err == nil {
		return dt, nil
	}

	return time.Time{}, err
}
