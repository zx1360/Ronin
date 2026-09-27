package model

import (
	"encoding/json"

	"github.com/google/uuid"
)

// MediaAsset 对应数据库的 gallery_media_assets 表
type MediaAsset struct {
	ID          uuid.UUID  `json:"id"`
	CreatedAt   FlexTime   `json:"created_at"`
	UpdatedAt   FlexTime   `json:"updated_at"`
	CapturedAt  FlexTime   `json:"captured_at"`
	FilePath    string     `json:"file_path"`
	ThumbPath   *string    `json:"thumb_path"`
	PreviewPath *string    `json:"preview_path"`
	Hash        []byte     `json:"hash"`
	SizeBytes   int64      `json:"size_bytes"`
	MimeType    *string    `json:"mime_type"`
	IsDeleted   bool       `json:"is_deleted"`
	SyncCount   int        `json:"sync_count"`
	GroupID     *uuid.UUID `json:"group_id"`
	Message     string     `json:"message"`
	EditParams  *string    `json:"edit_params"`
}

// Tag 对应数据库的 tags 表（树状结构）
type Tag struct {
	ID         uuid.UUID  `json:"id"`
	CreatedAt  FlexTime   `json:"created_at"`
	UpdatedAt  FlexTime   `json:"updated_at"`
	Name       string     `json:"name"`
	ParentID   *uuid.UUID `json:"parent_id"`
	FullPath   string     `json:"full_path"`
	IsFavorite bool       `json:"is_favorite"`
	// MediaCount 该标签直接关联的未删除媒体数；仅 GET /api/gallery/tags 统计填充
	MediaCount int `json:"media_count"`
}

// MediaTagLink 对应数据库的 media_tag_links 表
type MediaTagLink struct {
	MediaID uuid.UUID `json:"media_id"`
	TagID   uuid.UUID `json:"tag_id"`
}

// GalleryBatchResponse /api/gallery/batch 响应结构
type BatchData struct {
	MediaAssets   []MediaAsset   `json:"media_assets"`
	Tags          []Tag          `json:"tags"`
	MediaTagLinks []MediaTagLink `json:"media_tag_links"`
}

// TagCreateRequest POST /api/gallery/tags 请求结构
type TagCreateRequest struct {
	Name     string     `json:"name"`
	ParentID *uuid.UUID `json:"parent_id"`
}

// TagUpdateRequest PUT /api/gallery/tags/:id 请求结构
//
// 字段为"缺省即不修改"：ParentID 显式传 null 表示移动到根级。
type TagUpdateRequest struct {
	Name       *string         `json:"name"`
	ParentID   json.RawMessage `json:"parent_id"`
	IsFavorite *bool           `json:"is_favorite"`
}

// TagDeleteResponse DELETE /api/gallery/tags/:id 响应结构（含被级联删除的子孙）
type TagDeleteResponse struct {
	DeletedIDs []uuid.UUID `json:"deleted_ids"`
}

// MediaQueryParams GET /api/gallery/media 查询参数
type MediaQueryParams struct {
	TagIDs             string `form:"tag_ids"`             // 逗号分隔的标签 ID, 任一命中
	IncludeDescendants bool   `form:"include_descendants"` // 标签筛选是否包含子孙标签
	Untagged           bool   `form:"untagged"`            // 仅返回未打标签的媒体
	VLMTags            string `form:"vlm_tags"`            // 逗号分隔的 AI 标签, 任一命中（只读, 与人工标签无关）
	IncludeDeleted     bool   `form:"include_deleted"`     // 是否包含已软删除的媒体
	OnlyDeleted        bool   `form:"only_deleted"`        // 仅返回已软删除的媒体（优先级高于 include_deleted）
	MimeType           string `form:"mime_type"`           // image / video / image/jpeg
	IDs                string `form:"ids"`                 // 逗号分隔的媒体 ID, 指定则只查这些
	SortBy             string `form:"sort_by"`             // captured_at(默认) / sync_count / size_bytes / file_path
	SortOrder          string `form:"sort_order"`          // desc(默认) / asc
	Limit              int    `form:"limit"`               // 默认 60, 上限 1000
	Offset             int    `form:"offset"`
}

// MediaQueryResponse GET /api/gallery/media 响应结构
type MediaQueryResponse struct {
	MediaAssets   []MediaAsset   `json:"media_assets"`
	MediaTagLinks []MediaTagLink `json:"media_tag_links"`
	Total         int            `json:"total"`
}

// MediaTagsRequest PUT /api/gallery/media/:id/tags 请求结构（全量替换该媒体的标签集合）
type MediaTagsRequest struct {
	TagIDs []uuid.UUID `json:"tag_ids"`
}

// MediaTagsResponse PUT /api/gallery/media/:id/tags 响应结构
type MediaTagsResponse struct {
	MediaID uuid.UUID   `json:"media_id"`
	TagIDs  []uuid.UUID `json:"tag_ids"`
}

// MediaTagsBatchRequest POST /api/gallery/media/tags 请求结构（多媒体的标签增删）
type MediaTagsBatchRequest struct {
	MediaIDs     []uuid.UUID `json:"media_ids"`
	AddTagIDs    []uuid.UUID `json:"add_tag_ids"`
	RemoveTagIDs []uuid.UUID `json:"remove_tag_ids"`
}

// MediaPatchRequest PATCH /api/gallery/media 请求结构
//
// 除 MediaIDs 外均为"缺省即不修改"：
//   - Message 传空串表示清空（落库为 NULL）
//   - GroupID 传 null 表示解绑，传 UUID 表示捆绑到该主文件
//   - EditParams 传 null 表示清除，传 JSON 字符串/对象表示设置
//   - MarkProcessed 为 true 时 sync_count + 1（批次处理游标）
type MediaPatchRequest struct {
	MediaIDs      []uuid.UUID     `json:"media_ids"`
	IsDeleted     *bool           `json:"is_deleted"`
	Message       *string         `json:"message"`
	GroupID       json.RawMessage `json:"group_id"`
	EditParams    json.RawMessage `json:"edit_params"`
	MarkProcessed bool            `json:"mark_processed"`
}

// MediaPatchResponse PATCH /api/gallery/media 响应结构（返回更新后的行, 供客户端刷新缓存）
type MediaPatchResponse struct {
	MediaAssets []MediaAsset `json:"media_assets"`
}

// GalleryOverview  /api/gallery/overview 响应结构
type GalleryOverview struct {
	TotalMedia int            `json:"total_media"`
	ImageCount int            `json:"image_count"`
	VideoCount int            `json:"video_count"`
	ImageRatio float64        `json:"image_ratio"`
	VideoRatio float64        `json:"video_ratio"`
	TotalTags  int            `json:"total_tags"`
	RootTags   int            `json:"root_tags"`
	TotalLinks int            `json:"total_links"`
	TotalSize  int64          `json:"total_size"`
	MinYear    int            `json:"min_year"`
	MaxYear    int            `json:"max_year"`
	SyncStats  SyncStatsData  `json:"sync_stats"`
	YearStats  []YearStatItem `json:"year_stats"`
}

type SyncStatsData struct {
	MinSyncCount int     `json:"min_sync_count"`
	MaxSyncCount int     `json:"max_sync_count"`
	AvgSyncCount float64 `json:"avg_sync_count"`
}

type YearStatItem struct {
	Year       int `json:"year"`
	MediaCount int `json:"media_count"`
}

// BatchQueryParams /api/gallery/batch 查询参数
type BatchQueryParams struct {
	Limit         int    `form:"limit" json:"limit"`
	Offset        int    `form:"offset" json:"offset"`
	MimeType      string `form:"mime_type" json:"mime_type"`           // 空=全部, image, video, image/jpeg 等
	SortBy        string `form:"sort_by" json:"sort_by"`               // sync_count, captured_at, size_bytes, file_path
	SortOrder     string `form:"sort_order" json:"sort_order"`         // asc, desc
	Year          int    `form:"year" json:"year"`                     // 筛选年份, 0=不筛选
	Month         int    `form:"month" json:"month"`                   // 筛选月份, 0=不筛选 (需同时指定year)
	Day           int    `form:"day" json:"day"`                       // 筛选日期, 0=不筛选 (需同时指定year, month)
	SecondarySort string `form:"secondary_sort" json:"secondary_sort"` // 二次排序字段, 空=不进行二次排序
}
