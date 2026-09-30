package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestReviewPresetStoreSeedsDefaults(t *testing.T) {
	path := filepath.Join(t.TempDir(), "data", "review_presets.json")
	store := NewReviewPresetStore(path)
	if err := store.Load(); err != nil {
		t.Fatalf("首次加载应生成默认预设: %v", err)
	}
	presets := store.Snapshot()
	if len(presets) == 0 {
		t.Fatal("默认预设不应为空")
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("应落盘配置文件: %v", err)
	}

	reloaded := NewReviewPresetStore(path)
	if err := reloaded.Load(); err != nil {
		t.Fatalf("重新加载失败: %v", err)
	}
	if len(reloaded.Snapshot()) != len(presets) {
		t.Fatalf("重载后条数变化: %d → %d", len(presets), len(reloaded.Snapshot()))
	}
}

func TestReviewPresetStoreReplace(t *testing.T) {
	path := filepath.Join(t.TempDir(), "review_presets.json")
	store := NewReviewPresetStore(path)
	if err := store.Load(); err != nil {
		t.Fatal(err)
	}

	if err := store.Replace([]ReviewPreset{{Name: "自定义", Role: "你是编辑", Tone: "简洁"}}); err != nil {
		t.Fatalf("替换失败: %v", err)
	}
	presets := store.Snapshot()
	if len(presets) != 1 || presets[0].Name != "自定义" {
		t.Fatalf("替换结果不符: %+v", presets)
	}
	if presets[0].ID == "" {
		t.Fatal("缺失的 ID 应由服务端补齐")
	}

	// 空列表 = 恢复出厂设置，而不是留下一个没法用的空列表。
	if err := store.Replace(nil); err != nil {
		t.Fatalf("空列表应回落默认值: %v", err)
	}
	if len(store.Snapshot()) == 0 {
		t.Fatal("恢复出厂后不应为空")
	}
}

func TestReviewPresetStoreRejectsInvalid(t *testing.T) {
	path := filepath.Join(t.TempDir(), "review_presets.json")
	store := NewReviewPresetStore(path)
	if err := store.Load(); err != nil {
		t.Fatal(err)
	}
	before := store.Snapshot()

	cases := map[string][]ReviewPreset{
		"缺角色":  {{Name: "只有名字"}},
		"缺名称":  {{Role: "你是编辑"}},
		"id 重复": {{ID: "same", Name: "A", Role: "角色"}, {ID: "same", Name: "B", Role: "角色"}},
		"超出条数": manyPresets(maxReviewPresets + 1),
	}
	for name, presets := range cases {
		t.Run(name, func(t *testing.T) {
			if err := store.Replace(presets); err == nil {
				t.Fatal("非法预设应被拒绝")
			}
			if len(store.Snapshot()) != len(before) {
				t.Fatal("校验失败时不应改动内存中的预设")
			}
		})
	}
}

func TestReviewPresetStoreCorruptFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "review_presets.json")
	if err := os.WriteFile(path, []byte("{不是 JSON"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := NewReviewPresetStore(path).Load(); err == nil {
		t.Fatal("损坏的文件应明确报错，而不是静默重置")
	}
}

func manyPresets(n int) []ReviewPreset {
	presets := make([]ReviewPreset, 0, n)
	for i := 0; i < n; i++ {
		presets = append(presets, ReviewPreset{Name: "预设", Role: "角色"})
	}
	return presets
}
