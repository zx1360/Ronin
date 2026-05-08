// Package model 定义媒体文件相关的数据结构
package model

import (
	"time"

	"github.com/google/uuid"
)

// MediaAsset 媒体文件实体，对应数据库 media_assets 表
type MediaAsset struct {
	ID          uuid.UUID  `json:"id"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	CapturedAt  time.Time  `json:"captured_at"`  // 文件日期（优先级: EXIF > 修改时间 > 创建时间）
	FilePath    string     `json:"file_path"`    // 存储中的相对路径
	ThumbPath   *string    `json:"thumb_path"`   // 缩略图相对路径
	PreviewPath *string    `json:"preview_path"` // 预览图相对路径
	Hash        []byte     `json:"hash"`         // SHA-256 哈希
	SizeBytes   int64      `json:"size_bytes"`   // 文件大小
	MimeType    *string    `json:"mime_type"`    // MIME 类型
	IsDeleted   bool       `json:"is_deleted"`   // 是否已删除
	SyncCount   int        `json:"sync_count"`   // 同步次数
	GroupID     *uuid.UUID `json:"group_id"`     // 捆绑组主文件 ID
	EditParams  *string    `json:"edit_params"`  // 编辑参数 JSON
}

// FileInfo 文件扫描时的临时信息结构
type FileInfo struct {
	OriginalPath string    // 原始文件路径
	FileName     string    // 文件名
	Extension    string    // 扩展名（小写，含点）
	SizeBytes    int64     // 文件大小
	Hash         []byte    // SHA-256 哈希
	MimeType     string    // MIME 类型
	CapturedAt   time.Time // 文件日期
	IsVideo      bool      // 是否为视频
	IsAnimated   bool      // 是否为动态图（如 GIF）
}

// ProcessResult 处理结果
type ProcessResult struct {
	Asset       *MediaAsset // 生成的媒体资产
	Error       error       // 处理错误
	IsDuplicate bool        // 是否重复文件
}

// SupportedImageExts 支持的图片扩展名
var SupportedImageExts = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".webp": true,
	".gif":  true,
	".bmp":  true,
	".tiff": true,
	".tif":  true,
	".heic": true,
	".heif": true,
	".avif": true,
}

// SupportedVideoExts 支持的视频扩展名
var SupportedVideoExts = map[string]bool{
	".mp4":  true,
	".mov":  true,
	".avi":  true,
	".mkv":  true,
	".wmv":  true,
	".flv":  true,
	".webm": true,
	".m4v":  true,
	".3gp":  true,
	".ts":   true,
}

// AnimatedImageExts 动态图片扩展名
var AnimatedImageExts = map[string]bool{
	".gif":  true,
	".webp": true, // WebP 可能是动态的，需要进一步检测
	".apng": true,
}

// ExtToMimeType 扩展名到 MIME 类型映射
var ExtToMimeType = map[string]string{
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".png":  "image/png",
	".webp": "image/webp",
	".gif":  "image/gif",
	".bmp":  "image/bmp",
	".tiff": "image/tiff",
	".tif":  "image/tiff",
	".heic": "image/heic",
	".heif": "image/heif",
	".avif": "image/avif",
	".mp4":  "video/mp4",
	".mov":  "video/quicktime",
	".avi":  "video/x-msvideo",
	".mkv":  "video/x-matroska",
	".wmv":  "video/x-ms-wmv",
	".flv":  "video/x-flv",
	".webm": "video/webm",
	".m4v":  "video/x-m4v",
	".3gp":  "video/3gpp",
	".ts":   "video/mp2t",
}

// IsSupportedFile 检查文件扩展名是否支持
func IsSupportedFile(ext string) bool {
	return SupportedImageExts[ext] || SupportedVideoExts[ext]
}

// IsVideo 检查扩展名是否为视频
func IsVideo(ext string) bool {
	return SupportedVideoExts[ext]
}

// IsAnimatedImage 检查是否可能为动态图片
func IsAnimatedImage(ext string) bool {
	return AnimatedImageExts[ext]
}

// GetMimeType 根据扩展名获取 MIME 类型
func GetMimeType(ext string) string {
	if mime, ok := ExtToMimeType[ext]; ok {
		return mime
	}
	return "application/octet-stream"
}
