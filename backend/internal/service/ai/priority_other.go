//go:build !windows

package ai

// yieldToInteractive 在非 Windows 平台上不做处理。
//
// 该优化针对"AI 批处理与前台 UI 争抢 CPU"的 Windows 桌面场景；
// 其它平台交由调度器默认策略处理。
func yieldToInteractive(pid int) error { return nil }
