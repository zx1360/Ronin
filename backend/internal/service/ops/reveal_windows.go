//go:build windows

package ops

import (
	"os/exec"
	"syscall"
)

// reveal 在资源管理器中选中目标；进程独立于服务生命周期，不等它退出。
func reveal(abs string) error {
	cmd := exec.Command("explorer", "/select,"+abs)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	return cmd.Start()
}
