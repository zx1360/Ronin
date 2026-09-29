// 由 backend/cmd/route_export 生成，请勿手改。
// 重新生成：cd backend && go run ./cmd/route_export
// 路由来自 gin 路由表；业务模型不在此文件，见各 feature 的 models/。

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
