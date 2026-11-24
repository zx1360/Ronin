package ai

import (
	"cmp"
	"context"
	"slices"
	"time"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/repository/gallery_repo"
)

type relatedMatch struct {
	id         uuid.UUID
	bundled    bool
	otherGroup bool
	score      float32
	caption    string
}

func (e *Engine) relatedMatches(ctx context.Context, asset model.MediaAsset) ([]relatedMatch, error) {
	modelName := e.Config().EmbedModel
	row, err := ai_repo.GetEmbedding(asset.ID, "image", modelName)
	if err != nil {
		return nil, err
	}
	var query []float32
	if row != nil {
		query = dequantize(row, row.Dim)
	} else {
		modelName = "" // 仍可读取已捆绑的文件
	}
	evidence, err := ai_repo.RelatedMediaEvidenceFor(ctx, asset, modelName, 10*time.Minute)
	if err != nil {
		return nil, err
	}
	matches := make([]relatedMatch, 0, len(evidence))
	for _, item := range evidence {
		match := relatedMatch{
			id: item.MediaID, bundled: item.Bundled, otherGroup: item.OtherGroup, caption: item.Caption,
		}
		if !item.Bundled {
			match.score = cosine(query, dequantize(&item.EmbeddingRow, item.Dim))
			if match.score < 0.78 {
				continue
			}
		}
		matches = append(matches, match)
	}
	slices.SortStableFunc(matches, func(a, b relatedMatch) int {
		if a.bundled != b.bundled {
			if a.bundled {
				return -1
			}
			return 1
		}
		return cmp.Compare(b.score, a.score)
	})
	return matches, nil
}

func (e *Engine) RelatedMedia(ctx context.Context, id uuid.UUID) (*model.AiSearchResponse, error) {
	assets, err := gallery_repo.FetchMediaAssetsByIDs(ctx, []uuid.UUID{id})
	if err != nil {
		return nil, err
	}
	result := &model.AiSearchResponse{Mode: "related", Hits: []model.AiSearchHit{}}
	if len(assets) == 0 || assets[0].IsDeleted {
		return result, nil
	}
	matches, err := e.relatedMatches(ctx, assets[0])
	if err != nil {
		return nil, err
	}
	ids := make([]uuid.UUID, 0, len(matches))
	byID := make(map[uuid.UUID]relatedMatch, len(matches))
	for _, item := range matches {
		ids = append(ids, item.id)
		byID[item.id] = item
	}
	hits, err := buildHits(ctx, ids, nil, nil)
	if err != nil {
		return nil, err
	}
	for _, hit := range hits {
		if hit.IsDeleted {
			continue
		}
		match := byID[hit.ID]
		hit.Score = float64(match.score)
		hit.Source = []string{"nearby_visual"}
		if match.bundled {
			hit.Source = []string{"bundle"}
		} else if match.otherGroup {
			hit.Source = append(hit.Source, "other_bundle")
		}
		result.Hits = append(result.Hits, hit)
	}
	result.Total = len(result.Hits)
	return result, nil
}
