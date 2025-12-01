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

// SyncMediaFiles 同步媒体文件：检索、迁移、入库
func (s *service) SyncMediaFiles(sourceDir, destBaseDir string) error {
	// 1. 验证源目录存在
	if _, err := os.Stat(sourceDir); os.IsNotExist(err) {
		return fmt.Errorf("source directory not exists: %w", err)
	}

	// 2. 确保目标目录基础路径存在
	if err := os.MkdirAll(destBaseDir, 0755); err != nil {
		return fmt.Errorf("create dest base dir failed: %w", err)
	}

	// 3. 遍历源目录所有文件
	err := filepath.WalkDir(sourceDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return fmt.Errorf("walk path %s failed: %w", path, err)
		}

		// 跳过目录
		if d.IsDir() {
			return nil
		}

		// 过滤支持的媒体文件
		ext := strings.ToLower(filepath.Ext(path))
		if !supportedExts[ext] {
			return nil
		}

		// 处理单个媒体文件
		return s.processMediaFile(path, destBaseDir, ext)
	})

	if err != nil {
		return fmt.Errorf("walk source dir failed: %w", err)
	}

	return nil
}

// processMediaFile 处理单个媒体文件：获取信息、迁移、入库
func (s *service) processMediaFile(sourcePath, destBaseDir, ext string) error {
	// 1. 获取文件信息
	fileInfo, err := os.Stat(sourcePath)
	if err != nil {
		return fmt.Errorf("get file info %s failed: %w", sourcePath, err)
	}

	// 2. 计算文件创建时间（取创建时间和修改时间的较早值）
	createTime := fileInfo.ModTime().Unix()
	if birthTime, err := getFileBirthTime(sourcePath); err == nil && birthTime.Unix() < createTime {
		createTime = birthTime.Unix()
	}

	// 3. 生成日期范围（YYYY_MM）
	dateRange := time.Unix(createTime, 0).Format("2006_01")

	// 4. 生成目标路径（避免文件名冲突）
	destDir := filepath.Join(destBaseDir, dateRange)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("create dest dir %s failed: %w", destDir, err)
	}

	// 生成唯一文件名（原文件名+MD5前8位）
	filename := generateUniqueFilename(filepath.Base(sourcePath), sourcePath)
	destPath := filepath.Join(destDir, filename)

	// 5. 检查文件是否已处理过
	exists, err := s.repo.IsFileExists(destPath)
	if err != nil {
		return err
	}
	if exists {
		fmt.Printf("file already processed: %s -> %s\n", sourcePath, destPath)
		// 可选：删除原文件（当前注释）
		// return os.Remove(sourcePath)
		return nil
	}

	// 6. 拷贝文件到目标路径
	if err := copyFile(sourcePath, destPath); err != nil {
		return fmt.Errorf("copy file %s -> %s failed: %w", sourcePath, destPath, err)
	}

	// 7. 获取MIME类型
	mimeType := mime.TypeByExtension(ext)
	if mimeType == "" {
		mimeType = getFallbackMimeType(ext)
	}

	// 8. 创建默认媒体组（可根据实际需求修改分组逻辑）
	groupID := uuid.New()
	if err := s.repo.CreateMediaGroup(&MediaGroup{
		ID:     groupID,
		Remark: fmt.Sprintf("Auto-created group for %s", dateRange),
	}); err != nil {
		return err
	}

	// 9. （可选）创建默认标签并关联（修复后逻辑）
	defaultTagName := dateRange
	defaultTagDesc := "Auto-created tag by date"

	// 先创建标签（已存在则忽略）
	if err := s.repo.CreateTag(&Tag{
		Name:        defaultTagName,
		Description: defaultTagDesc,
	}); err != nil {
		return fmt.Errorf("create tag failed: %w", err)
	}

	// 重新查询标签（确保获取到正确的ID）
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

	// 10. 入库媒体文件记录
	mediaFile := &MediaFile{
		FilePath:   destPath,
		Ext:        ext[1:], // 去掉前缀点（如jpg而不是.jpg）
		FileSize:   fileInfo.Size(),
		CreateTime: createTime,
		DateRange:  dateRange,
		MimeType:   mimeType,
		GroupID:    groupID,
	}
	if err := s.repo.CreateMediaFile(mediaFile); err != nil {
		// 入库失败，删除已拷贝的文件
		os.Remove(destPath)
		return fmt.Errorf("save media file to db failed: %w", err)
	}

	// 11. （可选）删除原文件（当前注释，正式使用时取消注释）
	// if err := os.Remove(sourcePath); err != nil {
	//     return fmt.Errorf("delete source file %s failed: %w", sourcePath, err)
	// }

	fmt.Printf("successfully processed: %s -> %s\n", sourcePath, destPath)
	return nil
}

// getFileBirthTime 获取文件创建时间（跨平台兼容）
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
		return time.Time{}, fmt.Errorf("unsupported file info type for windows")
	}
	// Win32FileAttributeData.CreationTime 是FILETIME类型（100纳秒为单位，从1601-01-01开始）
	creationTime := time.Unix(0, winFileInfo.CreationTime.Nanoseconds())
	return creationTime, nil
}

// generateUniqueFilename 生成唯一文件名（原文件名+MD5前8位）
func generateUniqueFilename(originalName, sourcePath string) string {
	// 计算文件MD5
	file, err := os.Open(sourcePath)
	if err != nil {
		return originalName
	}
	defer file.Close()

	hash := md5.New()
	io.Copy(hash, file)
	md5Str := hex.EncodeToString(hash.Sum(nil))[:8]

	// 拼接文件名：原文件名（去掉扩展名）+ MD5 + 扩展名
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

	// 保留原文件权限
	srcInfo, err := os.Stat(src)
	if err != nil {
		return err
	}
	return os.Chmod(dst, srcInfo.Mode())
}

// getFallbackMimeType 为未知扩展名提供默认MIME类型
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
