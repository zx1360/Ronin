// 漫画页的纯逻辑：任务结果摘要、失败判定、输入校验、状态映射。
//
// 与 Vue 无关，字段口径对照 Dart 端 comix_models.dart 与 comix_widgets.dart：
// 后端把退出码 2 的 ok=false 记为 finished，直接把 finished 画成"完成"会把
// 业务失败伪装成成功，因此失败语义必须显式判定。

import { taskStatusKind, taskStatusText } from '../../utils.js';

/** 页面 Tab（与桌面端一致）。 */
export const TABS = [
  { value: 'url', label: '网址下载' },
  { value: 'library', label: '漫画库' },
  { value: 'tasks', label: '任务面板' },
];

/** 漫画库前端过滤项（接口只按库内字段返回，没有服务端过滤参数）。 */
export const FILTERS = [
  { value: 'all', label: '全部' },
  { value: 'public', label: '公开' },
  { value: 'hidden', label: '隐藏' },
  { value: 'readed', label: '已读' },
  { value: 'unread', label: '未读' },
  { value: 'pending', label: '未下完' },
  { value: 'failed', label: '有失败章节' },
  { value: 'legacy', label: 'legacy 资源' },
];

/** 业务级错误：进程正常结束但 CLI 返回 ok=false。 */
export function isBusinessError(task) {
  return !!(task && task.result && task.result.ok === false);
}

/** 失败语义：进程级失败/中断、业务 ok=false、非零退出码都算失败。 */
export function taskFailure(task) {
  if (!task) return false;
  const exitCode = task.exit_code;
  return (
    task.status === 'failed' ||
    task.status === 'killed' ||
    isBusinessError(task) ||
    (exitCode !== null && exitCode !== undefined && exitCode !== 0)
  );
}

/** 任务状态文案（finished + ok=false 显示为业务错误）。 */
export function comixStatusText(task) {
  if (!task) return '未知';
  if (isBusinessError(task) && task.status === 'finished') return '业务错误';
  return taskStatusText(task.status);
}

/** 任务状态徽标样式。 */
export function comixStatusKind(task) {
  if (!task) return '';
  if (isBusinessError(task) && task.status === 'finished') return 'error';
  return taskStatusKind(task.status);
}

/** 失败原因：业务错误优先，再退回任务级 error / stderr 首行。 */
export function taskFailureReason(task) {
  if (!task) return '';
  const result = task.result || {};
  if (typeof result.error === 'string' && result.error) return result.error;
  if (typeof task.error === 'string' && task.error) return task.error;
  if (typeof result.stderr === 'string' && result.stderr) return firstLine(result.stderr);
  return '';
}

/** 任务结果摘要（下载/失败/新章节/追更/回收统计），无结果返回空串。 */
export function taskSummary(task) {
  const result = task && task.result;
  if (!result || typeof result !== 'object') return '';
  const data = result.data;
  if (result.ok === true && data && typeof data === 'object') {
    const parts = [];
    if (typeof data.title === 'string' && data.title) parts.push(data.title);
    if (Array.isArray(data.reports)) parts.push(...updateCheckSummary(data.reports));
    // add-url / update-check 的下载结果嵌套在 data.download 下（协议文档 §4.2/§4.4）
    if (data.download && typeof data.download === 'object') {
      parts.push(...downloadSummary(data.download, '新章节'));
    }
    if (Array.isArray(data.downloaded) || Array.isArray(data.failed)) {
      parts.push(...downloadSummary(data, ''));
    }
    if (data.recovered_tasks !== undefined || data.removed_temp_dirs !== undefined) {
      parts.push(`回收任务 ${data.recovered_tasks || 0} · 清理临时目录 ${data.removed_temp_dirs || 0}`);
    }
    if (data.already_exists === true) parts.push('已登记过，复用现有记录');
    return parts.length ? parts.join(' · ') : '完成';
  }
  if (result.ok === false) {
    const reason = taskFailureReason(task);
    return reason ? `业务错误: ${reason}` : '业务错误（无错误详情，可展开日志查看）';
  }
  return '';
}

/** 追更检查摘要：逐部给出新增章节/进度/站点不可达。 */
function updateCheckSummary(reports) {
  const parts = [];
  const details = [];
  let newCount = 0;
  let errorCount = 0;
  for (const report of reports) {
    if (!report || typeof report !== 'object') continue;
    if (Array.isArray(report.new_chapters)) newCount += report.new_chapters.length;
    const name = report.title || report.comic_id || '';
    if (typeof report.error === 'string' && report.error) {
      // 站点不可达必须显式暴露，否则无法与"检查了但没更新"区分
      errorCount += 1;
      details.push(`${name}: 站点不可达`);
      continue;
    }
    if (typeof report.message === 'string' && report.message) details.push(`${name}: ${report.message}`);
  }
  parts.push(`检查 ${reports.length} 部`);
  parts.push(newCount > 0 ? `新增 ${newCount} 章` : '无新章节');
  if (errorCount > 0) parts.push(`${errorCount} 部站点不可达`);
  if (details.length) parts.push(details.join('；'));
  return parts;
}

/** 下载结果摘要（downloaded/failed/message）。 */
function downloadSummary(data, prefix) {
  const parts = [];
  const downloaded = data.downloaded;
  const failed = data.failed;
  if (Array.isArray(downloaded) && downloaded.length) {
    parts.push(`${prefix}下载成功 ${downloaded.length} 章`);
  }
  if (Array.isArray(failed) && failed.length) {
    parts.push(`${prefix}失败 ${failed.length} 章（已重试一轮）`);
    const first = failed[0];
    if (first && typeof first === 'object' && typeof first.error === 'string' && first.error) {
      parts.push(`示例: ${firstLine(first.error)}`);
    }
  }
  if (Array.isArray(downloaded) && !downloaded.length && (!Array.isArray(failed) || !failed.length)) {
    parts.push('无待下载章节');
  }
  if (typeof data.message === 'string' && data.message) parts.push(data.message);
  return parts;
}

function firstLine(text) {
  const index = String(text).indexOf('\n');
  const line = index >= 0 ? String(text).slice(0, index) : String(text);
  return line.length > 160 ? `${line.slice(0, 160)}…` : line;
}

/** 网址下载的单条提交结果（/API/comix/download-url 的 data.tasks 元素）。 */
export function normalizeSubmit(item) {
  const source = item && typeof item === 'object' ? item : {};
  return {
    url: typeof source.url === 'string' ? source.url : '',
    site: typeof source.site === 'string' ? source.site : '',
    taskId: typeof source.task_id === 'string' ? source.task_id : '',
    status: typeof source.status === 'string' ? source.status : '',
    error: typeof source.error === 'string' ? source.error : '',
  };
}

/** 把提交结果与任务快照合并成展示视图（任务可能尚未出现在列表里）。 */
export function submitResultView(item, task) {
  if (!item.taskId) {
    return {
      ...item,
      kind: 'error',
      text: '提交失败',
      reason: item.error || '未知错误（可能是站点不支持或 comix 集成不可用）',
      summary: '',
    };
  }
  if (!task) {
    return { ...item, kind: 'info', text: '已提交，等待任务出现', reason: item.error || '', summary: '' };
  }
  return {
    ...item,
    status: task.status,
    kind: comixStatusKind(task),
    text: comixStatusText(task),
    reason: taskFailure(task) ? taskFailureReason(task) : '',
    summary: taskSummary(task),
  };
}

/** 「仅下载最新 N 章」校验：返回错误文案，null 表示合法（留空=不限量）。 */
export function validateLatest(raw) {
  const text = String(raw || '').trim();
  if (!text) return null;
  if (!/^\d+$/.test(text)) return '请输入正整数（留空表示不限量）';
  if (Number(text) <= 0) return 'N 必须大于 0（留空表示不限量）';
  return null;
}

/** 章节区间校验：`1-5,8,10-12`；返回错误文案，null 表示合法。 */
export function validateRange(raw) {
  const text = String(raw || '').trim();
  if (!text) return null;
  for (const part of text.split(',')) {
    const segment = part.trim();
    if (!segment) continue;
    const match = /^(\d+)(?:-(\d+))?$/.exec(segment);
    if (!match) return `章节区间格式无效："${segment}"（应形如 1-5,8,10-12）`;
    const start = Number(match[1]);
    if (start <= 0) return `章节号必须为正整数："${segment}"`;
    if (match[2] !== undefined) {
      const end = Number(match[2]);
      if (end <= 0) return `章节号必须为正整数："${segment}"`;
      if (end < start) return `区间结束值小于起始值："${segment}"`;
    }
  }
  return null;
}

const CHAPTER_STATUS = {
  done: ['success', '完成'],
  failed: ['error', '失败'],
  pending: ['', '待下'],
};

/** 章节状态文案。 */
export function chapterStatusText(status) {
  return (CHAPTER_STATUS[status] || ['', status || '未知'])[1];
}

/** 章节状态徽标样式。 */
export function chapterStatusKind(status) {
  return (CHAPTER_STATUS[status] || [''])[0];
}
