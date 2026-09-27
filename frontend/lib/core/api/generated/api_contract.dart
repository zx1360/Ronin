// 由 backend/cmd/route_export 生成，请勿手改。
// 重新生成：cd backend && go run ./cmd/route_export
// 类型登记见 backend/internal/contract，路由来自 gin 路由表。
//
// 说明：时间（FlexTime / time.Time）与 uuid.UUID 一律保留 wire 上的字符串形态；
// json.RawMessage 映射为 Object?（不透明 JSON）；[]byte 映射为 base64 字符串。

abstract final class ApiPath {
  static const String aiCancel = '/API/ai/cancel';
  static const String aiCapabilities = '/API/ai/capabilities';
  static const String aiChat = '/API/ai/chat';
  static const String aiDuplicates = '/API/ai/duplicates';
  static const String aiDuplicatesIgnore = '/API/ai/duplicates/ignore';
  static const String aiDuplicatesIgnored = '/API/ai/duplicates/ignored';
  static const String aiDuplicatesUnignore = '/API/ai/duplicates/unignore';
  static const String aiEnqueue = '/API/ai/enqueue';
  static const String aiFacesAssign = '/API/ai/faces/assign';
  static const String aiIndexRebuild = '/API/ai/index/rebuild';
  static const String aiJobs = '/API/ai/jobs';
  static const String aiMediaId = '/API/ai/media/:id';
  static const String aiPersons = '/API/ai/persons';
  static const String aiPersonsId = '/API/ai/persons/:id';
  static const String aiPersonsIdPatch = '/API/ai/persons/:id';
  static const String aiPersonsIdFaces = '/API/ai/persons/:id/faces';
  static const String aiPersonsMerge = '/API/ai/persons/merge';
  static const String aiProcessCapabilityStart = '/API/ai/process/:capability/start';
  static const String aiProcessCapabilityStop = '/API/ai/process/:capability/stop';
  static const String aiRecluster = '/API/ai/recluster';
  static const String aiResume = '/API/ai/resume';
  static const String aiRetry = '/API/ai/retry';
  static const String aiReview = '/API/ai/review';
  static const String aiReviewPresets = '/API/ai/review/presets';
  static const String aiReviewPresetsPost = '/API/ai/review/presets';
  static const String aiReviewPresetsId = '/API/ai/review/presets/:id';
  static const String aiSearch = '/API/ai/search';
  static const String aiSearchImage = '/API/ai/search/image';
  static const String aiSimilarId = '/API/ai/similar/:id';
  static const String aiStatus = '/API/ai/status';
  static const String aiTags = '/API/ai/tags';
  static const String comicChapterInfoChapterId = '/API/comic/chapter-info/:chapter-id';
  static const String comicComicInfo = '/API/comic/comic-info';
  static const String comicComicInfoComicId = '/API/comic/comic-info/:comic-id';
  static const String comicComicInfoComicIdGet = '/API/comic/comic-info/:comic-id';
  static const String comicComicInfoComicIdPut = '/API/comic/comic-info/:comic-id';
  static const String comicDownloadComicId = '/API/comic/download/:comic-id';
  static const String comicMetaInfo = '/API/comic/meta-info';
  static const String comicSyncReaded = '/API/comic/sync-readed';
  static const String comixChaptersComicId = '/API/comix/chapters/:comic-id';
  static const String comixClean = '/API/comix/clean';
  static const String comixConfig = '/API/comix/config';
  static const String comixDelete = '/API/comix/delete';
  static const String comixDownload = '/API/comix/download';
  static const String comixDownloadUrl = '/API/comix/download-url';
  static const String comixInit = '/API/comix/init';
  static const String comixList = '/API/comix/list';
  static const String comixSites = '/API/comix/sites';
  static const String comixTasks = '/API/comix/tasks';
  static const String comixTasksTaskId = '/API/comix/tasks/:task-id';
  static const String comixTasksTaskIdStop = '/API/comix/tasks/:task-id/stop';
  static const String comixUpdateCheck = '/API/comix/update-check';
  static const String galleryIdType = '/API/gallery/:id/:type';
  static const String galleryBatch = '/API/gallery/batch';
  static const String galleryMedia = '/API/gallery/media';
  static const String galleryMediaPatch = '/API/gallery/media';
  static const String galleryMediaIdTags = '/API/gallery/media/:id/tags';
  static const String galleryMediaTags = '/API/gallery/media/tags';
  static const String galleryOverview = '/API/gallery/overview';
  static const String galleryTags = '/API/gallery/tags';
  static const String galleryTagsPost = '/API/gallery/tags';
  static const String galleryTagsId = '/API/gallery/tags/:id';
  static const String galleryTagsIdPut = '/API/gallery/tags/:id';
  static const String opsCapabilities = '/API/ops/capabilities';
  static const String opsDependencies = '/API/ops/dependencies';
  static const String opsFs = '/API/ops/fs';
  static const String opsGalleryTasks = '/API/ops/gallery/tasks';
  static const String opsGalleryTasksPost = '/API/ops/gallery/tasks';
  static const String opsGalleryTasksTaskId = '/API/ops/gallery/tasks/:task-id';
  static const String opsGalleryTasksTaskIdStop = '/API/ops/gallery/tasks/:task-id/stop';
  static const String opsOverview = '/API/ops/overview';
  static const String opsPreferences = '/API/ops/preferences';
  static const String opsPreferencesPut = '/API/ops/preferences';
  static const String opsReveal = '/API/ops/reveal';
  static const String ops = '/ops';
  static const String opsFilepath = '/ops/*filepath';
  static const String opsFilepathHead = '/ops/*filepath';
  static const String root = '/';
  static const String settings = '/API/settings';
  static const String settingsPut = '/API/settings';
  static const String staticFilepath = '/static/*filepath';
  static const String staticFilepathHead = '/static/*filepath';
  static const String test = '/API/test';
  static const String userDataBackupModule = '/API/user-data/backup/:module';
  static const String userDataCheckImagesModule = '/API/user-data/check-images/:module';
  static const String userDataSyncModule = '/API/user-data/sync/:module';

  /// GET /API/ai/media/:id
  static String aiMediaIdPath(String id) {
    return '/API/ai/media/${Uri.encodeComponent(id)}';
  }

  /// DELETE /API/ai/persons/:id
  static String aiPersonsIdPath(String id) {
    return '/API/ai/persons/${Uri.encodeComponent(id)}';
  }

  /// PATCH /API/ai/persons/:id
  static String aiPersonsIdPatchPath(String id) {
    return '/API/ai/persons/${Uri.encodeComponent(id)}';
  }

  /// GET /API/ai/persons/:id/faces
  static String aiPersonsIdFacesPath(String id) {
    return '/API/ai/persons/${Uri.encodeComponent(id)}/faces';
  }

  /// POST /API/ai/process/:capability/start
  static String aiProcessCapabilityStartPath(String capability) {
    return '/API/ai/process/${Uri.encodeComponent(capability)}/start';
  }

  /// POST /API/ai/process/:capability/stop
  static String aiProcessCapabilityStopPath(String capability) {
    return '/API/ai/process/${Uri.encodeComponent(capability)}/stop';
  }

  /// DELETE /API/ai/review/presets/:id
  static String aiReviewPresetsIdPath(String id) {
    return '/API/ai/review/presets/${Uri.encodeComponent(id)}';
  }

  /// GET /API/ai/similar/:id
  static String aiSimilarIdPath(String id) {
    return '/API/ai/similar/${Uri.encodeComponent(id)}';
  }

  /// GET /API/comic/chapter-info/:chapter-id
  static String comicChapterInfoChapterIdPath(String chapterId) {
    return '/API/comic/chapter-info/${Uri.encodeComponent(chapterId)}';
  }

  /// DELETE /API/comic/comic-info/:comic-id
  static String comicComicInfoComicIdPath(String comicId) {
    return '/API/comic/comic-info/${Uri.encodeComponent(comicId)}';
  }

  /// GET /API/comic/comic-info/:comic-id
  static String comicComicInfoComicIdGetPath(String comicId) {
    return '/API/comic/comic-info/${Uri.encodeComponent(comicId)}';
  }

  /// PUT /API/comic/comic-info/:comic-id
  static String comicComicInfoComicIdPutPath(String comicId) {
    return '/API/comic/comic-info/${Uri.encodeComponent(comicId)}';
  }

  /// GET /API/comic/download/:comic-id
  static String comicDownloadComicIdPath(String comicId) {
    return '/API/comic/download/${Uri.encodeComponent(comicId)}';
  }

  /// GET /API/comix/chapters/:comic-id
  static String comixChaptersComicIdPath(String comicId) {
    return '/API/comix/chapters/${Uri.encodeComponent(comicId)}';
  }

  /// GET /API/comix/tasks/:task-id
  static String comixTasksTaskIdPath(String taskId) {
    return '/API/comix/tasks/${Uri.encodeComponent(taskId)}';
  }

  /// POST /API/comix/tasks/:task-id/stop
  static String comixTasksTaskIdStopPath(String taskId) {
    return '/API/comix/tasks/${Uri.encodeComponent(taskId)}/stop';
  }

  /// GET /API/gallery/:id/:type
  static String galleryIdTypePath(String id, String type) {
    return '/API/gallery/${Uri.encodeComponent(id)}/${Uri.encodeComponent(type)}';
  }

  /// PUT /API/gallery/media/:id/tags
  static String galleryMediaIdTagsPath(String id) {
    return '/API/gallery/media/${Uri.encodeComponent(id)}/tags';
  }

  /// DELETE /API/gallery/tags/:id
  static String galleryTagsIdPath(String id) {
    return '/API/gallery/tags/${Uri.encodeComponent(id)}';
  }

  /// PUT /API/gallery/tags/:id
  static String galleryTagsIdPutPath(String id) {
    return '/API/gallery/tags/${Uri.encodeComponent(id)}';
  }

  /// GET /API/ops/gallery/tasks/:task-id
  static String opsGalleryTasksTaskIdPath(String taskId) {
    return '/API/ops/gallery/tasks/${Uri.encodeComponent(taskId)}';
  }

  /// POST /API/ops/gallery/tasks/:task-id/stop
  static String opsGalleryTasksTaskIdStopPath(String taskId) {
    return '/API/ops/gallery/tasks/${Uri.encodeComponent(taskId)}/stop';
  }

  /// GET /ops/*filepath
  static String opsFilepathPath(String filepath) {
    return '/ops/$filepath';
  }

  /// HEAD /ops/*filepath
  static String opsFilepathHeadPath(String filepath) {
    return '/ops/$filepath';
  }

  /// GET /static/*filepath
  static String staticFilepathPath(String filepath) {
    return '/static/$filepath';
  }

  /// HEAD /static/*filepath
  static String staticFilepathHeadPath(String filepath) {
    return '/static/$filepath';
  }

  /// POST /API/user-data/backup/:module
  static String userDataBackupModulePath(String module) {
    return '/API/user-data/backup/${Uri.encodeComponent(module)}';
  }

  /// POST /API/user-data/check-images/:module
  static String userDataCheckImagesModulePath(String module) {
    return '/API/user-data/check-images/${Uri.encodeComponent(module)}';
  }

  /// GET /API/user-data/sync/:module
  static String userDataSyncModulePath(String module) {
    return '/API/user-data/sync/${Uri.encodeComponent(module)}';
  }
}

/// model.MediaAsset
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.capturedAt,
    required this.filePath,
    this.thumbPath,
    this.previewPath,
    required this.hash,
    required this.sizeBytes,
    this.mimeType,
    required this.isDeleted,
    required this.syncCount,
    this.groupId,
    required this.message,
    this.editParams,
  });

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      id: _asString(json['id']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
      capturedAt: _asString(json['captured_at']),
      filePath: _asString(json['file_path']),
      thumbPath: json['thumb_path'] == null ? null : _asString(json['thumb_path']),
      previewPath: json['preview_path'] == null ? null : _asString(json['preview_path']),
      hash: _asString(json['hash']),
      sizeBytes: _asInt(json['size_bytes']),
      mimeType: json['mime_type'] == null ? null : _asString(json['mime_type']),
      isDeleted: _asBool(json['is_deleted']),
      syncCount: _asInt(json['sync_count']),
      groupId: json['group_id'] == null ? null : _asString(json['group_id']),
      message: _asString(json['message']),
      editParams: json['edit_params'] == null ? null : _asString(json['edit_params']),
    );
  }

  final String id;
  final String createdAt;
  final String updatedAt;
  final String capturedAt;
  final String filePath;
  final String? thumbPath;
  final String? previewPath;
  final String hash;
  final int sizeBytes;
  final String? mimeType;
  final bool isDeleted;
  final int syncCount;
  final String? groupId;
  final String message;
  final String? editParams;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'captured_at': capturedAt,
      'file_path': filePath,
      'thumb_path': thumbPath,
      'preview_path': previewPath,
      'hash': hash,
      'size_bytes': sizeBytes,
      'mime_type': mimeType,
      'is_deleted': isDeleted,
      'sync_count': syncCount,
      'group_id': groupId,
      'message': message,
      'edit_params': editParams,
    };
  }
}

/// model.Tag
class Tag {
  const Tag({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.name,
    this.parentId,
    required this.fullPath,
    required this.isFavorite,
    required this.mediaCount,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: _asString(json['id']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
      name: _asString(json['name']),
      parentId: json['parent_id'] == null ? null : _asString(json['parent_id']),
      fullPath: _asString(json['full_path']),
      isFavorite: _asBool(json['is_favorite']),
      mediaCount: _asInt(json['media_count']),
    );
  }

  final String id;
  final String createdAt;
  final String updatedAt;
  final String name;
  final String? parentId;
  final String fullPath;
  final bool isFavorite;
  final int mediaCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'name': name,
      'parent_id': parentId,
      'full_path': fullPath,
      'is_favorite': isFavorite,
      'media_count': mediaCount,
    };
  }
}

/// model.MediaTagLink
class MediaTagLink {
  const MediaTagLink({
    required this.mediaId,
    required this.tagId,
  });

  factory MediaTagLink.fromJson(Map<String, dynamic> json) {
    return MediaTagLink(
      mediaId: _asString(json['media_id']),
      tagId: _asString(json['tag_id']),
    );
  }

  final String mediaId;
  final String tagId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'media_id': mediaId,
      'tag_id': tagId,
    };
  }
}

/// model.BatchData
class BatchData {
  const BatchData({
    required this.mediaAssets,
    required this.tags,
    required this.mediaTagLinks,
  });

  factory BatchData.fromJson(Map<String, dynamic> json) {
    return BatchData(
      mediaAssets: (json['media_assets'] as List<dynamic>? ?? const <dynamic>[]).map((e) => MediaAsset.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[]).map((e) => Tag.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      mediaTagLinks: (json['media_tag_links'] as List<dynamic>? ?? const <dynamic>[]).map((e) => MediaTagLink.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
    );
  }

  final List<MediaAsset> mediaAssets;
  final List<Tag> tags;
  final List<MediaTagLink> mediaTagLinks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'media_assets': mediaAssets.map((e) => e.toJson()).toList(),
      'tags': tags.map((e) => e.toJson()).toList(),
      'media_tag_links': mediaTagLinks.map((e) => e.toJson()).toList(),
    };
  }
}

/// model.MediaQueryResponse
class MediaQueryResponse {
  const MediaQueryResponse({
    required this.mediaAssets,
    required this.mediaTagLinks,
    required this.total,
  });

  factory MediaQueryResponse.fromJson(Map<String, dynamic> json) {
    return MediaQueryResponse(
      mediaAssets: (json['media_assets'] as List<dynamic>? ?? const <dynamic>[]).map((e) => MediaAsset.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      mediaTagLinks: (json['media_tag_links'] as List<dynamic>? ?? const <dynamic>[]).map((e) => MediaTagLink.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      total: _asInt(json['total']),
    );
  }

  final List<MediaAsset> mediaAssets;
  final List<MediaTagLink> mediaTagLinks;
  final int total;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'media_assets': mediaAssets.map((e) => e.toJson()).toList(),
      'media_tag_links': mediaTagLinks.map((e) => e.toJson()).toList(),
      'total': total,
    };
  }
}

/// model.MediaPatchRequest
class MediaPatchRequest {
  const MediaPatchRequest({
    required this.mediaIds,
    this.isDeleted,
    this.message,
    this.groupId,
    this.editParams,
    required this.markProcessed,
  });

  factory MediaPatchRequest.fromJson(Map<String, dynamic> json) {
    return MediaPatchRequest(
      mediaIds: (json['media_ids'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      isDeleted: json['is_deleted'] == null ? null : _asBool(json['is_deleted']),
      message: json['message'] == null ? null : _asString(json['message']),
      groupId: json['group_id'],
      editParams: json['edit_params'],
      markProcessed: _asBool(json['mark_processed']),
    );
  }

  final List<String> mediaIds;
  final bool? isDeleted;
  final String? message;
  final Object? groupId;
  final Object? editParams;
  final bool markProcessed;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'media_ids': mediaIds,
      'is_deleted': isDeleted,
      'message': message,
      'group_id': groupId,
      'edit_params': editParams,
      'mark_processed': markProcessed,
    };
  }
}

/// model.MediaPatchResponse
class MediaPatchResponse {
  const MediaPatchResponse({
    required this.mediaAssets,
  });

  factory MediaPatchResponse.fromJson(Map<String, dynamic> json) {
    return MediaPatchResponse(
      mediaAssets: (json['media_assets'] as List<dynamic>? ?? const <dynamic>[]).map((e) => MediaAsset.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
    );
  }

  final List<MediaAsset> mediaAssets;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'media_assets': mediaAssets.map((e) => e.toJson()).toList(),
    };
  }
}

/// model.MediaTagsRequest
class MediaTagsRequest {
  const MediaTagsRequest({
    required this.tagIds,
  });

  factory MediaTagsRequest.fromJson(Map<String, dynamic> json) {
    return MediaTagsRequest(
      tagIds: (json['tag_ids'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
    );
  }

  final List<String> tagIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tag_ids': tagIds,
    };
  }
}

/// model.MediaTagsResponse
class MediaTagsResponse {
  const MediaTagsResponse({
    required this.mediaId,
    required this.tagIds,
  });

  factory MediaTagsResponse.fromJson(Map<String, dynamic> json) {
    return MediaTagsResponse(
      mediaId: _asString(json['media_id']),
      tagIds: (json['tag_ids'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
    );
  }

  final String mediaId;
  final List<String> tagIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'media_id': mediaId,
      'tag_ids': tagIds,
    };
  }
}

/// model.MediaTagsBatchRequest
class MediaTagsBatchRequest {
  const MediaTagsBatchRequest({
    required this.mediaIds,
    required this.addTagIds,
    required this.removeTagIds,
  });

  factory MediaTagsBatchRequest.fromJson(Map<String, dynamic> json) {
    return MediaTagsBatchRequest(
      mediaIds: (json['media_ids'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      addTagIds: (json['add_tag_ids'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      removeTagIds: (json['remove_tag_ids'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
    );
  }

  final List<String> mediaIds;
  final List<String> addTagIds;
  final List<String> removeTagIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'media_ids': mediaIds,
      'add_tag_ids': addTagIds,
      'remove_tag_ids': removeTagIds,
    };
  }
}

/// model.TagCreateRequest
class TagCreateRequest {
  const TagCreateRequest({
    required this.name,
    this.parentId,
  });

  factory TagCreateRequest.fromJson(Map<String, dynamic> json) {
    return TagCreateRequest(
      name: _asString(json['name']),
      parentId: json['parent_id'] == null ? null : _asString(json['parent_id']),
    );
  }

  final String name;
  final String? parentId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'parent_id': parentId,
    };
  }
}

/// model.TagUpdateRequest
class TagUpdateRequest {
  const TagUpdateRequest({
    this.name,
    this.parentId,
    this.isFavorite,
  });

  factory TagUpdateRequest.fromJson(Map<String, dynamic> json) {
    return TagUpdateRequest(
      name: json['name'] == null ? null : _asString(json['name']),
      parentId: json['parent_id'],
      isFavorite: json['is_favorite'] == null ? null : _asBool(json['is_favorite']),
    );
  }

  final String? name;
  final Object? parentId;
  final bool? isFavorite;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'parent_id': parentId,
      'is_favorite': isFavorite,
    };
  }
}

/// model.TagDeleteResponse
class TagDeleteResponse {
  const TagDeleteResponse({
    required this.deletedIds,
  });

  factory TagDeleteResponse.fromJson(Map<String, dynamic> json) {
    return TagDeleteResponse(
      deletedIds: (json['deleted_ids'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
    );
  }

  final List<String> deletedIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'deleted_ids': deletedIds,
    };
  }
}

/// model.GalleryOverview
class GalleryOverview {
  const GalleryOverview({
    required this.totalMedia,
    required this.imageCount,
    required this.videoCount,
    required this.imageRatio,
    required this.videoRatio,
    required this.totalTags,
    required this.rootTags,
    required this.totalLinks,
    required this.totalSize,
    required this.minYear,
    required this.maxYear,
    required this.syncStats,
    required this.yearStats,
  });

  factory GalleryOverview.fromJson(Map<String, dynamic> json) {
    return GalleryOverview(
      totalMedia: _asInt(json['total_media']),
      imageCount: _asInt(json['image_count']),
      videoCount: _asInt(json['video_count']),
      imageRatio: _asDouble(json['image_ratio']),
      videoRatio: _asDouble(json['video_ratio']),
      totalTags: _asInt(json['total_tags']),
      rootTags: _asInt(json['root_tags']),
      totalLinks: _asInt(json['total_links']),
      totalSize: _asInt(json['total_size']),
      minYear: _asInt(json['min_year']),
      maxYear: _asInt(json['max_year']),
      syncStats: SyncStatsData.fromJson((json['sync_stats'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      yearStats: (json['year_stats'] as List<dynamic>? ?? const <dynamic>[]).map((e) => YearStatItem.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
    );
  }

  final int totalMedia;
  final int imageCount;
  final int videoCount;
  final double imageRatio;
  final double videoRatio;
  final int totalTags;
  final int rootTags;
  final int totalLinks;
  final int totalSize;
  final int minYear;
  final int maxYear;
  final SyncStatsData syncStats;
  final List<YearStatItem> yearStats;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total_media': totalMedia,
      'image_count': imageCount,
      'video_count': videoCount,
      'image_ratio': imageRatio,
      'video_ratio': videoRatio,
      'total_tags': totalTags,
      'root_tags': rootTags,
      'total_links': totalLinks,
      'total_size': totalSize,
      'min_year': minYear,
      'max_year': maxYear,
      'sync_stats': syncStats.toJson(),
      'year_stats': yearStats.map((e) => e.toJson()).toList(),
    };
  }
}

/// model.ComicTotalMetaData
class ComicTotalMetaData {
  const ComicTotalMetaData({
    required this.bookCount,
    required this.totalChapterCount,
    required this.totalImageCount,
    required this.updatedAt,
  });

  factory ComicTotalMetaData.fromJson(Map<String, dynamic> json) {
    return ComicTotalMetaData(
      bookCount: _asInt(json['book_count']),
      totalChapterCount: _asInt(json['total_chapter_count']),
      totalImageCount: _asInt(json['total_image_count']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  final int bookCount;
  final int totalChapterCount;
  final int totalImageCount;
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'book_count': bookCount,
      'total_chapter_count': totalChapterCount,
      'total_image_count': totalImageCount,
      'updated_at': updatedAt,
    };
  }
}

/// model.ComicInfo
class ComicInfo {
  const ComicInfo({
    required this.id,
    required this.title,
    required this.chapterCount,
    required this.imageCount,
    required this.coverImage,
    required this.isPublic,
    required this.readed,
  });

  factory ComicInfo.fromJson(Map<String, dynamic> json) {
    return ComicInfo(
      id: _asString(json['id']),
      title: _asString(json['title']),
      chapterCount: _asInt(json['chapter_count']),
      imageCount: _asInt(json['image_count']),
      coverImage: _asString(json['cover_image']),
      isPublic: _asBool(json['is_public']),
      readed: _asBool(json['readed']),
    );
  }

  final String id;
  final String title;
  final int chapterCount;
  final int imageCount;
  final String coverImage;
  final bool isPublic;
  final bool readed;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'chapter_count': chapterCount,
      'image_count': imageCount,
      'cover_image': coverImage,
      'is_public': isPublic,
      'readed': readed,
    };
  }
}

/// model.ChapterInfo
class ChapterInfo {
  const ChapterInfo({
    required this.id,
    required this.comicId,
    required this.dirName,
    required this.chapterIndex,
    required this.imageCount,
    this.images,
  });

  factory ChapterInfo.fromJson(Map<String, dynamic> json) {
    return ChapterInfo(
      id: _asString(json['id']),
      comicId: _asString(json['comic_id']),
      dirName: _asString(json['dir_name']),
      chapterIndex: _asInt(json['chapter_index']),
      imageCount: _asInt(json['image_count']),
      images: json['images'] == null ? null : (json['images'] as List<dynamic>).map((e) => ImageInfo.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
    );
  }

  final String id;
  final String comicId;
  final String dirName;
  final int chapterIndex;
  final int imageCount;
  final List<ImageInfo>? images;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'comic_id': comicId,
      'dir_name': dirName,
      'chapter_index': chapterIndex,
      'image_count': imageCount,
      'images': images?.map((e) => e.toJson()).toList(),
    };
  }
}

/// model.ImageInfo
class ImageInfo {
  const ImageInfo({
    required this.path,
    required this.width,
    required this.height,
  });

  factory ImageInfo.fromJson(Map<String, dynamic> json) {
    return ImageInfo(
      path: _asString(json['path']),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
    );
  }

  final String path;
  final int width;
  final int height;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'path': path,
      'width': width,
      'height': height,
    };
  }
}

/// model.SyncReadedRequest
class SyncReadedRequest {
  const SyncReadedRequest({
    required this.readedIds,
  });

  factory SyncReadedRequest.fromJson(Map<String, dynamic> json) {
    return SyncReadedRequest(
      readedIds: (json['readed_ids'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
    );
  }

  final List<String> readedIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'readed_ids': readedIds,
    };
  }
}

/// model.SyncReadedResponse
class SyncReadedResponse {
  const SyncReadedResponse({
    required this.updatedCount,
    required this.newChapters,
  });

  factory SyncReadedResponse.fromJson(Map<String, dynamic> json) {
    return SyncReadedResponse(
      updatedCount: _asInt(json['updated_count']),
      newChapters: (json['new_chapters'] as Map<String, dynamic>? ?? const <String, dynamic>{}).map((k, v) => MapEntry(k, _asInt(v))),
    );
  }

  final int updatedCount;
  final Map<String, int> newChapters;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'updated_count': updatedCount,
      'new_chapters': newChapters,
    };
  }
}

/// model.UpdateComicRequest
class UpdateComicRequest {
  const UpdateComicRequest({
    this.isPublic,
    this.readed,
  });

  factory UpdateComicRequest.fromJson(Map<String, dynamic> json) {
    return UpdateComicRequest(
      isPublic: json['is_public'] == null ? null : _asBool(json['is_public']),
      readed: json['readed'] == null ? null : _asBool(json['readed']),
    );
  }

  final bool? isPublic;
  final bool? readed;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'is_public': isPublic,
      'readed': readed,
    };
  }
}

/// proctask.Task
class ProcTask {
  const ProcTask({
    required this.id,
    required this.name,
    required this.command,
    required this.status,
    required this.pid,
    required this.startedAt,
    this.finishedAt,
    this.exitCode,
    this.result,
    this.error,
    required this.logs,
  });

  factory ProcTask.fromJson(Map<String, dynamic> json) {
    return ProcTask(
      id: _asString(json['id']),
      name: _asString(json['name']),
      command: _asString(json['command']),
      status: _asString(json['status']),
      pid: _asInt(json['pid']),
      startedAt: _asString(json['started_at']),
      finishedAt: json['finished_at'] == null ? null : _asString(json['finished_at']),
      exitCode: json['exit_code'] == null ? null : _asInt(json['exit_code']),
      result: json['result'],
      error: json['error'] == null ? null : _asString(json['error']),
      logs: (json['logs'] as List<dynamic>? ?? const <dynamic>[]).map((e) => ProcTaskLog.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
    );
  }

  final String id;
  final String name;
  final String command;
  final String status;
  final int pid;
  final String startedAt;
  final String? finishedAt;
  final int? exitCode;
  final Object? result;
  final String? error;
  final List<ProcTaskLog> logs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'command': command,
      'status': status,
      'pid': pid,
      'started_at': startedAt,
      'finished_at': finishedAt,
      'exit_code': exitCode,
      'result': result,
      'error': error,
      'logs': logs.map((e) => e.toJson()).toList(),
    };
  }
}

/// proctask.LogEntry
class ProcTaskLog {
  const ProcTaskLog({
    required this.time,
    required this.stream,
    required this.text,
  });

  factory ProcTaskLog.fromJson(Map<String, dynamic> json) {
    return ProcTaskLog(
      time: _asString(json['time']),
      stream: _asString(json['stream']),
      text: _asString(json['text']),
    );
  }

  final String time;
  final String stream;
  final String text;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'time': time,
      'stream': stream,
      'text': text,
    };
  }
}

/// comix.Result
class ComixResult {
  const ComixResult({
    required this.ok,
    this.data,
    this.error,
    this.candidates,
    required this.exitCode,
    this.stderr,
  });

  factory ComixResult.fromJson(Map<String, dynamic> json) {
    return ComixResult(
      ok: _asBool(json['ok']),
      data: json['data'] == null ? null : (json['data'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v)),
      error: json['error'] == null ? null : _asString(json['error']),
      candidates: json['candidates'] == null ? null : (json['candidates'] as List<dynamic>).map((e) => e).toList(),
      exitCode: _asInt(json['exit_code']),
      stderr: json['stderr'] == null ? null : _asString(json['stderr']),
    );
  }

  final bool ok;
  final Map<String, Object?>? data;
  final String? error;
  final List<Object?>? candidates;
  final int exitCode;
  final String? stderr;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ok': ok,
      'data': data,
      'error': error,
      'candidates': candidates,
      'exit_code': exitCode,
      'stderr': stderr,
    };
  }
}

/// ai.Status
class AiStatus {
  const AiStatus({
    required this.enabled,
    required this.schemaReady,
    required this.started,
    required this.embedModel,
    required this.device,
    required this.batchSize,
    required this.idleTimeoutS,
    required this.jobTimeoutS,
    required this.maxAttempts,
    required this.paused,
    required this.autoCapabilities,
    required this.capabilities,
    required this.queue,
    required this.pendingTotal,
    required this.failedTotal,
    this.lastRun,
    required this.index,
    required this.cluster,
    required this.ollama,
    required this.personCount,
  });

  factory AiStatus.fromJson(Map<String, dynamic> json) {
    return AiStatus(
      enabled: _asBool(json['enabled']),
      schemaReady: _asBool(json['schema_ready']),
      started: _asBool(json['started']),
      embedModel: _asString(json['embed_model']),
      device: _asString(json['device']),
      batchSize: _asInt(json['batch_size']),
      idleTimeoutS: _asInt(json['idle_timeout_seconds']),
      jobTimeoutS: _asInt(json['job_timeout_seconds']),
      maxAttempts: _asInt(json['max_attempts']),
      paused: _asBool(json['paused']),
      autoCapabilities: (json['auto_capabilities'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      capabilities: (json['capabilities'] as List<dynamic>? ?? const <dynamic>[]).map((e) => CapabilityStatus.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      queue: (json['queue'] as List<dynamic>? ?? const <dynamic>[]).map((e) => AiCapabilityStat.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      pendingTotal: _asInt(json['pending_total']),
      failedTotal: _asInt(json['failed_total']),
      lastRun: json['last_run'] == null ? null : RunInfo.fromJson(json['last_run'] as Map<String, dynamic>),
      index: IndexState.fromJson((json['index'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      cluster: ClusterState.fromJson((json['cluster'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      ollama: OllamaState.fromJson((json['ollama'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      personCount: _asInt(json['person_count']),
    );
  }

  final bool enabled;
  final bool schemaReady;
  final bool started;
  final String embedModel;
  final String device;
  final int batchSize;
  final int idleTimeoutS;
  final int jobTimeoutS;
  final int maxAttempts;
  final bool paused;
  final List<String> autoCapabilities;
  final List<CapabilityStatus> capabilities;
  final List<AiCapabilityStat> queue;
  final int pendingTotal;
  final int failedTotal;
  final RunInfo? lastRun;
  final IndexState index;
  final ClusterState cluster;
  final OllamaState ollama;
  final int personCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'schema_ready': schemaReady,
      'started': started,
      'embed_model': embedModel,
      'device': device,
      'batch_size': batchSize,
      'idle_timeout_seconds': idleTimeoutS,
      'job_timeout_seconds': jobTimeoutS,
      'max_attempts': maxAttempts,
      'paused': paused,
      'auto_capabilities': autoCapabilities,
      'capabilities': capabilities.map((e) => e.toJson()).toList(),
      'queue': queue.map((e) => e.toJson()).toList(),
      'pending_total': pendingTotal,
      'failed_total': failedTotal,
      'last_run': lastRun?.toJson(),
      'index': index.toJson(),
      'cluster': cluster.toJson(),
      'ollama': ollama.toJson(),
      'person_count': personCount,
    };
  }
}

/// model.AiJob
class AiJob {
  const AiJob({
    required this.id,
    required this.capability,
    required this.mediaId,
    required this.status,
    required this.priority,
    required this.attempts,
    this.lastError,
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiJob.fromJson(Map<String, dynamic> json) {
    return AiJob(
      id: _asInt(json['id']),
      capability: _asString(json['capability']),
      mediaId: _asString(json['media_id']),
      status: _asString(json['status']),
      priority: _asInt(json['priority']),
      attempts: _asInt(json['attempts']),
      lastError: json['last_error'] == null ? null : _asString(json['last_error']),
      startedAt: json['started_at'] == null ? null : _asString(json['started_at']),
      finishedAt: json['finished_at'] == null ? null : _asString(json['finished_at']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  final int id;
  final String capability;
  final String mediaId;
  final String status;
  final int priority;
  final int attempts;
  final String? lastError;
  final String? startedAt;
  final String? finishedAt;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'capability': capability,
      'media_id': mediaId,
      'status': status,
      'priority': priority,
      'attempts': attempts,
      'last_error': lastError,
      'started_at': startedAt,
      'finished_at': finishedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

/// model.AiCapabilityInfo
class AiCapabilityInfo {
  const AiCapabilityInfo({
    required this.capability,
    required this.label,
    required this.inputTier,
    required this.selected,
    required this.ready,
    this.reason,
    required this.candidates,
    this.settingKey,
  });

  factory AiCapabilityInfo.fromJson(Map<String, dynamic> json) {
    return AiCapabilityInfo(
      capability: _asString(json['capability']),
      label: _asString(json['label']),
      inputTier: _asString(json['input_tier']),
      selected: _asString(json['selected']),
      ready: _asBool(json['ready']),
      reason: json['reason'] == null ? null : _asString(json['reason']),
      candidates: (json['candidates'] as List<dynamic>? ?? const <dynamic>[]).map((e) => AiImplementation.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      settingKey: json['setting_key'] == null ? null : _asString(json['setting_key']),
    );
  }

  final String capability;
  final String label;
  final String inputTier;
  final String selected;
  final bool ready;
  final String? reason;
  final List<AiImplementation> candidates;
  final String? settingKey;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'capability': capability,
      'label': label,
      'input_tier': inputTier,
      'selected': selected,
      'ready': ready,
      'reason': reason,
      'candidates': candidates.map((e) => e.toJson()).toList(),
      'setting_key': settingKey,
    };
  }
}

/// model.AiImplementation
class AiImplementation {
  const AiImplementation({
    required this.id,
    required this.label,
    this.note,
  });

  factory AiImplementation.fromJson(Map<String, dynamic> json) {
    return AiImplementation(
      id: _asString(json['id']),
      label: _asString(json['label']),
      note: json['note'] == null ? null : _asString(json['note']),
    );
  }

  final String id;
  final String label;
  final String? note;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'note': note,
    };
  }
}

/// model.AiResultSpec
class AiResultSpec {
  const AiResultSpec({
    required this.mediaId,
    required this.capability,
    required this.inputTier,
    required this.executor,
    required this.updatedAt,
  });

  factory AiResultSpec.fromJson(Map<String, dynamic> json) {
    return AiResultSpec(
      mediaId: _asString(json['media_id']),
      capability: _asString(json['capability']),
      inputTier: _asString(json['input_tier']),
      executor: _asString(json['executor']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  final String mediaId;
  final String capability;
  final String inputTier;
  final String executor;
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'media_id': mediaId,
      'capability': capability,
      'input_tier': inputTier,
      'executor': executor,
      'updated_at': updatedAt,
    };
  }
}

/// model.AiPerson
class AiPerson {
  const AiPerson({
    required this.id,
    this.name,
    this.coverFaceId,
    this.coverMedia,
    required this.faceCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiPerson.fromJson(Map<String, dynamic> json) {
    return AiPerson(
      id: _asString(json['id']),
      name: json['name'] == null ? null : _asString(json['name']),
      coverFaceId: json['cover_face_id'] == null ? null : _asString(json['cover_face_id']),
      coverMedia: json['cover_media_id'] == null ? null : _asString(json['cover_media_id']),
      faceCount: _asInt(json['face_count']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  final String id;
  final String? name;
  final String? coverFaceId;
  final String? coverMedia;
  final int faceCount;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'cover_face_id': coverFaceId,
      'cover_media_id': coverMedia,
      'face_count': faceCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

/// model.AiFace
class AiFace {
  const AiFace({
    required this.id,
    required this.mediaId,
    this.personId,
    required this.box,
    required this.detScore,
    required this.quality,
    required this.createdAt,
  });

  factory AiFace.fromJson(Map<String, dynamic> json) {
    return AiFace(
      id: _asString(json['id']),
      mediaId: _asString(json['media_id']),
      personId: json['person_id'] == null ? null : _asString(json['person_id']),
      box: (json['bbox'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asDouble(e)).toList(),
      detScore: _asDouble(json['det_score']),
      quality: _asDouble(json['quality']),
      createdAt: _asString(json['created_at']),
    );
  }

  final String id;
  final String mediaId;
  final String? personId;
  final List<double> box;
  final double detScore;
  final double quality;
  final String createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'media_id': mediaId,
      'person_id': personId,
      'bbox': box,
      'det_score': detScore,
      'quality': quality,
      'created_at': createdAt,
    };
  }
}

/// model.AiMediaDetail
class AiMediaDetail {
  const AiMediaDetail({
    required this.mediaId,
    this.phash,
    this.ocrText,
    this.caption,
    required this.vlmTags,
    required this.hasVector,
    required this.faces,
  });

  factory AiMediaDetail.fromJson(Map<String, dynamic> json) {
    return AiMediaDetail(
      mediaId: _asString(json['media_id']),
      phash: json['phash'] == null ? null : _asInt(json['phash']),
      ocrText: json['ocr_text'] == null ? null : _asString(json['ocr_text']),
      caption: json['caption'] == null ? null : _asString(json['caption']),
      vlmTags: (json['vlm_tags'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      hasVector: _asBool(json['has_vector']),
      faces: (json['faces'] as List<dynamic>? ?? const <dynamic>[]).map((e) => AiFace.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
    );
  }

  final String mediaId;
  final int? phash;
  final String? ocrText;
  final String? caption;
  final List<String> vlmTags;
  final bool hasVector;
  final List<AiFace> faces;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'media_id': mediaId,
      'phash': phash,
      'ocr_text': ocrText,
      'caption': caption,
      'vlm_tags': vlmTags,
      'has_vector': hasVector,
      'faces': faces.map((e) => e.toJson()).toList(),
    };
  }
}

/// model.AiSearchHit
class AiSearchHit {
  const AiSearchHit({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.capturedAt,
    required this.filePath,
    this.thumbPath,
    this.previewPath,
    required this.hash,
    required this.sizeBytes,
    this.mimeType,
    required this.isDeleted,
    required this.syncCount,
    this.groupId,
    required this.message,
    this.editParams,
    required this.score,
    required this.source,
  });

  factory AiSearchHit.fromJson(Map<String, dynamic> json) {
    return AiSearchHit(
      id: _asString(json['id']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
      capturedAt: _asString(json['captured_at']),
      filePath: _asString(json['file_path']),
      thumbPath: json['thumb_path'] == null ? null : _asString(json['thumb_path']),
      previewPath: json['preview_path'] == null ? null : _asString(json['preview_path']),
      hash: _asString(json['hash']),
      sizeBytes: _asInt(json['size_bytes']),
      mimeType: json['mime_type'] == null ? null : _asString(json['mime_type']),
      isDeleted: _asBool(json['is_deleted']),
      syncCount: _asInt(json['sync_count']),
      groupId: json['group_id'] == null ? null : _asString(json['group_id']),
      message: _asString(json['message']),
      editParams: json['edit_params'] == null ? null : _asString(json['edit_params']),
      score: _asDouble(json['score']),
      source: (json['source'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
    );
  }

  final String id;
  final String createdAt;
  final String updatedAt;
  final String capturedAt;
  final String filePath;
  final String? thumbPath;
  final String? previewPath;
  final String hash;
  final int sizeBytes;
  final String? mimeType;
  final bool isDeleted;
  final int syncCount;
  final String? groupId;
  final String message;
  final String? editParams;
  final double score;
  final List<String> source;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'captured_at': capturedAt,
      'file_path': filePath,
      'thumb_path': thumbPath,
      'preview_path': previewPath,
      'hash': hash,
      'size_bytes': sizeBytes,
      'mime_type': mimeType,
      'is_deleted': isDeleted,
      'sync_count': syncCount,
      'group_id': groupId,
      'message': message,
      'edit_params': editParams,
      'score': score,
      'source': source,
    };
  }
}

/// model.AiSearchResponse
class AiSearchResponse {
  const AiSearchResponse({
    required this.hits,
    required this.total,
    required this.mode,
  });

  factory AiSearchResponse.fromJson(Map<String, dynamic> json) {
    return AiSearchResponse(
      hits: (json['hits'] as List<dynamic>? ?? const <dynamic>[]).map((e) => AiSearchHit.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      total: _asInt(json['total']),
      mode: _asString(json['mode']),
    );
  }

  final List<AiSearchHit> hits;
  final int total;
  final String mode;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hits': hits.map((e) => e.toJson()).toList(),
      'total': total,
      'mode': mode,
    };
  }
}

/// model.DuplicateGroup
class DuplicateGroup {
  const DuplicateGroup({
    required this.distance,
    required this.mediaIds,
    required this.files,
  });

  factory DuplicateGroup.fromJson(Map<String, dynamic> json) {
    return DuplicateGroup(
      distance: _asInt(json['distance']),
      mediaIds: (json['media_ids'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      files: (json['files'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
    );
  }

  final int distance;
  final List<String> mediaIds;
  final List<String> files;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'distance': distance,
      'media_ids': mediaIds,
      'files': files,
    };
  }
}

/// ai_repo.ReviewPreset
class ReviewPreset {
  const ReviewPreset({
    required this.id,
    required this.name,
    required this.tone,
    required this.role,
    required this.isDefault,
  });

  factory ReviewPreset.fromJson(Map<String, dynamic> json) {
    return ReviewPreset(
      id: _asString(json['id']),
      name: _asString(json['name']),
      tone: _asString(json['tone']),
      role: _asString(json['role']),
      isDefault: _asBool(json['is_default']),
    );
  }

  final String id;
  final String name;
  final String tone;
  final String role;
  final bool isDefault;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'tone': tone,
      'role': role,
      'is_default': isDefault,
    };
  }
}

/// review.Result
class ReviewResult {
  const ReviewResult({
    required this.stats,
    required this.narrative,
    this.model,
    required this.presetId,
    this.preset,
    required this.cached,
    this.createdAt,
    this.notice,
  });

  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    return ReviewResult(
      stats: Stats.fromJson((json['stats'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      narrative: _asString(json['narrative']),
      model: json['model'] == null ? null : _asString(json['model']),
      presetId: _asString(json['preset_id']),
      preset: json['preset_name'] == null ? null : _asString(json['preset_name']),
      cached: _asBool(json['cached']),
      createdAt: json['created_at'] == null ? null : _asString(json['created_at']),
      notice: json['notice'] == null ? null : _asString(json['notice']),
    );
  }

  final Stats stats;
  final String narrative;
  final String? model;
  final String presetId;
  final String? preset;
  final bool cached;
  final String? createdAt;
  final String? notice;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stats': stats.toJson(),
      'narrative': narrative,
      'model': model,
      'preset_id': presetId,
      'preset_name': preset,
      'cached': cached,
      'created_at': createdAt,
      'notice': notice,
    };
  }
}

/// model.EssayArticle
class EssayArticle {
  const EssayArticle({
    required this.id,
    required this.date,
    required this.wordCount,
    required this.content,
    required this.imgs,
    required this.labels,
    this.messages,
    this.mood,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EssayArticle.fromJson(Map<String, dynamic> json) {
    return EssayArticle(
      id: _asString(json['id']),
      date: _asString(json['date']),
      wordCount: _asInt(json['word_count']),
      content: _asString(json['content']),
      imgs: (json['imgs'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      labels: (json['labels'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      messages: json['messages'],
      mood: json['mood'] == null ? null : _asString(json['mood']),
      deletedAt: json['deleted_at'] == null ? null : _asString(json['deleted_at']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  final String id;
  final String date;
  final int wordCount;
  final String content;
  final List<String> imgs;
  final List<String> labels;
  final Object? messages;
  final String? mood;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'date': date,
      'word_count': wordCount,
      'content': content,
      'imgs': imgs,
      'labels': labels,
      'messages': messages,
      'mood': mood,
      'deleted_at': deletedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

/// model.EssayLabel
class EssayLabel {
  const EssayLabel({
    required this.id,
    required this.name,
    required this.essayCount,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EssayLabel.fromJson(Map<String, dynamic> json) {
    return EssayLabel(
      id: _asString(json['id']),
      name: _asString(json['name']),
      essayCount: _asInt(json['essay_count']),
      deletedAt: json['deleted_at'] == null ? null : _asString(json['deleted_at']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  final String id;
  final String name;
  final int essayCount;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'essay_count': essayCount,
      'deleted_at': deletedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

/// model.EssayYearSummary
class EssayYearSummary {
  const EssayYearSummary({
    required this.year,
    required this.essayCount,
    required this.wordCount,
    this.monthSummaries,
    this.deletedAt,
    required this.updatedAt,
  });

  factory EssayYearSummary.fromJson(Map<String, dynamic> json) {
    return EssayYearSummary(
      year: _asString(json['year']),
      essayCount: _asInt(json['essay_count']),
      wordCount: _asInt(json['word_count']),
      monthSummaries: json['month_summaries'],
      deletedAt: json['deleted_at'] == null ? null : _asString(json['deleted_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  final String year;
  final int essayCount;
  final int wordCount;
  final Object? monthSummaries;
  final String? deletedAt;
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'year': year,
      'essay_count': essayCount,
      'word_count': wordCount,
      'month_summaries': monthSummaries,
      'deleted_at': deletedAt,
      'updated_at': updatedAt,
    };
  }
}

/// model.BookletStyle
class BookletStyle {
  const BookletStyle({
    required this.id,
    required this.startDate,
    required this.validCheckIn,
    required this.fullyDone,
    required this.longestStreak,
    required this.longestFullyStreak,
    this.tasks,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookletStyle.fromJson(Map<String, dynamic> json) {
    return BookletStyle(
      id: _asString(json['id']),
      startDate: _asString(json['start_date']),
      validCheckIn: _asInt(json['valid_check_in']),
      fullyDone: _asInt(json['fully_done']),
      longestStreak: _asInt(json['longest_streak']),
      longestFullyStreak: _asInt(json['longest_fully_streak']),
      tasks: json['tasks'],
      deletedAt: json['deleted_at'] == null ? null : _asString(json['deleted_at']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  final String id;
  final String startDate;
  final int validCheckIn;
  final int fullyDone;
  final int longestStreak;
  final int longestFullyStreak;
  final Object? tasks;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'start_date': startDate,
      'valid_check_in': validCheckIn,
      'fully_done': fullyDone,
      'longest_streak': longestStreak,
      'longest_fully_streak': longestFullyStreak,
      'tasks': tasks,
      'deleted_at': deletedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

/// model.BookletRecord
class BookletRecord {
  const BookletRecord({
    required this.id,
    required this.styleId,
    required this.date,
    required this.message,
    this.taskCompletion,
    this.mood,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookletRecord.fromJson(Map<String, dynamic> json) {
    return BookletRecord(
      id: _asString(json['id']),
      styleId: _asString(json['style_id']),
      date: _asString(json['date']),
      message: _asString(json['message']),
      taskCompletion: json['task_completion'],
      mood: json['mood'] == null ? null : _asString(json['mood']),
      deletedAt: json['deleted_at'] == null ? null : _asString(json['deleted_at']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }

  final String id;
  final String styleId;
  final String date;
  final String message;
  final Object? taskCompletion;
  final String? mood;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'style_id': styleId,
      'date': date,
      'message': message,
      'task_completion': taskCompletion,
      'mood': mood,
      'deleted_at': deletedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

/// data_handler.CheckImagesRequest
class CheckImagesRequest {
  const CheckImagesRequest({
    required this.filenames,
  });

  factory CheckImagesRequest.fromJson(Map<String, dynamic> json) {
    return CheckImagesRequest(
      filenames: (json['filenames'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
    );
  }

  final List<String> filenames;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'filenames': filenames,
    };
  }
}

/// data_handler.CheckImagesResponse
class CheckImagesResponse {
  const CheckImagesResponse({
    required this.existing,
    required this.missing,
  });

  factory CheckImagesResponse.fromJson(Map<String, dynamic> json) {
    return CheckImagesResponse(
      existing: (json['existing'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      missing: (json['missing'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
    );
  }

  final List<String> existing;
  final List<String> missing;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'existing': existing,
      'missing': missing,
    };
  }
}

/// ops.GalleryOptions
class GalleryOptions {
  const GalleryOptions({
    required this.mode,
    required this.concurrency,
    required this.batch,
    required this.resize,
    required this.resizePrew,
    required this.resizeThumb,
  });

  factory GalleryOptions.fromJson(Map<String, dynamic> json) {
    return GalleryOptions(
      mode: _asString(json['mode']),
      concurrency: _asInt(json['concurrency']),
      batch: _asInt(json['batch']),
      resize: _asInt(json['resize']),
      resizePrew: _asInt(json['resize_preview']),
      resizeThumb: _asInt(json['resize_thumb']),
    );
  }

  final String mode;
  final int concurrency;
  final int batch;
  final int resize;
  final int resizePrew;
  final int resizeThumb;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': mode,
      'concurrency': concurrency,
      'batch': batch,
      'resize': resize,
      'resize_preview': resizePrew,
      'resize_thumb': resizeThumb,
    };
  }
}

/// ops.Preferences
class OpsPreferences {
  const OpsPreferences({
    required this.autoRefreshSeconds,
    this.collapsedSections,
    this.lastTab,
    required this.logAutoscroll,
  });

  factory OpsPreferences.fromJson(Map<String, dynamic> json) {
    return OpsPreferences(
      autoRefreshSeconds: _asInt(json['auto_refresh_seconds']),
      collapsedSections: json['collapsed_sections'] == null ? null : (json['collapsed_sections'] as List<dynamic>).map((e) => _asString(e)).toList(),
      lastTab: json['last_tab'] == null ? null : _asString(json['last_tab']),
      logAutoscroll: _asBool(json['log_autoscroll']),
    );
  }

  final int autoRefreshSeconds;
  final List<String>? collapsedSections;
  final String? lastTab;
  final bool logAutoscroll;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'auto_refresh_seconds': autoRefreshSeconds,
      'collapsed_sections': collapsedSections,
      'last_tab': lastTab,
      'log_autoscroll': logAutoscroll,
    };
  }
}

/// ops.DirEntry
class DirEntry {
  const DirEntry({
    required this.name,
    required this.path,
  });

  factory DirEntry.fromJson(Map<String, dynamic> json) {
    return DirEntry(
      name: _asString(json['name']),
      path: _asString(json['path']),
    );
  }

  final String name;
  final String path;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'path': path,
    };
  }
}

/// ops.Dependency
class Dependency {
  const Dependency({
    required this.name,
    required this.available,
    this.path,
    this.required_,
  });

  factory Dependency.fromJson(Map<String, dynamic> json) {
    return Dependency(
      name: _asString(json['name']),
      available: _asBool(json['available']),
      path: json['path'] == null ? null : _asString(json['path']),
      required_: json['required_for'] == null ? null : _asString(json['required_for']),
    );
  }

  final String name;
  final bool available;
  final String? path;
  final String? required_;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'available': available,
      'path': path,
      'required_for': required_,
    };
  }
}

/// settings.Spec
class SettingSpec {
  const SettingSpec({
    required this.key,
    required this.section,
    required this.label,
    this.help,
    required this.kind,
    required this.default_,
    this.options,
    this.min,
    this.max,
    this.restart,
  });

  factory SettingSpec.fromJson(Map<String, dynamic> json) {
    return SettingSpec(
      key: _asString(json['key']),
      section: _asString(json['section']),
      label: _asString(json['label']),
      help: json['help'] == null ? null : _asString(json['help']),
      kind: _asString(json['kind']),
      default_: _asString(json['default']),
      options: json['options'] == null ? null : (json['options'] as List<dynamic>).map((e) => SettingOption.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      min: json['min'] == null ? null : _asInt(json['min']),
      max: json['max'] == null ? null : _asInt(json['max']),
      restart: json['restart'] == null ? null : _asBool(json['restart']),
    );
  }

  final String key;
  final String section;
  final String label;
  final String? help;
  final String kind;
  final String default_;
  final List<SettingOption>? options;
  final int? min;
  final int? max;
  final bool? restart;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'section': section,
      'label': label,
      'help': help,
      'kind': kind,
      'default': default_,
      'options': options?.map((e) => e.toJson()).toList(),
      'min': min,
      'max': max,
      'restart': restart,
    };
  }
}

/// settings.Option
class SettingOption {
  const SettingOption({
    required this.value,
    required this.label,
  });

  factory SettingOption.fromJson(Map<String, dynamic> json) {
    return SettingOption(
      value: _asString(json['value']),
      label: _asString(json['label']),
    );
  }

  final String value;
  final String label;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'value': value,
      'label': label,
    };
  }
}

/// model.SyncStatsData
class SyncStatsData {
  const SyncStatsData({
    required this.minSyncCount,
    required this.maxSyncCount,
    required this.avgSyncCount,
  });

  factory SyncStatsData.fromJson(Map<String, dynamic> json) {
    return SyncStatsData(
      minSyncCount: _asInt(json['min_sync_count']),
      maxSyncCount: _asInt(json['max_sync_count']),
      avgSyncCount: _asDouble(json['avg_sync_count']),
    );
  }

  final int minSyncCount;
  final int maxSyncCount;
  final double avgSyncCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'min_sync_count': minSyncCount,
      'max_sync_count': maxSyncCount,
      'avg_sync_count': avgSyncCount,
    };
  }
}

/// model.YearStatItem
class YearStatItem {
  const YearStatItem({
    required this.year,
    required this.mediaCount,
  });

  factory YearStatItem.fromJson(Map<String, dynamic> json) {
    return YearStatItem(
      year: _asInt(json['year']),
      mediaCount: _asInt(json['media_count']),
    );
  }

  final int year;
  final int mediaCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'year': year,
      'media_count': mediaCount,
    };
  }
}

/// ai.CapabilityStatus
class CapabilityStatus {
  const CapabilityStatus({
    required this.capability,
    required this.ready,
    this.reason,
    this.sidecar,
    required this.missingMedia,
    required this.pending,
    required this.failed,
    required this.done,
  });

  factory CapabilityStatus.fromJson(Map<String, dynamic> json) {
    return CapabilityStatus(
      capability: _asString(json['capability']),
      ready: _asBool(json['ready']),
      reason: json['reason'] == null ? null : _asString(json['reason']),
      sidecar: json['sidecar'] == null ? null : SidecarState.fromJson(json['sidecar'] as Map<String, dynamic>),
      missingMedia: _asInt(json['missing_media']),
      pending: _asInt(json['pending']),
      failed: _asInt(json['failed']),
      done: _asInt(json['done']),
    );
  }

  final String capability;
  final bool ready;
  final String? reason;
  final SidecarState? sidecar;
  final int missingMedia;
  final int pending;
  final int failed;
  final int done;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'capability': capability,
      'ready': ready,
      'reason': reason,
      'sidecar': sidecar?.toJson(),
      'missing_media': missingMedia,
      'pending': pending,
      'failed': failed,
      'done': done,
    };
  }
}

/// model.AiCapabilityStat
class AiCapabilityStat {
  const AiCapabilityStat({
    required this.capability,
    required this.pending,
    required this.running,
    required this.done,
    required this.failed,
    required this.total,
  });

  factory AiCapabilityStat.fromJson(Map<String, dynamic> json) {
    return AiCapabilityStat(
      capability: _asString(json['capability']),
      pending: _asInt(json['pending']),
      running: _asInt(json['running']),
      done: _asInt(json['done']),
      failed: _asInt(json['failed']),
      total: _asInt(json['total']),
    );
  }

  final String capability;
  final int pending;
  final int running;
  final int done;
  final int failed;
  final int total;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'capability': capability,
      'pending': pending,
      'running': running,
      'done': done,
      'failed': failed,
      'total': total,
    };
  }
}

/// ai.RunInfo
class RunInfo {
  const RunInfo({
    required this.capability,
    required this.total,
    required this.processed,
    required this.failed,
    required this.startedAt,
    required this.running,
  });

  factory RunInfo.fromJson(Map<String, dynamic> json) {
    return RunInfo(
      capability: _asString(json['capability']),
      total: _asInt(json['total']),
      processed: _asInt(json['processed']),
      failed: _asInt(json['failed']),
      startedAt: _asString(json['started_at']),
      running: _asBool(json['running']),
    );
  }

  final String capability;
  final int total;
  final int processed;
  final int failed;
  final String startedAt;
  final bool running;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'capability': capability,
      'total': total,
      'processed': processed,
      'failed': failed,
      'started_at': startedAt,
      'running': running,
    };
  }
}

/// ai.IndexState
class IndexState {
  const IndexState({
    required this.model,
    required this.vectors,
    required this.loaded,
    required this.memoryBytes,
  });

  factory IndexState.fromJson(Map<String, dynamic> json) {
    return IndexState(
      model: _asString(json['model']),
      vectors: _asInt(json['vectors']),
      loaded: _asBool(json['loaded']),
      memoryBytes: _asInt(json['memory_estimate_bytes']),
    );
  }

  final String model;
  final int vectors;
  final bool loaded;
  final int memoryBytes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'model': model,
      'vectors': vectors,
      'loaded': loaded,
      'memory_estimate_bytes': memoryBytes,
    };
  }
}

/// ai.ClusterState
class ClusterState {
  const ClusterState({
    required this.persons,
    required this.threshold,
    required this.minGroup,
    required this.centroidsOk,
  });

  factory ClusterState.fromJson(Map<String, dynamic> json) {
    return ClusterState(
      persons: _asInt(json['persons']),
      threshold: _asDouble(json['threshold']),
      minGroup: _asInt(json['min_group_faces']),
      centroidsOk: _asBool(json['centroids_loaded']),
    );
  }

  final int persons;
  final double threshold;
  final int minGroup;
  final bool centroidsOk;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'persons': persons,
      'threshold': threshold,
      'min_group_faces': minGroup,
      'centroids_loaded': centroidsOk,
    };
  }
}

/// ai.OllamaState
class OllamaState {
  const OllamaState({
    required this.url,
    required this.model,
    required this.modelDefault,
    required this.modelAlt,
    required this.activeModel,
    this.lastSwitch,
    required this.numCtx,
    required this.reachable,
    required this.modelReady,
    this.error,
    required this.ownedServer,
    required this.pid,
    required this.idleSeconds,
    this.models,
    required this.keepAlive,
    required this.keepAliveDefaultSeconds,
    required this.thinking,
  });

  factory OllamaState.fromJson(Map<String, dynamic> json) {
    return OllamaState(
      url: _asString(json['url']),
      model: _asString(json['model']),
      modelDefault: _asString(json['model_default']),
      modelAlt: _asString(json['model_alt']),
      activeModel: _asString(json['active_model']),
      lastSwitch: json['last_switch'] == null ? null : _asString(json['last_switch']),
      numCtx: _asInt(json['num_ctx']),
      reachable: _asBool(json['reachable']),
      modelReady: _asBool(json['model_ready']),
      error: json['error'] == null ? null : _asString(json['error']),
      ownedServer: _asBool(json['owned_server']),
      pid: _asInt(json['pid']),
      idleSeconds: _asInt(json['idle_seconds']),
      models: json['models'] == null ? null : (json['models'] as List<dynamic>).map((e) => _asString(e)).toList(),
      keepAlive: _asString(json['keep_alive']),
      keepAliveDefaultSeconds: _asInt(json['keep_alive_default_seconds']),
      thinking: _asBool(json['thinking']),
    );
  }

  final String url;
  final String model;
  final String modelDefault;
  final String modelAlt;
  final String activeModel;
  final String? lastSwitch;
  final int numCtx;
  final bool reachable;
  final bool modelReady;
  final String? error;
  final bool ownedServer;
  final int pid;
  final int idleSeconds;
  final List<String>? models;
  final String keepAlive;
  final int keepAliveDefaultSeconds;
  final bool thinking;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'model': model,
      'model_default': modelDefault,
      'model_alt': modelAlt,
      'active_model': activeModel,
      'last_switch': lastSwitch,
      'num_ctx': numCtx,
      'reachable': reachable,
      'model_ready': modelReady,
      'error': error,
      'owned_server': ownedServer,
      'pid': pid,
      'idle_seconds': idleSeconds,
      'models': models,
      'keep_alive': keepAlive,
      'keep_alive_default_seconds': keepAliveDefaultSeconds,
      'thinking': thinking,
    };
  }
}

/// review.Stats
class Stats {
  const Stats({
    required this.from,
    required this.to,
    required this.days,
    required this.facts,
    required this.booklet,
    required this.essay,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      from: _asString(json['from']),
      to: _asString(json['to']),
      days: _asInt(json['days']),
      facts: (json['facts'] as List<dynamic>? ?? const <dynamic>[]).map((e) => _asString(e)).toList(),
      booklet: BookletStats.fromJson((json['booklet'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      essay: EssayStats.fromJson((json['essay'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
    );
  }

  final String from;
  final String to;
  final int days;
  final List<String> facts;
  final BookletStats booklet;
  final EssayStats essay;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'from': from,
      'to': to,
      'days': days,
      'facts': facts,
      'booklet': booklet.toJson(),
      'essay': essay.toJson(),
    };
  }
}

/// ai.SidecarState
class SidecarState {
  const SidecarState({
    required this.capability,
    required this.running,
    required this.pid,
    this.startedAt,
    this.lastUsedAt,
    required this.idleSeconds,
    required this.idleTimeoutS,
    required this.python,
    required this.probeOk,
    this.probeError,
    this.missingModels,
  });

  factory SidecarState.fromJson(Map<String, dynamic> json) {
    return SidecarState(
      capability: _asString(json['capability']),
      running: _asBool(json['running']),
      pid: _asInt(json['pid']),
      startedAt: json['started_at'] == null ? null : _asString(json['started_at']),
      lastUsedAt: json['last_used_at'] == null ? null : _asString(json['last_used_at']),
      idleSeconds: _asInt(json['idle_seconds']),
      idleTimeoutS: _asInt(json['idle_timeout_seconds']),
      python: _asString(json['python']),
      probeOk: _asBool(json['probe_ok']),
      probeError: json['probe_error'] == null ? null : _asString(json['probe_error']),
      missingModels: json['missing_models'] == null ? null : (json['missing_models'] as List<dynamic>).map((e) => _asString(e)).toList(),
    );
  }

  final String capability;
  final bool running;
  final int pid;
  final String? startedAt;
  final String? lastUsedAt;
  final int idleSeconds;
  final int idleTimeoutS;
  final String python;
  final bool probeOk;
  final String? probeError;
  final List<String>? missingModels;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'capability': capability,
      'running': running,
      'pid': pid,
      'started_at': startedAt,
      'last_used_at': lastUsedAt,
      'idle_seconds': idleSeconds,
      'idle_timeout_seconds': idleTimeoutS,
      'python': python,
      'probe_ok': probeOk,
      'probe_error': probeError,
      'missing_models': missingModels,
    };
  }
}

/// review.BookletStats
class BookletStats {
  const BookletStats({
    required this.activeStyles,
    required this.totalRecords,
    required this.checkInDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.completionRate,
    required this.moodCounts,
    required this.topTasks,
  });

  factory BookletStats.fromJson(Map<String, dynamic> json) {
    return BookletStats(
      activeStyles: _asInt(json['active_styles']),
      totalRecords: _asInt(json['total_records']),
      checkInDays: _asInt(json['check_in_days']),
      currentStreak: _asInt(json['current_streak']),
      longestStreak: _asInt(json['longest_streak']),
      completionRate: _asDouble(json['completion_rate']),
      moodCounts: (json['mood_counts'] as Map<String, dynamic>? ?? const <String, dynamic>{}).map((k, v) => MapEntry(k, _asInt(v))),
      topTasks: (json['top_tasks'] as List<dynamic>? ?? const <dynamic>[]).map((e) => TaskStat.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
    );
  }

  final int activeStyles;
  final int totalRecords;
  final int checkInDays;
  final int currentStreak;
  final int longestStreak;
  final double completionRate;
  final Map<String, int> moodCounts;
  final List<TaskStat> topTasks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'active_styles': activeStyles,
      'total_records': totalRecords,
      'check_in_days': checkInDays,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'completion_rate': completionRate,
      'mood_counts': moodCounts,
      'top_tasks': topTasks.map((e) => e.toJson()).toList(),
    };
  }
}

/// review.EssayStats
class EssayStats {
  const EssayStats({
    required this.articles,
    required this.words,
    required this.activeDays,
    required this.avgWords,
    required this.topLabels,
    required this.moodCounts,
  });

  factory EssayStats.fromJson(Map<String, dynamic> json) {
    return EssayStats(
      articles: _asInt(json['articles']),
      words: _asInt(json['words']),
      activeDays: _asInt(json['active_days']),
      avgWords: _asDouble(json['avg_words']),
      topLabels: (json['top_labels'] as List<dynamic>? ?? const <dynamic>[]).map((e) => LabelStat.fromJson((e as Map<String, dynamic>?) ?? const <String, dynamic>{})).toList(),
      moodCounts: (json['mood_counts'] as Map<String, dynamic>? ?? const <String, dynamic>{}).map((k, v) => MapEntry(k, _asInt(v))),
    );
  }

  final int articles;
  final int words;
  final int activeDays;
  final double avgWords;
  final List<LabelStat> topLabels;
  final Map<String, int> moodCounts;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'articles': articles,
      'words': words,
      'active_days': activeDays,
      'avg_words': avgWords,
      'top_labels': topLabels.map((e) => e.toJson()).toList(),
      'mood_counts': moodCounts,
    };
  }
}

/// review.TaskStat
class TaskStat {
  const TaskStat({
    required this.name,
    required this.done,
    required this.days,
  });

  factory TaskStat.fromJson(Map<String, dynamic> json) {
    return TaskStat(
      name: _asString(json['name']),
      done: _asInt(json['done']),
      days: _asInt(json['days']),
    );
  }

  final String name;
  final int done;
  final int days;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'done': done,
      'days': days,
    };
  }
}

/// review.LabelStat
class LabelStat {
  const LabelStat({
    required this.name,
    required this.count,
  });

  factory LabelStat.fromJson(Map<String, dynamic> json) {
    return LabelStat(
      name: _asString(json['name']),
      count: _asInt(json['count']),
    );
  }

  final String name;
  final int count;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'count': count,
    };
  }
}

/// 后端 JSON 字段容错读取：键缺失或类型不符时回落到空值，避免契约演进直接崩在解析上。
String _asString(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return false;
}
