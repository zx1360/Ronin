// api.js —— 唯一的 HTTP 出口：统一 fetch 封装 + 全部端点调用。
//
// 路径不手写：全部取自后端契约生成物 ./generated/endpoints.js
// （由 `cd backend && go run ./cmd/route_export` 生成，改了路由就重新生成）。
//
// 页面由 Monarch 同源托管（http://127.0.0.1:<LOCAL_DEBUG_PORT>/ops/），所以
//   - 自己的静态资源用相对路径（./app.css、./js/main.js）；
//   - 接口一律用绝对路径 /API/...（同源，回环请求无需 X-API-Key）。
// 非 2xx 一律抛 ApiError，并把服务端的 error/message 原样带给调用方。

import {
  API,
  aiPersonsId,
  aiPersonsIdPatch,
  aiProcessCapabilityStart,
  aiProcessCapabilityStop,
  aiReviewPresetsId,
  comicComicInfoComicIdPut,
  comixTasksTaskId,
  comixTasksTaskIdStop,
  galleryIdType,
  opsGalleryTasksTaskIdStop,
  staticFilepath,
} from './generated/endpoints.js';

class ApiError extends Error {
  constructor(message, status, payload) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.payload = payload;
  }
}

function buildUrl(path, query) {
  let url = path;
  if (query) {
    const parts = [];
    for (const [key, value] of Object.entries(query)) {
      if (value === undefined || value === null || value === '') continue;
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
    }
    if (parts.length) url += `?${parts.join('&')}`;
  }
  return url;
}

async function request(method, path, { body, query } = {}) {
  const init = { method, headers: {} };
  if (body !== undefined) {
    init.headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(body);
  }
  let response;
  try {
    response = await fetch(buildUrl(path, query), init);
  } catch (err) {
    throw new ApiError(`无法连接服务端：${err.message}`, 0, null);
  }
  const raw = await response.text();
  let data = null;
  if (raw) {
    try {
      data = JSON.parse(raw);
    } catch (err) {
      data = null;
    }
  }
  if (!response.ok) {
    const message = (data && (data.error || data.message)) ||
      (raw ? raw.slice(0, 300) : `HTTP ${response.status}`);
    throw new ApiError(message, response.status, data);
  }
  return data;
}

/** comix 系列响应是 {ok,data} / {ok:false,error} 信封；ok=false 即使 HTTP 200 也算失败。 */
function unwrap(payload) {
  if (payload && typeof payload === 'object' && 'ok' in payload) {
    if (!payload.ok) {
      throw new ApiError(payload.error || 'comix 返回 ok=false', 200, payload);
    }
    return payload.data;
  }
  return payload;
}

const get = (path, query) => request('GET', path, { query });
const post = (path, body, query) => request('POST', path, { body, query });
const put = (path, body) => request('PUT', path, { body });
const patch = (path, body) => request('PATCH', path, { body });
const del = (path, body) => request('DELETE', path, { body });

// ---------- ops：概览 / 能力 / 依赖 / 路径 / 偏好 ----------

export const opsOverview = () => get(API.opsOverview);
export const opsCapabilities = () => get(API.opsCapabilities);
export const opsDependencies = () => get(API.opsDependencies);
export const opsListDirs = (path) => get(API.opsFs, { path });
export const opsReveal = (path) => post(API.opsReveal, { path });
export const getPreferences = () => get(API.opsPreferences);
export const putPreferences = (patchObj) => put(API.opsPreferencesPut, patchObj);

// ---------- ops：gallery CLI 任务 ----------

export const galleryRun = (options) => post(API.opsGalleryTasksPost, options);
export const galleryTasks = () => get(API.opsGalleryTasks);
export const galleryStop = (id) => post(opsGalleryTasksTaskIdStop(id));

// ---------- 运行时配置 ----------

export const getSettings = () => get(API.settings);
export const putSettings = (values) => put(API.settingsPut, values);

// ---------- AI 运维 ----------

export const aiStatus = () => get(API.aiStatus);
export const aiCapabilities = () => get(API.aiCapabilities);
export const aiJobs = (query) => get(API.aiJobs, query);
export const aiEnqueue = (body) => post(API.aiEnqueue, body);
export const aiRetry = (body) => post(API.aiRetry, body);
export const aiCancel = () => post(API.aiCancel, {});
export const aiResume = () => post(API.aiResume, {});
export const aiRebuildIndex = () => post(API.aiIndexRebuild, {});
export const aiProcess = (capability, action) => post(
  action === 'stop' ? aiProcessCapabilityStop(capability) : aiProcessCapabilityStart(capability),
  {},
);

// ---------- AI 检索 / 组织 ----------

export const aiSearch = (query) => get(API.aiSearch, query);
export const aiDuplicates = (query) => get(API.aiDuplicates, query);
export const aiIgnoreDuplicates = (mediaIds) => post(API.aiDuplicatesIgnore, { media_ids: mediaIds });
export const aiUnignoreDuplicates = (mediaIds) => post(API.aiDuplicatesUnignore, { media_ids: mediaIds });
export const aiIgnoredDuplicates = () => get(API.aiDuplicatesIgnored);

export const aiPersons = () => get(API.aiPersons);
export const aiPersonRename = (id, name) => patch(aiPersonsIdPatch(id), { name });
export const aiPersonDelete = (id) => del(aiPersonsId(id));
export const aiPersonsMerge = (sourceIds, targetId) => post(API.aiPersonsMerge, { source_ids: sourceIds, target_id: targetId });
export const aiRecluster = (reset) => post(API.aiRecluster, { reset: Boolean(reset) });

// ---------- AI 近期回顾 ----------

export const aiReviewPresets = () => get(API.aiReviewPresets);
export const aiUpsertReviewPreset = (preset) => post(API.aiReviewPresetsPost, preset);
export const aiDeleteReviewPreset = (id) => del(aiReviewPresetsId(id));
export const aiGenerateReview = (body) => post(API.aiReview, body);

// ---------- gallery 媒体 ----------

export const galleryMedia = (query) => get(API.galleryMedia, query);
export const galleryPatchMedia = (body) => patch(API.galleryMediaPatch, body);

/** 缩略图地址：回环请求无需 API Key，普通 <img src> 即可。 */
export const thumbUrl = (mediaId) => galleryIdType(mediaId, 'thumb');

// ---------- comix ----------

export const comixConfig = async () => unwrap(await get(API.comixConfig));
export const comixInit = async () => unwrap(await post(API.comixInit, {}));
export const comixList = async () => unwrap(await get(API.comixList));
export const comixTasks = async () => unwrap(await get(API.comixTasks));
export const comixTask = async (id) => unwrap(await get(comixTasksTaskId(id)));
export const comixStop = async (id) => unwrap(await post(comixTasksTaskIdStop(id), {}));
export const comixDownloadUrl = async (body) => unwrap(await post(API.comixDownloadUrl, body));
export const comixDownload = async (body) => unwrap(await post(API.comixDownload, body));
export const comixUpdateCheck = async (body) => unwrap(await post(API.comixUpdateCheck, body));
export const comixDelete = async (body) => unwrap(await post(API.comixDelete, body));
export const comixClean = async () => unwrap(await post(API.comixClean, {}));

/** 漫画库管理字段（公开 / 已读）。刻意不发 cover_image。 */
export const comicUpdate = (comicId, fields) => put(comicComicInfoComicIdPut(comicId), fields);

const STATIC_PREFIX = staticFilepath('');
/**
 * /static/{相对路径}：逐段编码。
 * 封面等路径可能含中文、空格，Windows 上还可能是反斜杠分隔，统一按 / 与 \ 切段。
 */
export const staticUrl = (relative) => STATIC_PREFIX +
  String(relative).split(/[\\/]+/).filter(Boolean).map(encodeURIComponent).join('/');
