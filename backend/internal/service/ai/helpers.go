package ai

import (
	"fmt"
	"strings"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/repository/gallery_repo"
)

// parseUUIDs 解析媒体 ID 字符串列表，非法项直接报错（调用方不应静默忽略）。
func parseUUIDs(raw []string) ([]uuid.UUID, error) {
	ids := make([]uuid.UUID, 0, len(raw))
	for _, s := range raw {
		id, err := uuid.Parse(strings.TrimSpace(s))
		if err != nil {
			return nil, fmt.Errorf("媒体 ID 非法: %s", s)
		}
		ids = append(ids, id)
	}
	return ids, nil
}

// fetchAssets 按 ID 批量取媒体资产。
func fetchAssets(ids []uuid.UUID) ([]model.MediaAsset, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	return gallery_repo.FetchMediaAssetsByIDs(ids)
}

// tierByMediaID 把输入项的实际档位按媒体 ID 索引。
//
// 侧车按 ID 返回结果，逐条回写结果时需要回查该条实际喂进去的档位。
func tierByMediaID(items []MediaItem) map[string]string {
	out := make(map[string]string, len(items))
	for _, item := range items {
		out[item.MediaID] = item.Tier
	}
	return out
}

// tierOf 取某媒体实际使用的档位；查不到时退回能力的期望档位。
func tierOf(tiers map[string]string, mediaID, capability string) string {
	if tier, ok := tiers[mediaID]; ok && tier != "" {
		return tier
	}
	return model.AIInputTier(capability)
}
