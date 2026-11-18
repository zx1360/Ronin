export function formatBytes(bytes) {
  const value = Number(bytes);
  if (!Number.isFinite(value) || value <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let index = 0;
  let size = value;
  while (size >= 1024 && index < units.length - 1) {
    size /= 1024;
    index += 1;
  }
  return `${size >= 100 || index === 0 ? Math.round(size) : size.toFixed(1)} ${units[index]}`;
}

/** 时间戳（ISO 字符串 / 毫秒）转为本地时间文本。 */
export function formatTime(value, withSeconds = true) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  const pad = (n) => String(n).padStart(2, '0');
  const base = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  return withSeconds ? `${base}:${pad(date.getSeconds())}` : base;
}

/** 仅时分秒（日志行用）。 */
export function formatClock(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return '--:--:--';
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

const TASK_STATUS_TEXT = {
  queued: '排队中',
  running: '运行中',
  finished: '已完成',
  failed: '失败',
  killed: '已中断',
};

export const taskActive = (status) => status === 'queued' || status === 'running';

export function taskStatusText(status) {
  return TASK_STATUS_TEXT[status] || status || '未知';
}

export function taskStatusKind(status) {
  if (status === 'queued') return 'warning';
  if (status === 'running') return 'info';
  if (status === 'finished') return 'success';
  if (status === 'failed') return 'error';
  if (status === 'killed') return 'warning';
  return '';
}
