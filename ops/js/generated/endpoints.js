// 由 backend/cmd/route_export 生成，请勿手改。
// 重新生成：cd backend && go run ./cmd/route_export
// 路由来自 gin 路由表。

// 静态路径表：键是生成的路由标识符，值是 gin 风格路径模板。
export const API = {
  'aiCancel': '/API/ai/cancel',
  'aiCapabilities': '/API/ai/capabilities',
  'aiChat': '/API/ai/chat',
  'aiDuplicates': '/API/ai/duplicates',
  'aiDuplicatesIgnore': '/API/ai/duplicates/ignore',
  'aiDuplicatesIgnored': '/API/ai/duplicates/ignored',
  'aiDuplicatesUnignore': '/API/ai/duplicates/unignore',
  'aiEnqueue': '/API/ai/enqueue',
  'aiFacesAssign': '/API/ai/faces/assign',
  'aiIndexRebuild': '/API/ai/index/rebuild',
  'aiJobs': '/API/ai/jobs',
  'aiMediaId': '/API/ai/media/:id',
  'aiPersons': '/API/ai/persons',
  'aiPersonsId': '/API/ai/persons/:id',
  'aiPersonsIdPatch': '/API/ai/persons/:id',
  'aiPersonsIdFaces': '/API/ai/persons/:id/faces',
  'aiPersonsMerge': '/API/ai/persons/merge',
  'aiProcessCapabilityStart': '/API/ai/process/:capability/start',
  'aiProcessCapabilityStop': '/API/ai/process/:capability/stop',
  'aiRecluster': '/API/ai/recluster',
  'aiResume': '/API/ai/resume',
  'aiRetry': '/API/ai/retry',
  'aiReview': '/API/ai/review',
  'aiReviewPresets': '/API/ai/review/presets',
  'aiReviewPresetsPost': '/API/ai/review/presets',
  'aiReviewPresetsId': '/API/ai/review/presets/:id',
  'aiSearch': '/API/ai/search',
  'aiSearchImage': '/API/ai/search/image',
  'aiSimilarId': '/API/ai/similar/:id',
  'aiStatus': '/API/ai/status',
  'aiTags': '/API/ai/tags',
  'comicChapterInfoChapterId': '/API/comic/chapter-info/:chapter-id',
  'comicComicInfo': '/API/comic/comic-info',
  'comicComicInfoComicId': '/API/comic/comic-info/:comic-id',
  'comicComicInfoComicIdGet': '/API/comic/comic-info/:comic-id',
  'comicComicInfoComicIdPut': '/API/comic/comic-info/:comic-id',
  'comicDownloadComicId': '/API/comic/download/:comic-id',
  'comicMetaInfo': '/API/comic/meta-info',
  'comicSyncReaded': '/API/comic/sync-readed',
  'comixChaptersComicId': '/API/comix/chapters/:comic-id',
  'comixClean': '/API/comix/clean',
  'comixConfig': '/API/comix/config',
  'comixDelete': '/API/comix/delete',
  'comixDownload': '/API/comix/download',
  'comixDownloadUrl': '/API/comix/download-url',
  'comixInit': '/API/comix/init',
  'comixList': '/API/comix/list',
  'comixSites': '/API/comix/sites',
  'comixTasks': '/API/comix/tasks',
  'comixTasksTaskId': '/API/comix/tasks/:task-id',
  'comixTasksTaskIdStop': '/API/comix/tasks/:task-id/stop',
  'comixUpdateCheck': '/API/comix/update-check',
  'galleryIdType': '/API/gallery/:id/:type',
  'galleryBatch': '/API/gallery/batch',
  'galleryMedia': '/API/gallery/media',
  'galleryMediaPatch': '/API/gallery/media',
  'galleryMediaIdTags': '/API/gallery/media/:id/tags',
  'galleryMediaTags': '/API/gallery/media/tags',
  'galleryOverview': '/API/gallery/overview',
  'galleryTags': '/API/gallery/tags',
  'galleryTagsPost': '/API/gallery/tags',
  'galleryTagsId': '/API/gallery/tags/:id',
  'galleryTagsIdPut': '/API/gallery/tags/:id',
  'opsCapabilities': '/API/ops/capabilities',
  'opsDependencies': '/API/ops/dependencies',
  'opsFs': '/API/ops/fs',
  'opsGalleryTasks': '/API/ops/gallery/tasks',
  'opsGalleryTasksPost': '/API/ops/gallery/tasks',
  'opsGalleryTasksTaskId': '/API/ops/gallery/tasks/:task-id',
  'opsGalleryTasksTaskIdStop': '/API/ops/gallery/tasks/:task-id/stop',
  'opsOverview': '/API/ops/overview',
  'opsPreferences': '/API/ops/preferences',
  'opsPreferencesPut': '/API/ops/preferences',
  'opsReveal': '/API/ops/reveal',
  'ops': '/ops',
  'opsFilepath': '/ops/*filepath',
  'opsFilepathHead': '/ops/*filepath',
  'root': '/',
  'settings': '/API/settings',
  'settingsPut': '/API/settings',
  'staticFilepath': '/static/*filepath',
  'staticFilepathHead': '/static/*filepath',
  'test': '/API/test',
  'userDataBackupModule': '/API/user-data/backup/:module',
  'userDataCheckImagesModule': '/API/user-data/check-images/:module',
  'userDataSyncModule': '/API/user-data/sync/:module',
};

// 带路径参数的端点：返回已编码的完整路径。

/** GET /API/ai/media/:id */
export function aiMediaId(id) {
  return `/API/ai/media/${encodeURIComponent(id)}`;
}

/** DELETE /API/ai/persons/:id */
export function aiPersonsId(id) {
  return `/API/ai/persons/${encodeURIComponent(id)}`;
}

/** PATCH /API/ai/persons/:id */
export function aiPersonsIdPatch(id) {
  return `/API/ai/persons/${encodeURIComponent(id)}`;
}

/** GET /API/ai/persons/:id/faces */
export function aiPersonsIdFaces(id) {
  return `/API/ai/persons/${encodeURIComponent(id)}/faces`;
}

/** POST /API/ai/process/:capability/start */
export function aiProcessCapabilityStart(capability) {
  return `/API/ai/process/${encodeURIComponent(capability)}/start`;
}

/** POST /API/ai/process/:capability/stop */
export function aiProcessCapabilityStop(capability) {
  return `/API/ai/process/${encodeURIComponent(capability)}/stop`;
}

/** DELETE /API/ai/review/presets/:id */
export function aiReviewPresetsId(id) {
  return `/API/ai/review/presets/${encodeURIComponent(id)}`;
}

/** GET /API/ai/similar/:id */
export function aiSimilarId(id) {
  return `/API/ai/similar/${encodeURIComponent(id)}`;
}

/** GET /API/comic/chapter-info/:chapter-id */
export function comicChapterInfoChapterId(chapterId) {
  return `/API/comic/chapter-info/${encodeURIComponent(chapterId)}`;
}

/** DELETE /API/comic/comic-info/:comic-id */
export function comicComicInfoComicId(comicId) {
  return `/API/comic/comic-info/${encodeURIComponent(comicId)}`;
}

/** GET /API/comic/comic-info/:comic-id */
export function comicComicInfoComicIdGet(comicId) {
  return `/API/comic/comic-info/${encodeURIComponent(comicId)}`;
}

/** PUT /API/comic/comic-info/:comic-id */
export function comicComicInfoComicIdPut(comicId) {
  return `/API/comic/comic-info/${encodeURIComponent(comicId)}`;
}

/** GET /API/comic/download/:comic-id */
export function comicDownloadComicId(comicId) {
  return `/API/comic/download/${encodeURIComponent(comicId)}`;
}

/** GET /API/comix/chapters/:comic-id */
export function comixChaptersComicId(comicId) {
  return `/API/comix/chapters/${encodeURIComponent(comicId)}`;
}

/** GET /API/comix/tasks/:task-id */
export function comixTasksTaskId(taskId) {
  return `/API/comix/tasks/${encodeURIComponent(taskId)}`;
}

/** POST /API/comix/tasks/:task-id/stop */
export function comixTasksTaskIdStop(taskId) {
  return `/API/comix/tasks/${encodeURIComponent(taskId)}/stop`;
}

/** GET /API/gallery/:id/:type */
export function galleryIdType(id, type) {
  return `/API/gallery/${encodeURIComponent(id)}/${encodeURIComponent(type)}`;
}

/** PUT /API/gallery/media/:id/tags */
export function galleryMediaIdTags(id) {
  return `/API/gallery/media/${encodeURIComponent(id)}/tags`;
}

/** DELETE /API/gallery/tags/:id */
export function galleryTagsId(id) {
  return `/API/gallery/tags/${encodeURIComponent(id)}`;
}

/** PUT /API/gallery/tags/:id */
export function galleryTagsIdPut(id) {
  return `/API/gallery/tags/${encodeURIComponent(id)}`;
}

/** GET /API/ops/gallery/tasks/:task-id */
export function opsGalleryTasksTaskId(taskId) {
  return `/API/ops/gallery/tasks/${encodeURIComponent(taskId)}`;
}

/** POST /API/ops/gallery/tasks/:task-id/stop */
export function opsGalleryTasksTaskIdStop(taskId) {
  return `/API/ops/gallery/tasks/${encodeURIComponent(taskId)}/stop`;
}

/** GET /ops/*filepath */
export function opsFilepath(filepath) {
  return `/ops/${filepath}`;
}

/** HEAD /ops/*filepath */
export function opsFilepathHead(filepath) {
  return `/ops/${filepath}`;
}

/** GET /static/*filepath */
export function staticFilepath(filepath) {
  return `/static/${filepath}`;
}

/** HEAD /static/*filepath */
export function staticFilepathHead(filepath) {
  return `/static/${filepath}`;
}

/** POST /API/user-data/backup/:module */
export function userDataBackupModule(module) {
  return `/API/user-data/backup/${encodeURIComponent(module)}`;
}

/** POST /API/user-data/check-images/:module */
export function userDataCheckImagesModule(module) {
  return `/API/user-data/check-images/${encodeURIComponent(module)}`;
}

/** GET /API/user-data/sync/:module */
export function userDataSyncModule(module) {
  return `/API/user-data/sync/${encodeURIComponent(module)}`;
}
