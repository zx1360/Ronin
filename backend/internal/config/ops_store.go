package config

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
)

// OpsSettings 用指针区分局部更新中缺省的字段。
type OpsSettings struct {
	AutoRefreshSeconds *int  `json:"auto_refresh_seconds,omitempty"` // 仪表盘概览轮询间隔（秒）
	AiRefreshSeconds   *int  `json:"ai_refresh_seconds,omitempty"`   // AI 页轮询间隔（秒）
	LogLineLimit       *int  `json:"log_line_limit,omitempty"`       // 日志页单任务展示行数上限
	ConfirmDestructive *bool `json:"confirm_destructive,omitempty"`  // 破坏性操作二次确认
	// AiPaused AI 任务队列是否处于暂停；服务端启动时按它恢复上次的状态（缺省即暂停）
	AiPaused *bool `json:"ai_paused,omitempty"`
}

const (
	defaultAutoRefresh = 10
	defaultAiRefresh   = 3
	defaultLogLines    = 800
	defaultAiPaused    = true

	minAutoRefresh = 5
	maxAutoRefresh = 3600
	minAiRefresh   = 2
	maxAiRefresh   = 60
	minLogLines    = 100
	maxLogLines    = 5000
)

// opsSettingsKeys 配置文件里的全部已知键；Load 时缺项会回写一份完整配置。
var opsSettingsKeys = []string{
	"auto_refresh_seconds", "ai_refresh_seconds", "log_line_limit",
	"confirm_destructive", "ai_paused",
}

type OpsStore struct {
	path string
	mu   sync.RWMutex
	cur  OpsSettings
}

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
	if hasMissingOpsKey(raw) {
		return s.saveLocked()
	}
	return nil
}

func hasMissingOpsKey(raw []byte) bool {
	var present map[string]json.RawMessage
	if err := json.Unmarshal(raw, &present); err != nil {
		return false
	}
	for _, key := range opsSettingsKeys {
		if _, ok := present[key]; !ok {
			return true
		}
	}
	return false
}

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

func (s *OpsStore) Path() string { return s.path }

func (s *OpsStore) saveLocked() error {
	return saveJSON(s.path, "网页端偏好", filledOpsSettings(s.cur))
}

func defaultOpsSettings() OpsSettings {
	confirm := true
	paused := defaultAiPaused
	return OpsSettings{
		AutoRefreshSeconds: intPtr(defaultAutoRefresh),
		AiRefreshSeconds:   intPtr(defaultAiRefresh),
		LogLineLimit:       intPtr(defaultLogLines),
		ConfirmDestructive: &confirm,
		AiPaused:           &paused,
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
	if update.AiPaused != nil {
		value := *update.AiPaused
		dst.AiPaused = &value
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
	var dst OpsSettings
	applyOpsSettings(&dst, src)
	return dst
}
