package config

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// baseConfig 构造一份可辨识的 .env 基准配置。
func baseConfig() AiConfig {
	return AiConfig{
		IdleTimeout: 120 * time.Second,
		JobTimeout:  900 * time.Second,
		BatchSize:   16,
		MaxAttempts: 3,
		Workers:     1,
		Device:      "auto",
		AutoCaps:    []string{"phash", "embed"},
	}
}

// TestStoreSeedsFromDefaultsAndPersists 配置文件不存在时按 .env 默认值新建，
// 且落盘内容完整可读（不会把用户改过的项丢掉）。
func TestStoreSeedsFromDefaultsAndPersists(t *testing.T) {
	path := filepath.Join(t.TempDir(), "data", "ai_config.json")
	store := NewConfigStore(path, baseConfig())

	if err := store.Load(); err != nil {
		t.Fatalf("首次加载失败: %v", err)
	}
	if !store.FirstLoad() {
		t.Fatal("文件不存在时应标记为首次初始化")
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("首次加载应写出配置文件: %v", err)
	}

	snapshot := store.Snapshot()
	if snapshot.BatchSize == nil || *snapshot.BatchSize != 16 {
		t.Fatalf("批大小默认值不符: %v", snapshot.BatchSize)
	}
	if snapshot.Device == nil || *snapshot.Device != "auto" {
		t.Fatalf("设备默认值不符: %v", snapshot.Device)
	}

	// 重新加载：读到的是文件里的值，且不再是首次初始化
	reloaded := NewConfigStore(path, baseConfig())
	if err := reloaded.Load(); err != nil {
		t.Fatalf("重新加载失败: %v", err)
	}
	if reloaded.FirstLoad() {
		t.Fatal("文件已存在时不应标记为首次初始化")
	}
	if got := reloaded.Snapshot(); got.BatchSize == nil || *got.BatchSize != 16 {
		t.Fatalf("重新加载后批大小不符: %v", got.BatchSize)
	}
}

// TestStorePartialUpdate 局部更新只改传入的项，其余保持原值。
func TestStorePartialUpdate(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ai_config.json")
	store := NewConfigStore(path, baseConfig())
	if err := store.Load(); err != nil {
		t.Fatalf("加载失败: %v", err)
	}

	batch := 32
	if err := store.Update(RuntimeConfig{BatchSize: &batch}); err != nil {
		t.Fatalf("更新批大小失败: %v", err)
	}

	snapshot := store.Snapshot()
	if *snapshot.BatchSize != 32 {
		t.Fatalf("批大小未更新: %d", *snapshot.BatchSize)
	}
	if *snapshot.IdleTimeoutSeconds != 120 {
		t.Fatalf("未涉及的项被改动: %d", *snapshot.IdleTimeoutSeconds)
	}
	if snapshot.AutoCapabilities == nil || len(*snapshot.AutoCapabilities) != 2 {
		t.Fatalf("自动处理能力被改动: %v", snapshot.AutoCapabilities)
	}
}

// TestStoreRejectsInvalidValues 非法取值必须被拒绝且不落盘，避免"看起来生效了"。
func TestStoreRejectsInvalidValues(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ai_config.json")
	store := NewConfigStore(path, baseConfig())
	if err := store.Load(); err != nil {
		t.Fatalf("加载失败: %v", err)
	}

	cases := []struct {
		name   string
		update RuntimeConfig
	}{
		{"批大小越界", RuntimeConfig{BatchSize: intPtr(0)}},
		{"重试上限越界", RuntimeConfig{MaxAttempts: intPtr(99)}},
		{"并发越界", RuntimeConfig{Workers: intPtr(9)}},
		{"设备非法", RuntimeConfig{Device: strPtr("gpu")}},
	}
	for _, tc := range cases {
		if err := store.Update(tc.update); err == nil {
			t.Fatalf("%s: 期望报错，实际通过", tc.name)
		}
	}

	snapshot := store.Snapshot()
	if *snapshot.BatchSize != 16 || *snapshot.Workers != 1 || *snapshot.Device != "auto" {
		t.Fatalf("非法更新不应改动内存值: %+v", snapshot)
	}
}

// TestStoreRejectsBrokenFile 配置文件损坏时明确报错，而不是静默重置成默认值。
func TestStoreRejectsBrokenFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ai_config.json")
	if err := os.WriteFile(path, []byte("{ not json"), 0644); err != nil {
		t.Fatalf("写入损坏文件失败: %v", err)
	}
	store := NewConfigStore(path, baseConfig())
	if err := store.Load(); err == nil {
		t.Fatal("损坏的配置文件应当报错")
	}
}

// TestApplyTo 运行时项覆盖到引擎配置上。
func TestApplyTo(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ai_config.json")
	store := NewConfigStore(path, baseConfig())
	if err := store.Load(); err != nil {
		t.Fatalf("加载失败: %v", err)
	}

	workers := 3
	device := "cpu"
	caps := []string{"phash"}
	if err := store.Update(RuntimeConfig{
		Workers:          &workers,
		Device:           &device,
		AutoCapabilities: &caps,
	}); err != nil {
		t.Fatalf("更新失败: %v", err)
	}

	cfg := baseConfig()
	store.ApplyTo(&cfg)
	if cfg.Workers != 3 || cfg.Device != "cpu" || len(cfg.AutoCaps) != 1 {
		t.Fatalf("运行时配置未生效: %+v", cfg)
	}
}

func strPtr(v string) *string { return &v }
