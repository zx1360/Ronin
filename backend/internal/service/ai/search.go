package ai

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/repository/gallery_repo"
)

// 检索模式。
const (
	ModeAuto     = "auto"
	ModeSemantic = "semantic"
	ModeKeyword  = "keyword"
	ModeFilename = "filename"
)

const (
	// semanticCandidateCap 语义检索的候选上限：结构化筛选后的候选超过该数量时截断，
	// 保证单次扫描时间可控（7w 全库仍远低于上限）。
	semanticCandidateCap = 50000
	// keywordCandidateCap 混合检索中"关键词命中"的候选上限。
	keywordCandidateCap = 3000
	// keywordBoost 混合检索中关键词命中的加分（相对语义得分的固定加权）。
	keywordBoost = 0.25
)

// SearchRequest 组合搜索请求。
type SearchRequest struct {
	Query              string
	Mode               string
	MediaID            string // 以库内媒体搜图
	ImagePath          string // 以外部图片搜图（服务端临时文件路径）
	TagIDs             []string
	IncludeDescendants bool
	PersonIDs          []string
	VLMTags            []string // 按 AI 标签筛选（与人工标签独立）
	MimeType           string
	From, To           *time.Time
	SortBy             string
	SortOrder          string
	Limit              int
	Offset             int
	MinScore           float32
}

// Search 执行组合搜索：语义（文搜图 / 以图搜图）与结构化条件（标签/人物/关键词）可任意组合。
func (e *Engine) Search(ctx context.Context, req SearchRequest) (*model.AiSearchResponse, error) {
	limit := req.Limit
	if limit <= 0 || limit > 200 {
		limit = 60
	}
	if req.Offset < 0 {
		req.Offset = 0
	}

	tagIDs, err := parseUUIDs(req.TagIDs)
	if err != nil {
		return nil, err
	}
	personIDs, err := parseUUIDs(req.PersonIDs)
	if err != nil {
		return nil, err
	}

	filters := ai_repo.SearchFilters{
		TagIDs:      tagIDs,
		Descendants: req.IncludeDescendants,
		PersonIDs:   personIDs,
		VLMTags:     normalizeTags(req.VLMTags),
		MimeType:    req.MimeType,
		From:        req.From,
		To:          req.To,
		SortBy:      req.SortBy,
		SortOrder:   req.SortOrder,
	}

	query := strings.TrimSpace(req.Query)
	mode := req.Mode
	if mode == "" {
		mode = ModeAuto
	}
	var useSemantic bool
	switch mode {
	case ModeSemantic:
		useSemantic = true
	case ModeKeyword, ModeFilename:
		useSemantic = false
	default:
		// auto：有文本/图片查询就走语义，否则退化为纯结构化筛选
		mode = ModeAuto
		useSemantic = query != "" || req.MediaID != "" || req.ImagePath != ""
	}

	if !useSemantic {
		return e.plainSearch(filters, query, mode, limit, req.Offset)
	}

	vector, err := e.queryVector(ctx, query, req.MediaID, req.ImagePath)
	if err != nil {
		// 语义链路不可用时退化为关键词检索，保证搜索框始终有结果
		fallback, fallbackErr := e.plainSearch(filters, query, ModeKeyword, limit, req.Offset)
		if fallbackErr != nil {
			return nil, fallbackErr
		}
		return fallback, nil
	}

	return e.semanticSearch(ctx, filters, query, vector, limit, req.Offset, req.MinScore)
}

// queryVector 生成查询向量：优先复用库内媒体的向量，其次对图片/文本实时编码。
func (e *Engine) queryVector(ctx context.Context, query, mediaID, imagePath string) ([]float32, error) {
	embedModel := e.Config().EmbedModel
	if mediaID != "" {
		id, err := uuid.Parse(mediaID)
		if err != nil {
			return nil, fmt.Errorf("媒体 ID 非法: %s", mediaID)
		}
		row, err := ai_repo.GetEmbedding(id, "image", embedModel)
		if err != nil {
			return nil, err
		}
		if row != nil {
			return dequantize(row, row.Dim), nil
		}
		// 该媒体尚无向量：用它的文件现算一次（与 embed 能力同档，结果一致）
		items, _, err := e.resolveItems(model.CapEmbed, []string{mediaID})
		if err != nil || len(items) == 0 {
			return nil, fmt.Errorf("该媒体尚未生成向量，可先对其执行 embed 处理")
		}
		imagePath = items[0].Path
	}

	switch {
	case imagePath != "":
		results, err := e.embed.RunBatch(ctx, map[string]any{"model": embedModel},
			[]SidecarItem{{ID: "query", Path: imagePath}})
		if err != nil {
			return nil, err
		}
		if len(results) == 0 || !results[0].OK {
			return nil, fmt.Errorf("图片编码失败: %s", firstNonEmpty(resultError(results), "侧车无响应"))
		}
		var payload embedPayload
		if err := json.Unmarshal(results[0].Result, &payload); err != nil {
			return nil, fmt.Errorf("解析图片向量失败: %w", err)
		}
		return decodeQuantized(payload)
	default:
		results, err := e.text.RunBatch(ctx, map[string]any{"model": embedModel},
			[]SidecarItem{{ID: "query", Text: query}})
		if err != nil {
			return nil, err
		}
		if len(results) == 0 || !results[0].OK {
			return nil, fmt.Errorf("文本编码失败: %s", firstNonEmpty(resultError(results), "侧车无响应"))
		}
		var payload embedPayload
		if err := json.Unmarshal(results[0].Result, &payload); err != nil {
			return nil, fmt.Errorf("解析文本向量失败: %w", err)
		}
		return decodeQuantized(payload)
	}
}

func resultError(results []BatchResult) string {
	if len(results) == 0 {
		return ""
	}
	return results[0].Error
}

// decodeQuantized 把侧车返回的 int8 向量还原为 float32。
func decodeQuantized(payload embedPayload) ([]float32, error) {
	raw, err := base64.StdEncoding.DecodeString(payload.Vec)
	if err != nil || len(raw) != payload.Dim {
		return nil, fmt.Errorf("向量数据非法（dim=%d len=%d）", payload.Dim, len(raw))
	}
	out := make([]float32, len(raw))
	for i, b := range raw {
		out[i] = float32(int8(b)) * payload.Scale
	}
	return out, nil
}

// plainSearch 不做向量打分的结构化检索（关键词/文件名），SQL 分页，结果稳定。
func (e *Engine) plainSearch(filters ai_repo.SearchFilters, query, mode string, limit, offset int) (*model.AiSearchResponse, error) {
	source := "keyword"
	if mode == ModeFilename {
		filters.Filename = query
		source = "filename"
	} else {
		filters.Keyword = query
		mode = ModeKeyword
	}
	filters.Limit = limit
	filters.Offset = offset

	ids, total, err := ai_repo.SearchMediaIDs(filters)
	if err != nil {
		return nil, err
	}
	hits, err := buildHits(ids, nil, []string{source})
	if err != nil {
		return nil, err
	}
	return &model.AiSearchResponse{Hits: hits, Total: total, Mode: mode}, nil
}

// normalizeTags 清理筛选用的标签名：去空白、去空项、去重。
func normalizeTags(tags []string) []string {
	out := make([]string, 0, len(tags))
	seen := make(map[string]bool, len(tags))
	for _, tag := range tags {
		tag = strings.TrimSpace(tag)
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		out = append(out, tag)
	}
	return out
}

// semanticSearch 语义检索：结构化筛选出候选集，再用查询向量打分排序。
func (e *Engine) semanticSearch(ctx context.Context, filters ai_repo.SearchFilters, query string,
	vector []float32, limit, offset int, minScore float32) (*model.AiSearchResponse, error) {

	// 1) 结构化候选集（不含关键词）
	candidateFilters := filters
	candidateFilters.Limit = semanticCandidateCap
	candidateFilters.Offset = 0
	candidateIDs, _, err := ai_repo.SearchMediaIDs(candidateFilters)
	if err != nil {
		return nil, err
	}
	if len(candidateIDs) == 0 {
		return &model.AiSearchResponse{Hits: []model.AiSearchHit{}, Total: 0, Mode: ModeSemantic}, nil
	}

	allowed := make(map[uuid.UUID]bool, len(candidateIDs))
	for _, id := range candidateIDs {
		allowed[id] = true
	}

	// 2) 向量精确扫描（仅统计候选集内的媒体）
	hits, err := e.index.SearchVector(vector, len(candidateIDs), func(id uuid.UUID) bool { return allowed[id] })
	if err != nil {
		return nil, err
	}

	scores := make(map[uuid.UUID]float32, len(hits))
	ordered := make([]uuid.UUID, 0, len(hits))
	for _, hit := range hits {
		if hit.Score < minScore {
			continue
		}
		scores[hit.MediaID] = hit.Score
		ordered = append(ordered, hit.MediaID)
	}

	// 3) 关键词命中额外加分（混合检索：既"像"又"含"的结果排更前）
	sources := map[uuid.UUID][]string{}
	if strings.TrimSpace(query) != "" {
		keywordFilters := filters
		keywordFilters.Keyword = query
		keywordFilters.Limit = keywordCandidateCap
		keywordFilters.Offset = 0
		if keywordIDs, _, err := ai_repo.SearchMediaIDs(keywordFilters); err == nil {
			for _, id := range keywordIDs {
				sources[id] = []string{"keyword"}
				if _, exists := scores[id]; exists {
					scores[id] += keywordBoost
					continue
				}
				scores[id] = keywordBoost
				ordered = append(ordered, id)
			}
		}
	}

	sort.SliceStable(ordered, func(i, j int) bool { return scores[ordered[i]] > scores[ordered[j]] })

	total := len(ordered)
	page := paginate(ordered, offset, limit)

	pageScores := make([]float32, len(page))
	for i, id := range page {
		pageScores[i] = scores[id]
	}
	hitList, err := buildHits(page, pageScores, nil)
	if err != nil {
		return nil, err
	}
	for i := range hitList {
		if extra, ok := sources[page[i]]; ok {
			hitList[i].Source = append(hitList[i].Source, extra...)
		}
		hitList[i].Source = append([]string{"semantic"}, hitList[i].Source...)
	}

	return &model.AiSearchResponse{Hits: hitList, Total: total, Mode: ModeSemantic}, nil
}

func paginate(ids []uuid.UUID, offset, limit int) []uuid.UUID {
	if offset >= len(ids) {
		return nil
	}
	end := offset + limit
	if end > len(ids) {
		end = len(ids)
	}
	return ids[offset:end]
}

// buildHits 按给定顺序取回媒体资产并组装命中列表。
func buildHits(ids []uuid.UUID, scores []float32, sources []string) ([]model.AiSearchHit, error) {
	if len(ids) == 0 {
		return []model.AiSearchHit{}, nil
	}
	assets, err := gallery_repo.FetchMediaAssetsByIDs(ids)
	if err != nil {
		return nil, err
	}
	byID := make(map[uuid.UUID]model.MediaAsset, len(assets))
	for _, asset := range assets {
		byID[asset.ID] = asset
	}

	hits := make([]model.AiSearchHit, 0, len(ids))
	for i, id := range ids {
		asset, ok := byID[id]
		if !ok {
			continue // 已被删除
		}
		hit := model.AiSearchHit{MediaAsset: asset, Source: sources}
		if hit.Source == nil {
			hit.Source = []string{}
		}
		if i < len(scores) {
			hit.Score = float64(scores[i])
		}
		hits = append(hits, hit)
	}
	return hits, nil
}

// SimilarMedia 返回与指定媒体在视觉上最接近的其它媒体。
func (e *Engine) SimilarMedia(mediaID uuid.UUID, limit int) (*model.AiSearchResponse, error) {
	if limit <= 0 || limit > 200 {
		limit = 60
	}
	hits, err := e.index.SimilarTo(mediaID, limit)
	if err != nil {
		return nil, err
	}

	ids := make([]uuid.UUID, 0, len(hits))
	scores := make([]float32, 0, len(hits))
	for _, hit := range hits {
		ids = append(ids, hit.MediaID)
		scores = append(scores, hit.Score)
	}
	list, err := buildHits(ids, scores, []string{"semantic"})
	if err != nil {
		return nil, err
	}
	return &model.AiSearchResponse{Hits: list, Total: len(list), Mode: ModeSemantic}, nil
}

// SearchByImageBytes 以外部图片（上传内容）搜图：写入临时文件后编码。
func (e *Engine) SearchByImageBytes(ctx context.Context, path string, req SearchRequest) (*model.AiSearchResponse, error) {
	req.ImagePath = path
	req.Mode = ModeSemantic
	return e.Search(ctx, req)
}
