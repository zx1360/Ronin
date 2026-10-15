package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// RuntimeConfig AI 处理层的运行时可调项。指针字段表示"本次请求未涉及该项"，
// 用于界面上的局部更新；文件里读到的值一律已填充为具体数值。
type RuntimeConfig struct {
	IdleTimeoutSeconds *int      `json:"idle_timeout_seconds,omitempty"`
	JobTimeoutSeconds  *int      `json:"job_timeout_seconds,omitempty"`
	BatchSize          *int      `json:"batch_size,omitempty"`
	MaxAttempts        *int      `json:"max_attempts,omitempty"`
	Workers            *int      `json:"workers,omitempty"`
	Device             *string   `json:"device,omitempty"`            // auto / cpu
	AutoCapabilities   *[]string `json:"auto_capabilities,omitempty"` // 入库后自动执行的能力
	VLMModel           *string   `json:"vlm_model,omitempty"`         // 标注/对话选定的模型；空 = 尚未选定
}

// ConfigStore 串行化对配置文件的读写。
type ConfigStore struct {
	path     string
	defaults AiConfig
	mu       sync.RWMutex
	runtime  RuntimeConfig
}

// 运行时项的合法范围（与界面下发的候选一致，非法值直接拒绝而不是静默夹取）。
const (
	minIdleSeconds = 5
	maxIdleSeconds = 86400
	minJobSeconds  = 30
	maxJobSeconds  = 86400
	minBatchSize   = 1
	maxBatchSize   = 512
	minMaxAttempts = 1
	maxMaxAttempts = 20
	minWorkers     = 1
	maxWorkers     = 4
)

// NewConfigStore 构造存储；defaults 用于填充配置文件中缺失的项。
func NewConfigStore(path string, defaults AiConfig) *ConfigStore {
	s := &ConfigStore{path: path, defaults: defaults}
	s.runtime = defaultRuntime(defaults)
	return s
}

// Load 读取磁盘上的配置；文件不存在时写入一份完整默认值，便于用户直接查看与备份。
func (s *ConfigStore) Load() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.runtime = defaultRuntime(s.defaults)

	raw, err := os.ReadFile(s.path)
	if err != nil {
		if !os.IsNotExist(err) {
			return fmt.Errorf("读取 AI 配置文件失败: %w", err)
		}
		return s.saveLocked()
	}

	// 读取 saveLocked 写出的 runtime 包装，也接受手动维护的平铺配置。
	var file struct {
		RuntimeConfig
		Runtime *RuntimeConfig `json:"runtime"`
	}
	if err := json.Unmarshal(raw, &file); err != nil {
		return fmt.Errorf("解析 AI 配置文件失败 (%s): %w", s.path, err)
	}
	runtime := file.RuntimeConfig
	if file.Runtime != nil {
		runtime = *file.Runtime
	}
	if err := applyRuntime(&s.runtime, runtime); err != nil {
		return fmt.Errorf("AI 配置文件取值非法 (%s): %w", s.path, err)
	}
	return nil
}

// Snapshot 返回当前运行时配置的副本（可安全并发读取）。
func (s *ConfigStore) Snapshot() RuntimeConfig {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return cloneRuntime(s.runtime)
}

// Update 应用一次局部更新并落盘；失败时内存与文件都保持原值。
func (s *ConfigStore) Update(update RuntimeConfig) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	next := cloneRuntime(s.runtime)
	if err := applyRuntime(&next, update); err != nil {
		return err
	}
	previous := s.runtime
	s.runtime = next
	if err := s.saveLocked(); err != nil {
		s.runtime = previous
		return err
	}
	return nil
}

// ApplyTo 把运行时项覆盖到 AI 配置上（进程启动时装载一次）。
func (s *ConfigStore) ApplyTo(cfg *AiConfig) {
	snapshot := s.Snapshot()
	applySnapshotTo(cfg, snapshot)
}

// saveLocked 原子写入配置文件（先写临时文件再改名，避免中断留下半截 JSON）。
func (s *ConfigStore) saveLocked() error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0755); err != nil {
		return fmt.Errorf("创建配置目录失败: %w", err)
	}
	raw, err := json.MarshalIndent(struct {
		Runtime RuntimeConfig `json:"runtime"`
	}{Runtime: s.runtime}, "", "  ")
	if err != nil {
		return fmt.Errorf("序列化 AI 配置失败: %w", err)
	}
	raw = append(raw, '\n')

	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, raw, 0644); err != nil {
		return fmt.Errorf("写入 AI 配置失败: %w", err)
	}
	if err := os.Rename(tmp, s.path); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("保存 AI 配置失败: %w", err)
	}
	return nil
}

// Path 返回配置文件路径（供状态接口展示，便于用户直接备份）。
func (s *ConfigStore) Path() string { return s.path }

// defaultRuntime 由 .env 推导出的基准值构造完整默认配置。
func defaultRuntime(cfg AiConfig) RuntimeConfig {
	idle := int(cfg.IdleTimeout.Seconds())
	job := int(cfg.JobTimeout.Seconds())
	device := cfg.Device
	autoCaps := append([]string{}, cfg.AutoCaps...)
	model := ""
	return RuntimeConfig{
		IdleTimeoutSeconds: &idle,
		JobTimeoutSeconds:  &job,
		BatchSize:          intPtr(cfg.BatchSize),
		MaxAttempts:        intPtr(cfg.MaxAttempts),
		Workers:            intPtr(cfg.Workers),
		Device:             &device,
		AutoCapabilities:   &autoCaps,
		VLMModel:           &model,
	}
}

// applyRuntime 用 update 覆盖 dst（nil 字段保持 dst 原值）。
func applyRuntime(dst *RuntimeConfig, update RuntimeConfig) error {
	if err := validateRuntime(update); err != nil {
		return err
	}
	if update.IdleTimeoutSeconds != nil {
		dst.IdleTimeoutSeconds = intPtr(*update.IdleTimeoutSeconds)
	}
	if update.JobTimeoutSeconds != nil {
		dst.JobTimeoutSeconds = intPtr(*update.JobTimeoutSeconds)
	}
	if update.BatchSize != nil {
		dst.BatchSize = intPtr(*update.BatchSize)
	}
	if update.MaxAttempts != nil {
		dst.MaxAttempts = intPtr(*update.MaxAttempts)
	}
	if update.Workers != nil {
		dst.Workers = intPtr(*update.Workers)
	}
	if update.Device != nil {
		device := strings.ToLower(strings.TrimSpace(*update.Device))
		dst.Device = &device
	}
	if update.AutoCapabilities != nil {
		caps := append([]string{}, (*update.AutoCapabilities)...)
		dst.AutoCapabilities = &caps
	}
	if update.VLMModel != nil {
		model := strings.TrimSpace(*update.VLMModel)
		dst.VLMModel = &model
	}
	return nil
}

// validateRuntime 校验局部更新的取值范围；未提供的项跳过。
func validateRuntime(update RuntimeConfig) error {
	values := []struct {
		key      string
		value    *int
		min, max int
	}{
		{"idle_timeout_seconds", update.IdleTimeoutSeconds, minIdleSeconds, maxIdleSeconds},
		{"job_timeout_seconds", update.JobTimeoutSeconds, minJobSeconds, maxJobSeconds},
		{"batch_size", update.BatchSize, minBatchSize, maxBatchSize},
		{"max_attempts", update.MaxAttempts, minMaxAttempts, maxMaxAttempts},
		{"workers", update.Workers, minWorkers, maxWorkers},
	}
	for _, item := range values {
		if item.value == nil {
			continue
		}
		if *item.value < item.min || *item.value > item.max {
			return fmt.Errorf("%s 超出范围 %d-%d", item.key, item.min, item.max)
		}
	}
	if update.Device != nil {
		switch strings.ToLower(strings.TrimSpace(*update.Device)) {
		case "auto", "cpu":
		default:
			return fmt.Errorf("device 只支持 auto / cpu")
		}
	}
	return nil
}

// applySnapshotTo 把运行时快照写入引擎使用的配置副本。
func applySnapshotTo(cfg *AiConfig, runtime RuntimeConfig) {
	if runtime.IdleTimeoutSeconds != nil {
		cfg.IdleTimeout = seconds(*runtime.IdleTimeoutSeconds)
	}
	if runtime.JobTimeoutSeconds != nil {
		cfg.JobTimeout = seconds(*runtime.JobTimeoutSeconds)
	}
	if runtime.BatchSize != nil {
		cfg.BatchSize = *runtime.BatchSize
	}
	if runtime.MaxAttempts != nil {
		cfg.MaxAttempts = *runtime.MaxAttempts
	}
	if runtime.Workers != nil {
		cfg.Workers = *runtime.Workers
	}
	if runtime.Device != nil {
		cfg.Device = *runtime.Device
	}
	if runtime.AutoCapabilities != nil {
		cfg.AutoCaps = append([]string{}, (*runtime.AutoCapabilities)...)
	}
	// VLMModel 选择在引擎侧维护（标注/对话用哪个模型），此处不覆盖。
}

// cloneRuntime 深拷贝运行时配置（切片字段不能共享底层数组）。
func cloneRuntime(src RuntimeConfig) RuntimeConfig {
	dst := src
	if src.BatchSize != nil {
		dst.BatchSize = intPtr(*src.BatchSize)
	}
	if src.IdleTimeoutSeconds != nil {
		dst.IdleTimeoutSeconds = intPtr(*src.IdleTimeoutSeconds)
	}
	if src.JobTimeoutSeconds != nil {
		dst.JobTimeoutSeconds = intPtr(*src.JobTimeoutSeconds)
	}
	if src.MaxAttempts != nil {
		dst.MaxAttempts = intPtr(*src.MaxAttempts)
	}
	if src.Workers != nil {
		dst.Workers = intPtr(*src.Workers)
	}
	if src.Device != nil {
		device := *src.Device
		dst.Device = &device
	}
	if src.AutoCapabilities != nil {
		caps := append([]string{}, (*src.AutoCapabilities)...)
		dst.AutoCapabilities = &caps
	}
	if src.VLMModel != nil {
		model := *src.VLMModel
		dst.VLMModel = &model
	}
	return dst
}

func intPtr(v int) *int { return &v }

func seconds(v int) time.Duration { return time.Duration(v) * time.Second }
