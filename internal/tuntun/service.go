package tuntun

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"mime"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/google/uuid"
)

// Service 业务逻辑接口
type Service interface {
	SyncMediaFiles(sourceDir, destBaseDir string) error // 同步媒体文件
}

// service 实现Service接口
type service struct {
	repo Repo
}

// NewService 创建Service实例
func NewService(repo Repo) Service {
	return &service{repo: repo}
}

// 支持的媒体文件扩展名
var supportedExts = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".gif":  true,
	".webp": true,
	".mp4":  true,
	".mov":  true,
	".avi":  true,
	".mkv":  true,
}

// SyncMediaFiles 同步媒体文件
func (s *service) SyncMediaFiles(sourceDir, destBaseDir string) error {
	// 验证源目录存在
	if _, err := os.Stat(sourceDir); os.IsNotExist(err) {
		return fmt.Errorf("source directory not exists: %w", err)
	}

	// 确保目标目录存在
	if err := os.MkdirAll(destBaseDir, 0755); err != nil {
		return fmt.Errorf("create dest base dir failed: %w", err)
	}

	// 遍历源目录
	err := filepath.WalkDir(sourceDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return fmt.Errorf("walk path %s failed: %w", path, err)
		}
		if d.IsDir() {
			return nil
		}

		// 过滤支持的扩展名
		ext := strings.ToLower(filepath.Ext(path))
		if !supportedExts[ext] {
			return nil
		}

		// 处理单个文件
		return s.processMediaFile(path, destBaseDir, ext)
	})

	if err != nil {
		return fmt.Errorf("walk source dir failed: %w", err)
	}

	return nil
}

// processMediaFile 处理单个媒体文件
func (s *service) processMediaFile(sourcePath, destBaseDir, ext string) error {
	// 获取文件信息
	fileInfo, err := os.Stat(sourcePath)
	if err != nil {
		return fmt.Errorf("get file info %s failed: %w", sourcePath, err)
	}

	// 计算文件创建时间
	createTime := fileInfo.ModTime().Unix()
	if birthTime, err := getFileBirthTime(sourcePath); err == nil && birthTime.Unix() < createTime {
		createTime = birthTime.Unix()
	}

	// 生成日期范围
	dateRange := time.Unix(createTime, 0).Format("2006_01")

	// 生成目标路径
	destDir := filepath.Join(destBaseDir, dateRange)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("create dest dir %s failed: %w", destDir, err)
	}

	// 生成唯一文件名
	filename := generateUniqueFilename(filepath.Base(sourcePath), sourcePath)
	destPath := filepath.Join(destDir, filename)

	// 检查文件是否已处理
	exists, err := s.repo.IsFileExists(destPath)
	if err != nil {
		return err
	}
	if exists {
		fmt.Printf("file already processed: %s -> %s\n", sourcePath, destPath)
		return nil
	}

	// 拷贝文件
	if err := copyFile(sourcePath, destPath); err != nil {
		return fmt.Errorf("copy file %s -> %s failed: %w", sourcePath, destPath, err)
	}

	// 获取MIME类型
	mimeType := mime.TypeByExtension(ext)
	if mimeType == "" {
		mimeType = getFallbackMimeType(ext)
	}

	// 创建媒体组
	groupID := uuid.New()
	if err := s.repo.CreateMediaGroup(&MediaGroup{
		ID:     groupID,
		Remark: fmt.Sprintf("Auto-created group for %s", dateRange),
	}); err != nil {
		return err
	}

	// 创建默认标签
	defaultTagName := dateRange
	if err := s.repo.CreateTag(&Tag{
		Name:        defaultTagName,
		Description: "Auto-created tag by date",
	}); err != nil {
		return fmt.Errorf("create tag failed: %w", err)
	}

	// 查询标签ID
	tag, err := s.repo.GetTagByName(defaultTagName)
	if err != nil {
		return fmt.Errorf("query tag %s failed: %w", defaultTagName, err)
	}
	if tag == nil {
		return fmt.Errorf("tag %s not found after creation", defaultTagName)
	}

	// 关联组和标签
	if err := s.repo.CreateGroupTag(&GroupTag{
		GroupID: groupID,
		TagID:   tag.ID,
	}); err != nil {
		return fmt.Errorf("bind group and tag failed: %w", err)
	}

	// 入库媒体文件
	mediaFile := &MediaFile{
		FilePath:   destPath,
		Ext:        ext[1:],
		FileSize:   fileInfo.Size(),
		CreateTime: createTime,
		DateRange:  dateRange,
		MimeType:   mimeType,
		GroupID:    groupID,
	}
	if err := s.repo.CreateMediaFile(mediaFile); err != nil {
		os.Remove(destPath)
		return fmt.Errorf("save media file to db failed: %w", err)
	}

	fmt.Printf("successfully processed: %s -> %s\n", sourcePath, destPath)
	return nil
}

// getFileBirthTime 获取文件创建时间
func getFileBirthTime(path string) (time.Time, error) {
	file, err := os.Open(path)
	if err != nil {
		return time.Time{}, err
	}
	defer file.Close()

	fileInfo, err := file.Stat()
	if err != nil {
		return time.Time{}, err
	}

	winFileInfo, ok := fileInfo.Sys().(*syscall.Win32FileAttributeData)
	if !ok {
		return time.Time{}, fmt.Errorf("unsupported file info type")
	}
	creationTime := time.Unix(0, winFileInfo.CreationTime.Nanoseconds())
	return creationTime, nil
}

// generateUniqueFilename 生成唯一文件名
func generateUniqueFilename(originalName, sourcePath string) string {
	file, err := os.Open(sourcePath)
	if err != nil {
		return originalName
	}
	defer file.Close()

	hash := md5.New()
	io.Copy(hash, file)
	md5Str := hex.EncodeToString(hash.Sum(nil))[:8]

	nameWithoutExt := strings.TrimSuffix(originalName, filepath.Ext(originalName))
	return fmt.Sprintf("%s_%s%s", nameWithoutExt, md5Str, filepath.Ext(originalName))
}

// copyFile 拷贝文件
func copyFile(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return err
	}

	srcInfo, err := os.Stat(src)
	if err != nil {
		return err
	}
	return os.Chmod(dst, srcInfo.Mode())
}

// getFallbackMimeType 兜底MIME类型
func getFallbackMimeType(ext string) string {
	switch ext {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".gif":
		return "image/gif"
	case ".webp":
		return "image/webp"
	case ".mp4":
		return "video/mp4"
	case ".mov":
		return "video/quicktime"
	case ".avi":
		return "video/x-msvideo"
	case ".mkv":
		return "video/x-matroska"
	default:
		return "application/octet-stream"
	}
}
