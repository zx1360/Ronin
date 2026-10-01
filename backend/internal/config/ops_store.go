package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

// 网页运维端（ops）的界面偏好
//
// 这些是纯展示/交互偏好，不影响服务端行为，因此与 AI 运行时配置分开存放：
// `STATIC_DIR/data/ops_web.json`。不写用户目录，随应用目录一起迁移与备份。
// 字段用指针表示"本次请求未涉及该项"，便于界面做局部更新。

// OpsSettings 网页运维端偏好（读取后一律已填充为具体值）。
type OpsSettings struct {
	AutoRefreshSeconds *int  `json:"auto_refresh_seconds,omitempty"` // 仪表盘概览轮询间隔（秒）
	AiRefreshSeconds   *int  `json:"ai_refresh_seconds,omitempty"`   // AI 页轮询间隔（秒）
	LogLineLimit       *int  `json:"log_line_limit,omitempty"`       // 日志页单任务展示行数上限
	ConfirmDestructive *bool `json:"confirm_destructive,omitempty"`  // 破坏性操作二次确认
}

// 偏好的默认值与合法范围。
const (
	defaultAutoRefresh = 10
	defaultAiRefresh   = 3
	defaultLogLines    = 800

	minAutoRefresh = 5
	maxAutoRefresh = 3600
	minAiRefresh   = 2
	maxAiRefresh   = 60
	minLogLines    = 100
	maxLogLines    = 5000
)

// OpsStore 串行化对网页端偏好文件的读写。
type OpsStore struct {
	path string
	mu   sync.RWMutex
	cur  OpsSettings
}

// NewOpsStore 创建偏好存储（Load 之前使用默认值）。
func NewOpsStore(path string) *OpsStore {
	return &OpsStore{path: path, cur: defaultOpsSettings()}
}

// Load 读取偏好文件；文件不存在时写入一份完整默认值（便于用户直接查看与备份）。
func (s *OpsStore) Load() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.cur = defaultOpsSettings()
	raw, err := os.ReadFile(s.path)
	if err != nil {
		if !os.IsNotExist(err) {
			return fmt.Errorf("读取网页端偏好失败: %w", err)
		}
		return s.saveLocked()
	}

	var loaded OpsSettings
	if err := json.Unmarshal(raw, &loaded); err != nil {
		return fmt.Errorf("解析网页端偏好失败 (%s): %w", s.path, err)
	}
	if err := validateOpsSettings(loaded); err != nil {
		return fmt.Errorf("网页端偏好取值非法 (%s): %w", s.path, err)
	}
	applyOpsSettings(&s.cur, loaded)
	return nil
}

// Snapshot 返回当前偏好的副本。
func (s *OpsStore) Snapshot() OpsSettings {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return cloneOpsSettings(s.cur)
}

// Update 应用一次局部更新并落盘；非法值直接拒绝，失败时内存与文件都保持原值。
func (s *OpsStore) Update(update OpsSettings) error {
	if err := validateOpsSettings(update); err != nil {
		return err
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	next := cloneOpsSettings(s.cur)
	applyOpsSettings(&next, update)
	previous := s.cur
	s.cur = next
	if err := s.saveLocked(); err != nil {
		s.cur = previous
		return err
	}
	return nil
}

// Path 返回偏好文件路径（供界面展示，便于备份）。
func (s *OpsStore) Path() string { return s.path }

// saveLocked 原子写入（先写临时文件再改名，避免中断留下半截 JSON）。
func (s *OpsStore) saveLocked() error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0755); err != nil {
		return fmt.Errorf("创建偏好目录失败: %w", err)
	}
	raw, err := json.MarshalIndent(filledOpsSettings(s.cur), "", "  ")
	if err != nil {
		return fmt.Errorf("序列化网页端偏好失败: %w", err)
	}
	raw = append(raw, '\n')

	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, raw, 0644); err != nil {
		return fmt.Errorf("写入网页端偏好失败: %w", err)
	}
	if err := os.Rename(tmp, s.path); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("保存网页端偏好失败: %w", err)
	}
	return nil
}

func defaultOpsSettings() OpsSettings {
	confirm := true
	return OpsSettings{
		AutoRefreshSeconds: intPtr(defaultAutoRefresh),
		AiRefreshSeconds:   intPtr(defaultAiRefresh),
		LogLineLimit:       intPtr(defaultLogLines),
		ConfirmDestructive: &confirm,
	}
}

// filledOpsSettings 补齐未设置项，保证落盘的是完整可读的配置。
func filledOpsSettings(src OpsSettings) OpsSettings {
	merged := defaultOpsSettings()
	applyOpsSettings(&merged, src)
	return merged
}

// applyOpsSettings 用 update 覆盖 dst（nil 字段保持 dst 原值）。
func applyOpsSettings(dst *OpsSettings, update OpsSettings) {
	if update.AutoRefreshSeconds != nil {
		dst.AutoRefreshSeconds = intPtr(*update.AutoRefreshSeconds)
	}
	if update.AiRefreshSeconds != nil {
		dst.AiRefreshSeconds = intPtr(*update.AiRefreshSeconds)
	}
	if update.LogLineLimit != nil {
		dst.LogLineLimit = intPtr(*update.LogLineLimit)
	}
	if update.ConfirmDestructive != nil {
		value := *update.ConfirmDestructive
		dst.ConfirmDestructive = &value
	}
}

func validateOpsSettings(update OpsSettings) error {
	values := []struct {
		key      string
		value    *int
		min, max int
	}{
		{"auto_refresh_seconds", update.AutoRefreshSeconds, minAutoRefresh, maxAutoRefresh},
		{"ai_refresh_seconds", update.AiRefreshSeconds, minAiRefresh, maxAiRefresh},
		{"log_line_limit", update.LogLineLimit, minLogLines, maxLogLines},
	}
	for _, item := range values {
		if item.value == nil {
			continue
		}
		if *item.value < item.min || *item.value > item.max {
			return fmt.Errorf("%s 超出范围 %d-%d", item.key, item.min, item.max)
		}
	}
	return nil
}

func cloneOpsSettings(src OpsSettings) OpsSettings {
	dst := src
	if src.AutoRefreshSeconds != nil {
		dst.AutoRefreshSeconds = intPtr(*src.AutoRefreshSeconds)
	}
	if src.AiRefreshSeconds != nil {
		dst.AiRefreshSeconds = intPtr(*src.AiRefreshSeconds)
	}
	if src.LogLineLimit != nil {
		dst.LogLineLimit = intPtr(*src.LogLineLimit)
	}
	if src.ConfirmDestructive != nil {
		value := *src.ConfirmDestructive
		dst.ConfirmDestructive = &value
	}
	return dst
}
