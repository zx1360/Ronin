//go:build windows

package ai

import "syscall"

const (
	// PROCESS_SET_INFORMATION 打开进程句柄所需的最小权限。
	processSetInformation = 0x0200
	// belowNormalPriorityClass Windows 进程优先级类的"低于正常"档。
	belowNormalPriorityClass = 0x00004000
)

var procSetPriorityClass = syscall.NewLazyDLL("kernel32.dll").NewProc("SetPriorityClass")

// yieldToInteractive 把子进程降为"低于正常"优先级。
//
// AI 批处理是长时间吃满 CPU 的任务，而它跑在用户自己的 PC 上：不降优先级时，
// 前台交互（桌面端 UI、浏览器）会和它平权争抢核心，表现为界面发卡。
// 降一档后调度器始终优先满足前台，代价只是批处理在机器忙时慢一点。
//
// 失败只返回错误供调用方记录，不影响进程本身（优先级只是优化项）。
func yieldToInteractive(pid int) error {
	if pid <= 0 {
		return nil
	}
	handle, err := syscall.OpenProcess(processSetInformation, false, uint32(pid))
	if err != nil {
		return err
	}
	defer syscall.CloseHandle(handle)

	ret, _, callErr := procSetPriorityClass.Call(uintptr(handle), belowNormalPriorityClass)
	if ret == 0 {
		return callErr
	}
	return nil
}
