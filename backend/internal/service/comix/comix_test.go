package comix

import (
	"errors"
	"strings"
	"testing"
)

func TestBuildArgs(t *testing.T) {
	got := BuildArgs("download", "12", "--latest", "3")
	want := []string{"-m", "comix.cli", "--json", "download", "12", "--latest", "3"}
	if len(got) != len(want) {
		t.Fatalf("参数个数不符: %v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("第 %d 个参数应为 %q，实际 %q", i, want[i], got[i])
		}
	}
	// --json 必须位于子命令之前（主解析器的全局参数）
	if got[2] != "--json" || got[3] != "download" {
		t.Fatalf("--json 必须位于子命令之前: %v", got)
	}
}

func TestParseOutput(t *testing.T) {
	t.Run("成功输出", func(t *testing.T) {
		result, err := parseOutput(`{"ok":true,"data":{"comic_id":7},"exit_code":0}`, "", 0, nil)
		if err != nil {
			t.Fatalf("不应报错: %v", err)
		}
		if !result.OK || result.Data["comic_id"] == nil {
			t.Fatalf("应解析出 ok/data: %+v", result)
		}
	})

	t.Run("业务错误仍返回结果", func(t *testing.T) {
		exitErr := errors.New("exit status 2")
		result, err := parseOutput(`{"ok":false,"error":"多候选","candidates":[1,2],"exit_code":2}`, "候选提示", 2, exitErr)
		if err != nil {
			t.Fatalf("退出码 2 的业务错误不应视为传输故障: %v", err)
		}
		if result.OK || result.Error != "多候选" || len(result.Candidates) != 2 {
			t.Fatalf("业务错误内容未保留: %+v", result)
		}
		if result.Stderr != "候选提示" {
			t.Fatalf("stderr 应被裁剪后保留: %q", result.Stderr)
		}
	})

	t.Run("非 JSON 输出且进程失败", func(t *testing.T) {
		_, err := parseOutput("Traceback...", "boom", 1, errors.New("exit status 1"))
		if err == nil || !strings.Contains(err.Error(), "boom") {
			t.Fatalf("应带 stderr 报错，实际: %v", err)
		}
	})

	t.Run("非 JSON 输出且进程成功", func(t *testing.T) {
		_, err := parseOutput("not json", "", 0, nil)
		if err == nil || !strings.Contains(err.Error(), "解析失败") {
			t.Fatalf("应报告解析失败，实际: %v", err)
		}
	})
}
