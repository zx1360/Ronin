package utils

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/disintegration/imaging"
)

// ImageSavePath 定义图片存储的根路径
const ImageSavePath = "./uploads/images"

// InitStorage 初始化存储目录
func InitStorage() error {
	return os.MkdirAll(ImageSavePath, os.ModePerm)
}

// SaveImage 保存并处理上传的图片
// 返回保存后的文件名和错误
func SaveImage(fileName string, file io.Reader) (string, error) {
	if fileName == "" {
		return "", errors.New("文件名不能为空")
	}

	// 确保目录存在
	if err := InitStorage(); err != nil {
		return "", err
	}

	// 构建完整路径
	savePath := filepath.Join(ImageSavePath, fileName)

	// 检查文件是否已存在，如果存在则删除
	if _, err := os.Stat(savePath); err == nil {
		if err := os.Remove(savePath); err != nil {
			return "", fmt.Errorf("无法删除已存在的文件: %v", err)
		}
	}

	// 创建目标文件
	out, err := os.Create(savePath)
	if err != nil {
		return "", err
	}
	defer out.Close()

	// 使用 imaging 库来解码、处理（例如 resize）并保存图片，这更健壮
	img, err := imaging.Decode(file)
	if err != nil {
		return "", fmt.Errorf("无法解码图片: %v", err)
	}

	// 可以在这里对图片进行处理，例如压缩尺寸
	// img = imaging.Resize(img, 800, 0, imaging.Lanczos)

	err = imaging.Save(img, savePath)
	if err != nil {
		return "", err
	}

	return fileName, nil
}

// DeleteImage 删除指定的图片文件
func DeleteImage(fileName string) error {
	if fileName == "" {
		return errors.New("文件名不能为空")
	}
	filePath := filepath.Join(ImageSavePath, fileName)
	return os.Remove(filePath)
}

// GetImageURL 返回图片的URL路径（相对路径）
func GetImageURL(fileName string) string {
	if fileName == "" {
		return ""
	}
	// 假设图片通过 /images/ 路由对外提供访问
	return fmt.Sprintf("/images/%s", fileName)
}
