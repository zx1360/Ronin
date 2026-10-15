package model

import (
	"fmt"
	"strings"

	"github.com/google/uuid"
)

const HiddenEssayLabelID = "00000000-0000-4000-8000-000000000001"
const EssaySchemaVersion = 2

func (l EssayLabel) IsHiddenRoot() bool {
	return l.ID.String() == HiddenEssayLabelID || (l.Name == "隐藏" && l.ParentID == nil)
}

func EnsureHiddenEssayLabel(labels []EssayLabel) []EssayLabel {
	for _, label := range labels {
		if label.IsHiddenRoot() {
			return labels
		}
	}
	return append(labels, EssayLabel{ID: uuid.MustParse(HiddenEssayLabelID), Name: "隐藏"})
}

func ValidateEssayLabels(labels []EssayLabel) error {
	byID := make(map[uuid.UUID]EssayLabel, len(labels))
	for _, label := range labels {
		if _, exists := byID[label.ID]; exists || label.ID == uuid.Nil || strings.TrimSpace(label.Name) == "" {
			return fmt.Errorf("标签 ID 重复或缺少 ID/名称")
		}
		if label.ID.String() == HiddenEssayLabelID && (label.Name != "隐藏" || label.ParentID != nil) {
			return fmt.Errorf("隐藏标签必须保留在根级")
		}
		byID[label.ID] = label
	}
	for _, label := range labels {
		seen := map[uuid.UUID]bool{label.ID: true}
		for parent := label.ParentID; parent != nil; {
			if seen[*parent] {
				return fmt.Errorf("标签不能循环嵌套")
			}
			item, exists := byID[*parent]
			if !exists {
				return fmt.Errorf("上级标签不存在")
			}
			seen[*parent] = true
			parent = item.ParentID
		}
	}
	return nil
}

// 隐藏根及其整棵子树；历史平级“隐藏”标签同样生效。
func HiddenEssayLabelIDs(labels []EssayLabel) map[string]bool {
	byID := make(map[string]EssayLabel, len(labels))
	hidden := map[string]bool{HiddenEssayLabelID: true}
	for _, label := range labels {
		byID[label.ID.String()] = label
		if label.IsHiddenRoot() {
			hidden[label.ID.String()] = true
		}
	}
	for _, label := range labels {
		seen := map[string]bool{}
		for id := label.ID.String(); id != "" && !seen[id]; {
			if hidden[id] {
				hidden[label.ID.String()] = true
				break
			}
			seen[id] = true
			item := byID[id]
			if item.ParentID == nil {
				break
			}
			id = item.ParentID.String()
		}
	}
	return hidden
}
