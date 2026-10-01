package util_handler

import (
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func TestDirUsageCacheConcurrentAndRefresh(t *testing.T) {
	root := t.TempDir()
	file := filepath.Join(root, "file")
	if err := os.WriteFile(file, []byte("abc"), 0o644); err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if usage := getCachedDirUsage(root); !usage.Exists || usage.Files != 1 || usage.Bytes != 3 {
				t.Errorf("并发首读统计不完整: %+v", usage)
			}
		}()
	}
	wg.Wait()
	if err := os.WriteFile(file, []byte("abcdef"), 0o644); err != nil {
		t.Fatal(err)
	}
	if usage := getCachedDirUsage(root); usage.Bytes != 3 {
		t.Fatal("缓存未过期时发生了扫描")
	}
	usageCacheMu.Lock()
	usageCache[root].updatedAt = time.Now().Add(-2 * usageCacheTTL)
	usageCacheMu.Unlock()
	if usage := getCachedDirUsage(root); usage.Bytes != 3 {
		t.Fatal("过期访问应立即返回现有快照")
	}
	deadline := time.Now().Add(3 * time.Second)
	for getCachedDirUsage(root).Bytes != 6 {
		if time.Now().After(deadline) {
			t.Fatal("过期统计没有异步刷新")
		}
		time.Sleep(time.Millisecond)
	}
}
