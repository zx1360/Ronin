//go:build !windows
// +build !windows

package scanner

import (
	"os"
	"time"
)

// getCreationTime 获取文件创建时间 (非 Windows 系统回退到修改时间)
func getCreationTime(stat os.FileInfo) time.Time {
	return stat.ModTime()
}
