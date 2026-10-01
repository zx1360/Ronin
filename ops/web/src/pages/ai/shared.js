// AI 页各标签共用的小工具：字段兜底、进度换算、任务文案、库内文件定位。

import { api, assetUrl } from '../../api.js';
import { state, toast } from '../../store.js';

/** 能力展示名（服务端未下发名称时退回能力标识）。 */
export function capabilityLabel(capabilities, name) {
  const found = (capabilities || []).find((item) => item && item.capability === name);
  return (found && found.label) || name || '';
}

/** 数值兜底：接口字段缺失或类型异常时按 0 处理。 */
export function num(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

/** 处理进度百分比（「尚无产物」也计入分母，与桌面端一致）。 */
export function progressPercent(done, pending, missing) {
  const total = num(done) + num(pending) + num(missing);
  if (total <= 0) return 0;
  return Math.min(100, Math.round((num(done) / total) * 100));
}

/** 取库内相对路径的文件名。 */
export function baseName(filePath) {
  const parts = String(filePath || '').split(/[/\\]/).filter(Boolean);
  return parts.length ? parts[parts.length - 1] : '';
}

export const JOB_STATUS_TEXT = {
  pending: '待处理',
  running: '执行中',
  done: '已完成',
  failed: '失败',
};

export function jobStatusText(status) {
  return JOB_STATUS_TEXT[status] || status || '未知';
}

export function jobStatusKind(status) {
  if (status === 'running') return 'info';
  if (status === 'done') return 'success';
  if (status === 'failed') return 'error';
  return '';
}

/**
 * 打开媒体文件所在目录。
 *
 * 绝对路径由服务端下发的 `paths.galleryMedia` 与库内相对路径（相对 Media 目录）
 * 拼成，与桌面端 `FileRevealService.absoluteMediaPath` 同构；该路径不可用时退回
 * `rel_path`（服务端与 gallery 根目录拼接）。没有路径就如实提示，不猜目录。
 */
export async function revealMedia(filePath) {
  const relative = String(filePath || '').replace(/\\/g, '/').replace(/^\/+/, '');
  if (!relative) {
    toast('该记录没有文件路径，无法定位', 'error');
    return;
  }
  const root = String(state.paths.galleryMedia || '').replace(/[/\\]+$/, '');
  const body = root
    ? { path: root + '\\' + relative.replace(/\//g, '\\') }
    : { rel_path: /^media\//i.test(relative) ? relative : 'Media/' + relative };
  try {
    await api.post('/API/ops/local/reveal', body, { timeoutMs: 15000 });
  } catch (err) {
    toast('打开所在目录失败: ' + err.message, 'error');
  }
}

/** 缩略图地址（复用 gallery 文件流，附带 API 密钥）。 */
export function thumbUrl(mediaId) {
  if (!mediaId) return '';
  return assetUrl('/API/gallery/' + mediaId + '/thumb');
}
