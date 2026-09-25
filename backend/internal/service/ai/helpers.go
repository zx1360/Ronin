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
