package config

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"sync"
	"unicode/utf8"

	"github.com/google/uuid"
)

// 客户端整体提交预设，以服务端保存结果为准。
type ReviewPreset struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Role string `json:"role"`
	Tone string `json:"tone"`
}

const (
	maxReviewPresets   = 20
	maxReviewNameRunes = 40
	maxReviewRoleRunes = 1000
	maxReviewToneRunes = 500
)

type ReviewPresetStore struct {
	path string

	mu      sync.RWMutex
	presets []ReviewPreset
}

func NewReviewPresetStore(path string) *ReviewPresetStore {
	return &ReviewPresetStore{path: path}
}

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

func (s *ReviewPresetStore) saveLocked() error {
	return saveJSON(s.path, "回顾预设", struct {
		Presets []ReviewPreset `json:"presets"`
	}{Presets: s.presets})
}

// 空列表恢复内置预设，单条预设必须有角色设定。
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
