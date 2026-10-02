package ai

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"monarch/internal/config"
)

// fakeSidecar 在临时目录里放一个假的 ronin_ai 包，用来在不依赖真实模型的情况下
// 验证侧车的管道协议与中断路径。
const fakeSidecar = `
import json, sys, time

header = json.loads(sys.stdin.readline())
count = int(header.get("count") or 0)
for _ in range(count):
    sys.stdin.readline()

mode = header.get("params", {}).get("mode", "full")
if mode == "full":
    for i in range(count):
        print(json.dumps({"id": str(i), "ok": True}), flush=True)
else:
    # 少回一条后卡住：中断时读取协程仍在读管道
    for i in range(max(0, count - 1)):
        print(json.dumps({"id": str(i), "ok": True}), flush=True)
        time.sleep(0.05)
    time.sleep(600)
`

// newFakeSidecar 构造一个指向假侧车的 Sidecar；python 不可用时跳过用例。
func newFakeSidecar(t *testing.T) *Sidecar {
	t.Helper()
	python, err := exec.LookPath("python")
	if err != nil {
		t.Skip("跳过：未找到 python")
	}

	dir := t.TempDir()
	pkg := filepath.Join(dir, "ronin_ai")
	if err := os.MkdirAll(pkg, 0o755); err != nil {
		t.Fatalf("创建假侧车目录失败: %v", err)
	}
	if err := os.WriteFile(filepath.Join(pkg, "__init__.py"), nil, 0o644); err != nil {
		t.Fatalf("写入 __init__.py 失败: %v", err)
	}
	if err := os.WriteFile(filepath.Join(pkg, "__main__.py"), []byte(fakeSidecar), 0o644); err != nil {
		t.Fatalf("写入 __main__.py 失败: %v", err)
	}

	cfg := config.AiConfig{Python: python, SidecarDir: dir, IdleTimeout: time.Minute}
	return NewSidecar("test", cfg, func() config.AiConfig { return cfg })
}

// TestSidecarRunBatch 正常路径：每个条目都应拿到一条结果。
func TestSidecarRunBatch(t *testing.T) {
	s := newFakeSidecar(t)
	defer s.Shutdown()

	ctx, cancel := context.WithTimeout(t.Context(), 60*time.Second)
	defer cancel()

	results, err := s.RunBatch(ctx, nil, []SidecarItem{{ID: "a"}, {ID: "b"}})
	if err != nil {
		t.Fatalf("批次执行失败: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("结果条数不符: %d", len(results))
	}
}

// TestSidecarCancelDuringBatch 中断运行中的批次：必须返回错误而不是让读取协程
// 踩到已被置空的管道（那会 panic 并带崩整个服务），之后还能重新拉起侧车。
func TestSidecarCancelDuringBatch(t *testing.T) {
	s := newFakeSidecar(t)
	defer s.Shutdown()

	for round := 1; round <= 3; round++ {
		ctx, cancel := context.WithCancel(context.Background())
		done := make(chan error, 1)
		go func() {
			_, err := s.RunBatch(ctx, map[string]any{"mode": "partial"}, []SidecarItem{{ID: "a"}, {ID: "b"}})
			done <- err
		}()

		time.Sleep(150 * time.Millisecond)
		cancel()

		select {
		case err := <-done:
			if err == nil {
				t.Fatalf("第 %d 轮：中断后应返回错误", round)
			}
		case <-time.After(30 * time.Second):
			t.Fatalf("第 %d 轮：批次中断后未退出", round)
		}
	}

	// 中断过的侧车必须还能正常干活（进程已在中断时回收）
	ctx, cancel := context.WithTimeout(t.Context(), 60*time.Second)
	defer cancel()
	results, err := s.RunBatch(ctx, nil, []SidecarItem{{ID: "c"}})
	if err != nil || len(results) != 1 {
		t.Fatalf("中断后重新拉起失败: n=%d err=%v", len(results), err)
	}
}
