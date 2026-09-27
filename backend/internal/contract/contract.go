// Package contract 登记"服务端与各客户端共用的类型"，供 cmd/route_export 生成
// contract.json 与两端客户端代码（Dart / JS）。
//
// 这里是类型契约的**唯一**登记处：新增或修改交换类型时只改 Go 结构体本身，
// 客户端代码由生成器产出，不再手工同步。
//
// 注意：handler 里以匿名 gin.H 拼出的响应没有 Go 类型可登记，它们只出现在
// references/api/routes.json 里，不进本契约。
package contract

import (
	"monarch/internal/handler/data_handler"
	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/service/ai"
	"monarch/internal/service/comix"
	"monarch/internal/service/ops"
	"monarch/internal/service/proctask"
	"monarch/internal/service/review"
	"monarch/internal/settings"
)

// NamedType 一个需要生成到客户端契约里的类型。
type NamedType struct {
	Name string // 客户端侧的类型名，如 "MediaAsset"
	Type any    // 零值实例，如 model.MediaAsset{}
}

// Types 返回需要生成到客户端契约里的类型集合（一次登记，两端共用）。
//
// 顺序即生成顺序；结构体里嵌套的具名结构体会被递归发现并追加到末尾。
func Types() []NamedType {
	return []NamedType{
		// ---- gallery：媒体、标签、批次 ----
		{Name: "MediaAsset", Type: model.MediaAsset{}},
		{Name: "Tag", Type: model.Tag{}},
		{Name: "MediaTagLink", Type: model.MediaTagLink{}},
		{Name: "BatchData", Type: model.BatchData{}},
		{Name: "MediaQueryResponse", Type: model.MediaQueryResponse{}},
		{Name: "MediaPatchRequest", Type: model.MediaPatchRequest{}},
		{Name: "MediaPatchResponse", Type: model.MediaPatchResponse{}},
		{Name: "MediaTagsRequest", Type: model.MediaTagsRequest{}},
		{Name: "MediaTagsResponse", Type: model.MediaTagsResponse{}},
		{Name: "MediaTagsBatchRequest", Type: model.MediaTagsBatchRequest{}},
		{Name: "TagCreateRequest", Type: model.TagCreateRequest{}},
		{Name: "TagUpdateRequest", Type: model.TagUpdateRequest{}},
		{Name: "TagDeleteResponse", Type: model.TagDeleteResponse{}},
		{Name: "GalleryOverview", Type: model.GalleryOverview{}},

		// ---- comic：漫画浏览与离线下载 ----
		{Name: "ComicTotalMetaData", Type: model.ComicTotalMetaData{}},
		{Name: "ComicInfo", Type: model.ComicInfo{}},
		{Name: "ChapterInfo", Type: model.ChapterInfo{}},
		{Name: "ImageInfo", Type: model.ImageInfo{}},
		{Name: "SyncReadedRequest", Type: model.SyncReadedRequest{}},
		{Name: "SyncReadedResponse", Type: model.SyncReadedResponse{}},
		{Name: "UpdateComicRequest", Type: model.UpdateComicRequest{}},

		// ---- 外部命令任务（comix 爬虫与 gallery CLI 共用同一任务引擎类型）----
		{Name: "ProcTask", Type: proctask.Task{}},
		{Name: "ProcTaskLog", Type: proctask.LogEntry{}},
		{Name: "ComixResult", Type: comix.Result{}},

		// ---- ai：队列、能力、检索、人物、去重 ----
		{Name: "AiStatus", Type: ai.Status{}},
		{Name: "AiJob", Type: model.AiJob{}},
		{Name: "AiCapabilityInfo", Type: model.AiCapabilityInfo{}},
		{Name: "AiImplementation", Type: model.AiImplementation{}},
		{Name: "AiResultSpec", Type: model.AiResultSpec{}},
		{Name: "AiPerson", Type: model.AiPerson{}},
		{Name: "AiFace", Type: model.AiFace{}},
		{Name: "AiMediaDetail", Type: model.AiMediaDetail{}},
		{Name: "AiSearchHit", Type: model.AiSearchHit{}},
		{Name: "AiSearchResponse", Type: model.AiSearchResponse{}},
		{Name: "DuplicateGroup", Type: model.DuplicateGroup{}},
		{Name: "ReviewPreset", Type: ai_repo.ReviewPreset{}},
		{Name: "ReviewResult", Type: review.Result{}},

		// ---- user-data：随笔与打卡 ----
		{Name: "EssayArticle", Type: model.EssayArticle{}},
		{Name: "EssayLabel", Type: model.EssayLabel{}},
		{Name: "EssayYearSummary", Type: model.EssayYearSummary{}},
		{Name: "BookletStyle", Type: model.BookletStyle{}},
		{Name: "BookletRecord", Type: model.BookletRecord{}},
		{Name: "CheckImagesRequest", Type: data_handler.CheckImagesRequest{}},
		{Name: "CheckImagesResponse", Type: data_handler.CheckImagesResponse{}},

		// ---- ops：gallery CLI 任务与页面偏好 ----
		{Name: "GalleryOptions", Type: ops.GalleryOptions{}},
		{Name: "OpsPreferences", Type: ops.Preferences{}},
		{Name: "DirEntry", Type: ops.DirEntry{}},
		{Name: "Dependency", Type: ops.Dependency{}},

		// ---- settings：schema 驱动的运行时配置 ----
		{Name: "SettingSpec", Type: settings.Spec{}},
		{Name: "SettingOption", Type: settings.Option{}},
	}
}
