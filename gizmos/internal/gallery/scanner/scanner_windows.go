//go:build windows
// +build windows

package scanner

import (
	"os"
	"syscall"
	"time"
)

// getCreationTime 获取文件创建时间 (Windows 特有)
func getCreationTime(stat os.FileInfo) time.Time {
	if sys := stat.Sys(); sys != nil {
		if winStat, ok := sys.(*syscall.Win32FileAttributeData); ok {
			nsec := winStat.CreationTime.Nanoseconds()
			return time.Unix(0, nsec)
		}
	}
	return stat.ModTime()
}
