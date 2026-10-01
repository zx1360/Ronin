package taskengine

import (
	"errors"
	"runtime"
	"strings"
	"testing"
	"time"
)

// 引擎行为测试依赖 cmd.exe 与 ping（Windows）；其它平台跳过。
func requireWindows(t *testing.T) {
	t.Helper()
	if runtime.GOOS != "windows" {
		t.Skip("任务引擎测试依赖 Windows 命令")
	}
}

// waitFor 等待任务离开 running 状态。
func waitFor(t *testing.T, m *Manager, id string, timeout time.Duration) *Task {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		task, err := m.Get(id)
		if err != nil {
			t.Fatalf("获取任务失败: %v", err)
		}
		if task.Status != StatusRunning {
			return task
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("任务 %s 在 %s 内未结束", id, timeout)
	return nil
}

func TestStartStreamsOutputAndFinishes(t *testing.T) {
	requireWindows(t)
	m := NewManager(50, 5)

	task, err := m.Start(Spec{
		Name:         "echo",
		Exe:          "cmd.exe",
		Args:         []string{"/c", "echo hello && echo warning 1>&2"},
		StreamStdout: true,
	})
	if err != nil {
		t.Fatalf("启动失败: %v", err)
	}

	finished := waitFor(t, m, task.ID, 20*time.Second)
	if finished.Status != StatusFinished {
		t.Fatalf("状态应为 finished，实际 %s（error=%s）", finished.Status, finished.Error)
	}
	if finished.ExitCode != nil {
		t.Fatalf("退出码为 0 时不应记录: %v", *finished.ExitCode)
	}

	var stdout, stderr bool
	for _, entry := range finished.Logs {
		if entry.Stream == "stdout" && strings.Contains(entry.Text, "hello") {
			stdout = true
		}
		if entry.Stream == "stderr" && strings.Contains(entry.Text, "warning") {
			stderr = true
		}
	}
	if !stdout || !stderr {
		t.Fatalf("stdout/stderr 未完整收集: stdout=%v stderr=%v", stdout, stderr)
	}
	if !strings.Contains(finished.Command, "cmd.exe") {
		t.Fatalf("命令行应包含可执行文件名: %q", finished.Command)
	}
}

func TestNonZeroExitIsFailure(t *testing.T) {
	requireWindows(t)
	m := NewManager(50, 5)

	task, err := m.Start(Spec{Name: "fail", Exe: "cmd.exe", Args: []string{"/c", "exit 3"}})
	if err != nil {
		t.Fatalf("启动失败: %v", err)
	}

	finished := waitFor(t, m, task.ID, 20*time.Second)
	if finished.Status != StatusFailed {
		t.Fatalf("状态应为 failed，实际 %s", finished.Status)
	}
	if finished.ExitCode == nil || *finished.ExitCode != 3 {
		t.Fatalf("应记录非零退出码 3，实际 %v", finished.ExitCode)
	}
	if !strings.Contains(finished.Error, "exit 3") {
		t.Fatalf("失败原因应包含退出码: %q", finished.Error)
	}
}

func TestParseErrorMarksFailed(t *testing.T) {
	requireWindows(t)
	m := NewManager(50, 5)

	task, err := m.Start(Spec{
		Name: "parse",
		Exe:  "cmd.exe",
		Args: []string{"/c", "echo not-json"},
		Parse: func(stdout, stderr string, exitCode int, runErr error) (any, error) {
			return nil, errors.New("输出解析失败")
		},
	})
	if err != nil {
		t.Fatalf("启动失败: %v", err)
	}

	finished := waitFor(t, m, task.ID, 20*time.Second)
	if finished.Status != StatusFailed || !strings.Contains(finished.Error, "输出解析失败") {
		t.Fatalf("解析错误应使任务失败: %s / %s", finished.Status, finished.Error)
	}
}

func TestStopKillsRunningTask(t *testing.T) {
	requireWindows(t)
	m := NewManager(50, 5)

	task, err := m.Start(Spec{
		Name: "long",
		Exe:  "cmd.exe",
		Args: []string{"/c", "ping -n 30 127.0.0.1 > NUL"},
	})
	if err != nil {
		t.Fatalf("启动失败: %v", err)
	}
	if m.RunningCount() != 1 {
		t.Fatalf("运行中任务数应为 1，实际 %d", m.RunningCount())
	}

	if err := m.Stop(task.ID); err != nil {
		t.Fatalf("中断失败: %v", err)
	}

	finished := waitFor(t, m, task.ID, 20*time.Second)
	if finished.Status != StatusKilled {
		t.Fatalf("状态应为 killed，实际 %s", finished.Status)
	}
	if m.RunningCount() != 0 {
		t.Fatalf("中断后运行中任务数应为 0，实际 %d", m.RunningCount())
	}
}
