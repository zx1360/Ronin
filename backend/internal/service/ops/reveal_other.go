//go:build !windows

package ops

import (
	"fmt"
	"os/exec"
	"runtime"
)

// reveal 在非 Windows 平台打开所在目录（仅支持 macOS 与常见的 Linux 文件管理器）。
func reveal(abs string) error {
	dir := abs
	switch runtime.GOOS {
	case "darwin":
		return exec.Command("open", "-R", dir).Start()
	default:
		return fmt.Errorf("当前平台不支持在文件管理器中定位路径")
	}
}
