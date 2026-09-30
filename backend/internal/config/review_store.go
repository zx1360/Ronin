package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"unicode/utf8"

	"github.com/google/uuid"
)

// 回顾预设（角色 + 语气）存 <STATIC_DIR>/data/review_presets.json。
//
// 服务端文件是唯一权威，端上只做本地镜像缓存；写入按"整体替换"语义，
// 与用户数据同步一致，避免两端各自增删导致列表分叉。
type ReviewPreset struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Role string `json:"role"`
	Tone string `json:"tone"`
}

// 取值上限：预设是给模型的开场设定，过长只会挤占上下文。
const (
	maxReviewPresets   = 20
	maxReviewNameRunes = 40
	maxReviewRoleRunes = 1000
	maxReviewToneRunes = 500
)

// ReviewPresetStore 串行化对预设文件的读写。
type ReviewPresetStore struct {
	path string

	mu      sync.RWMutex
	presets []ReviewPreset
}

// NewReviewPresetStore 构造存储；文件不存在时由 Load 写入一份内置默认值。
func NewReviewPresetStore(path string) *ReviewPresetStore {
	return &ReviewPresetStore{path: path}
}

// Path 返回配置文件路径（供接口展示，便于用户直接编辑与备份）。
func (s *ReviewPresetStore) Path() string { return s.path }

// Load 读取预设；文件缺失时按内置默认值新建，损坏时明确报错而不静默重置。
func (s *ReviewPresetStore) Load() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	raw, err := os.ReadFile(s.path)
	if err != nil {
		if !os.IsNotExist(err) {
			return fmt.Errorf("读取回顾预设失败: %w", err)
		}
		s.presets = defaultReviewPresets()
		return s.saveLocked()
	}

	var file struct {
		Presets []ReviewPreset `json:"presets"`
	}
	if err := json.Unmarshal(raw, &file); err != nil {
		return fmt.Errorf("解析回顾预设失败 (%s): %w", s.path, err)
	}
	presets, err := validateReviewPresets(file.Presets)
	if err != nil {
		return fmt.Errorf("回顾预设非法 (%s): %w", s.path, err)
	}
	s.presets = presets
	return nil
}

// Snapshot 返回当前预设的副本。
func (s *ReviewPresetStore) Snapshot() []ReviewPreset {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return append([]ReviewPreset{}, s.presets...)
}

// Replace 整体替换预设并落盘；失败时内存与文件都保持原值。
func (s *ReviewPresetStore) Replace(presets []ReviewPreset) error {
	next, err := validateReviewPresets(presets)
	if err != nil {
		return err
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	previous := s.presets
	s.presets = next
	if err := s.saveLocked(); err != nil {
		s.presets = previous
		return err
	}
	return nil
}

// saveLocked 原子写入（先写临时文件再改名，避免中断留下半截 JSON）。
func (s *ReviewPresetStore) saveLocked() error {
	dir := filepath.Dir(s.path)
	if dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("创建配置目录失败: %w", err)
		}
	}
	raw, err := json.MarshalIndent(struct {
		Presets []ReviewPreset `json:"presets"`
	}{Presets: s.presets}, "", "  ")
	if err != nil {
		return fmt.Errorf("序列化回顾预设失败: %w", err)
	}
	raw = append(raw, '\n')

	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, raw, 0644); err != nil {
		return fmt.Errorf("写入回顾预设失败: %w", err)
	}
	if err := os.Rename(tmp, s.path); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("保存回顾预设失败: %w", err)
	}
	return nil
}

// validateReviewPresets 规整并校验预设列表：补齐 ID、裁剪空白、限定长度与数量。
//
// 允许恢复出厂设置（列表为空时回落到内置默认），但不允许出现空角色——
// 没有角色设定的回顾没有意义。
func validateReviewPresets(presets []ReviewPreset) ([]ReviewPreset, error) {
	if len(presets) == 0 {
		return defaultReviewPresets(), nil
	}
	if len(presets) > maxReviewPresets {
		return nil, fmt.Errorf("预设最多 %d 条", maxReviewPresets)
	}

	seen := map[string]bool{}
	result := make([]ReviewPreset, 0, len(presets))
	for i, item := range presets {
		position := i + 1
		id := strings.TrimSpace(item.ID)
		if id == "" {
			id = uuid.NewString()
		}
		if seen[id] {
			return nil, fmt.Errorf("第 %d 条预设的 id 重复", position)
		}
		seen[id] = true

		name := strings.TrimSpace(item.Name)
		role := strings.TrimSpace(item.Role)
		tone := strings.TrimSpace(item.Tone)
		if name == "" {
			return nil, fmt.Errorf("第 %d 条预设缺少名称", position)
		}
		if role == "" {
			return nil, fmt.Errorf("预设「%s」缺少角色设定", name)
		}
		if err := checkRunes("预设名称", name, maxReviewNameRunes); err != nil {
			return nil, err
		}
		if err := checkRunes("角色设定", role, maxReviewRoleRunes); err != nil {
			return nil, err
		}
		if err := checkRunes("语气要求", tone, maxReviewToneRunes); err != nil {
			return nil, err
		}
		result = append(result, ReviewPreset{ID: id, Name: name, Role: role, Tone: tone})
	}
	return result, nil
}

func checkRunes(label, value string, limit int) error {
	if utf8.RuneCountInString(value) > limit {
		return fmt.Errorf("%s最多 %d 字", label, limit)
	}
	return nil
}

// defaultReviewPresets 首次使用时的内置预设，用户可随意改写或删除。
func defaultReviewPresets() []ReviewPreset {
	return []ReviewPreset{
		{
			ID:   uuid.NewString(),
			Name: "温和的倾听者",
			Role: "你是陪伴我多年的朋友，熟悉我的生活节奏，擅长从琐碎记录里看出我自己没察觉的变化。",
			Tone: "温和、具体、不评判。可以说你观察到了什么，但不要替我做结论，也不要说教。",
		},
		{
			ID:   uuid.NewString(),
			Name: "冷静的记录者",
			Role: "你是一位只对事实负责的观察者，负责把这几十天的记录还原成一条清晰的线索。",
			Tone: "克制、客观、条理清楚，先讲事实再给一句观察，不用感叹号，不煽情。",
		},
		{
			ID:   uuid.NewString(),
			Name: "直言的老友",
			Role: "你是敢对我说真话的老朋友，看得见我在哪些地方原地打转，也看得见我真正的进展。",
			Tone: "直率但不刻薄，该指出的问题直接指出，同时把做得好的地方讲清楚、讲具体。",
		},
	}
}
