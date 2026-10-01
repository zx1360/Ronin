// 展示层格式化工具：时间、体积、状态文案。

/** 字节数转为可读体积。 */
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

/** 相对时间（"3 分钟前"）。 */
export function formatAgo(value) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
  if (seconds < 60) return `${seconds} 秒前`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)} 分钟前`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)} 小时前`;
  return `${Math.floor(seconds / 86400)} 天前`;
}

/** 耗时文本（毫秒）。 */
export function formatDuration(ms) {
  if (!Number.isFinite(ms) || ms < 0) return '—';
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return `${seconds} 秒`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} 分 ${seconds % 60} 秒`;
  return `${Math.floor(minutes / 60)} 时 ${minutes % 60} 分`;
}

const TASK_STATUS_TEXT = {
  running: '运行中',
  finished: '已完成',
  failed: '失败',
  killed: '已中断',
};

/** 任务状态文案。 */
export function taskStatusText(status) {
  return TASK_STATUS_TEXT[status] || status || '未知';
}

/** 任务状态对应的徽标样式。 */
export function taskStatusKind(status) {
  if (status === 'running') return 'info';
  if (status === 'finished') return 'success';
  if (status === 'failed') return 'error';
  if (status === 'killed') return 'warning';
  return '';
}

/** 把异常转为可展示的错误文案。 */
export function errorText(error) {
  if (!error) return '';
  return error.message || String(error);
}
