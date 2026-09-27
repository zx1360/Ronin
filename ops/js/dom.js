// dom.js —— 极简 DOM 构建与格式化工具。
//
// 没有虚拟 DOM、没有组件框架：视图函数直接用 el() 产出节点，刷新时重建局部子树。
// 约定：attrs 里以 on 开头且值为函数的键会被当作事件监听（onclick → click）。
// value 记到子节点挂载之后再赋值，保证 <select> 的选项已存在。

export function el(tag, attrs = null, children = null) {
  const node = document.createElement(tag);
  let pendingValue = null;
  if (attrs) {
    for (const [key, value] of Object.entries(attrs)) {
      if (value === null || value === undefined || value === false) continue;
      if (key === 'class' || key === 'className') node.className = String(value);
      else if (key === 'text') node.textContent = String(value);
      else if (key === 'value') pendingValue = value;
      else if (key === 'style' && typeof value === 'object') Object.assign(node.style, value);
      else if (key === 'dataset' && typeof value === 'object') Object.assign(node.dataset, value);
      else if (key.startsWith('on') && typeof value === 'function') node.addEventListener(key.slice(2), value);
      else if (typeof value === 'boolean') node[key] = value;
      else node.setAttribute(key, String(value));
    }
  }
  append(node, children);
  if (pendingValue !== null) node.value = pendingValue;
  return node;
}

function append(node, children) {
  if (children === null || children === undefined || typeof children === 'boolean') return node;
  if (Array.isArray(children)) {
    for (const child of children) append(node, child);
    return node;
  }
  if (children instanceof Node) {
    node.appendChild(children);
    return node;
  }
  node.appendChild(document.createTextNode(String(children)));
  return node;
}

export function clear(node) {
  while (node.firstChild) node.removeChild(node.firstChild);
  return node;
}

/** 用新内容替换容器里的全部子节点。 */
export function mount(parent, ...children) {
  clear(parent);
  append(parent, children);
  return parent;
}

function on(node, event, handler, options) {
  node.addEventListener(event, handler, options);
  return node;
}

// ---------- 格式化 ----------

export function fmtBytes(bytes) {
  const n = Number(bytes);
  if (!Number.isFinite(n) || n < 0) return '—';
  if (n < 1024) return `${n} B`;
  const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
  let value = n / 1024;
  let i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i += 1;
  }
  return `${value >= 100 ? value.toFixed(0) : value.toFixed(1)} ${units[i]}`;
}

export function fmtNum(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n.toLocaleString('zh-CN') : '—';
}

function pad(value) {
  return String(value).padStart(2, '0');
}

/** 完整时间（本地时区）。 */
export function fmtTime(value) {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ` +
    `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

/** 只要时分秒（日志行前缀）。 */
function fmtClock(value) {
  if (!value) return '--:--:--';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '--:--:--';
  return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

export function fmtDuration(from, to) {
  if (!from) return '—';
  const start = new Date(from).getTime();
  const end = to ? new Date(to).getTime() : Date.now();
  if (!Number.isFinite(start) || !Number.isFinite(end)) return '—';
  let seconds = Math.max(0, Math.round((end - start) / 1000));
  if (seconds < 60) return `${seconds} 秒`;
  const minutes = Math.floor(seconds / 60);
  seconds %= 60;
  if (minutes < 60) return `${minutes} 分 ${seconds} 秒`;
  const hours = Math.floor(minutes / 60);
  return `${hours} 小时 ${minutes % 60} 分`;
}

/** 把任意值渲染成可读文本（null/undefined/空串统一为占位符）。 */
export function text(value, fallback = '—') {
  if (value === null || value === undefined || value === '') return fallback;
  return String(value);
}

// ---------- 小部件 ----------

export function badge(label, kind = '') {
  return el('span', { class: `badge${kind ? ' badge-' + kind : ''}`, text: label });
}

export function emptyBox(message = '加载中…') {
  return el('div', { class: 'empty', text: message });
}

export function alertBox(message, kind = 'warn', action = null) {
  return el('div', { class: `alert alert-${kind}` }, [
    el('span', { class: 'alert-text', text: message }),
    action || null,
  ]);
}

export function errorBox(message, onRetry = null) {
  return alertBox(message, 'error', onRetry ? el('button', { class: 'btn btn-sm', text: '重试', onclick: onRetry }) : null);
}

export function btn(label, onclick, opts = {}) {
  const { kind = '', title = null, disabled = false, size = '' } = opts;
  return el('button', {
    class: `btn${kind ? ' btn-' + kind : ''}${size ? ' btn-' + size : ''}`,
    text: label,
    title,
    disabled,
    onclick,
  });
}

/** 可折叠卡片：collapsed 由调用方（偏好）决定，onToggle 由调用方落库。 */
export function card(title, body, opts = {}) {
  const { collapsed = false, onToggle = null, actions = null, subtitle = null } = opts;
  const head = el('div', { class: 'card-head' }, [
    onToggle ? el('button', {
      class: 'icon-btn',
      title: collapsed ? '展开' : '折叠',
      text: collapsed ? '▸' : '▾',
      onclick: onToggle,
    }) : null,
    el('h2', { class: 'card-title', text: title }),
    subtitle ? el('span', { class: 'card-sub muted', text: subtitle }) : null,
    el('div', { class: 'spacer' }),
    actions || null,
  ]);
  const node = el('section', { class: `card${collapsed ? ' collapsed' : ''}` }, [
    head,
    el('div', { class: 'card-body' }, body),
  ]);
  return node;
}

/** 键值表：items 为 [标签, 值节点或文本] 数组。 */
export function kvList(items) {
  return el('dl', { class: 'kv' }, items.map(([label, value]) => [
    el('dt', { text: label }),
    el('dd', null, value),
  ]));
}

/** 复制按钮：路径类内容统一用它。 */
export function copyBtn(value, label = '复制') {
  return btn(label, async () => {
    const ok = await copyText(value);
    toast(ok ? '已复制到剪贴板' : '复制失败，请手动选择', ok ? 'ok' : 'error');
  }, { size: 'sm', kind: 'ghost', title: value });
}

export function tableEl(headers, rows) {
  return el('div', { class: 'table-wrap' }, el('table', { class: 'table' }, [
    el('thead', null, el('tr', null, headers.map((header) => (
      typeof header === 'string'
        ? el('th', { text: header })
        : el('th', { text: header.title, class: header.class || null })
    )))),
    el('tbody', null, rows),
  ]));
}

/** 这些类要从单元格子节点"上提"到 <td> 上，否则对齐/内边距不生效。 */
const CELL_CLASSES = ['num', 'ta-center', 'ta-right', 'ta-left'];

/**
 * 表格行：字符串自动包成 <td>；已经是 td/th 的节点原样使用；
 * 其它节点（span/div/input…）也包一层真实 <td> —— 直接塞进 <tr> 会变成匿名单元格，
 * 拿不到 td 的内边距与对齐样式。
 */
export function tr(cells, attrs = null) {
  return el('tr', attrs, cells.map((cell) => {
    if (cell === null || cell === undefined || cell === false) return el('td');
    if (cell instanceof Node) {
      const tag = String(cell.tagName || '').toUpperCase();
      if (tag === 'TD' || tag === 'TH') return cell;
      const lifted = CELL_CLASSES.filter((cls) => cell.classList && cell.classList.contains(cls));
      for (const cls of lifted) cell.classList.remove(cls);
      return el('td', { class: lifted.length ? lifted.join(' ') : null }, cell);
    }
    return el('td', null, cell);
  }));
}

// ---------- 日志面板 ----------

/**
 * 日志面板：等宽、贴底滚动。
 * update(logs, autoscroll) 每次重建内容，只有"原本就在底部"时才继续贴底。
 */
export function logView() {
  const node = el('pre', { class: 'logs' });
  let stick = true;
  on(node, 'scroll', () => {
    stick = node.scrollHeight - node.scrollTop - node.clientHeight < 24;
  });
  function update(logs, autoscroll = true) {
    const wasAtBottom = stick;
    clear(node);
    for (const entry of logs || []) {
      append(node, el('div', { class: `log-line log-${entry.stream || 'stdout'}` }, [
        el('span', { class: 'log-time', text: fmtClock(entry.time) }),
        el('span', { class: 'log-text', text: entry.text }),
      ]));
    }
    if (!logs || logs.length === 0) {
      append(node, el('div', { class: 'log-line log-system' }, [
        el('span', { class: 'log-text', text: '（暂无日志）' }),
      ]));
    }
    if (autoscroll && wasAtBottom) node.scrollTop = node.scrollHeight;
  }
  return { node, update };
}

// ---------- 剪贴板与提示 ----------

async function copyText(value) {
  const content = String(value ?? '');
  if (!content) return false;
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(content);
      return true;
    }
  } catch (err) {
    // 回退到 execCommand
  }
  try {
    const area = el('textarea', { class: 'clip-fallback' });
    area.value = content;
    document.body.appendChild(area);
    area.select();
    const ok = document.execCommand('copy');
    area.remove();
    return ok;
  } catch (err) {
    return false;
  }
}

export function toast(message, kind = 'info') {
  const host = document.getElementById('toasts');
  if (!host) return;
  const node = el('div', { class: `toast toast-${kind}`, text: message });
  host.appendChild(node);
  const ttl = kind === 'error' ? 7000 : 3200;
  setTimeout(() => {
    node.classList.add('leaving');
    setTimeout(() => node.remove(), 320);
  }, ttl);
}

/** 统一的错误提示：把服务端的 error 字段如实抛给用户。 */
export function toastError(err) {
  toast(err && err.message ? err.message : String(err), 'error');
}

// ---------- 模态框 ----------

/** 简单模态框，返回 { close }。body 为节点数组，foot 为按钮数组。 */
function modal(title, body, foot = []) {
  const mask = el('div', { class: 'modal-mask' });
  const close = () => {
    mask.remove();
    document.removeEventListener('keydown', onKey);
  };
  const onKey = (event) => {
    if (event.key === 'Escape') close();
  };
  const box = el('div', { class: 'modal' }, [
    el('div', { class: 'card-head' }, [
      el('h2', { class: 'card-title', text: title }),
      el('div', { class: 'spacer' }),
      el('button', { class: 'icon-btn', text: '✕', title: '关闭', onclick: close }),
    ]),
    el('div', { class: 'modal-body card-body' }, body),
    el('div', { class: 'card-body modal-foot' }, foot),
  ]);
  mask.appendChild(box);
  on(mask, 'click', (event) => {
    if (event.target === mask) close();
  });
  document.addEventListener('keydown', onKey);
  document.body.appendChild(mask);
  return { close, node: box };
}

/** 目录选择器：GET /API/ops/fs?path= 逐层下钻，选择目录后回调。 */
export function dirPicker(listDirs, initialPath, onPick) {
  let current = initialPath || '';
  const list = el('div', { class: 'dir-list' });
  const pathText = el('div', { class: 'mono muted', text: current || '（选择盘符）' });

  async function load(path) {
    mount(list, emptyBox());
    try {
      const data = await listDirs(path);
      current = path;
      pathText.textContent = path || '（选择盘符）';
      const entries = data.entries || [];
      const items = [];
      if (path && data.parent !== undefined && data.parent !== '') {
        items.push(el('button', {
          class: 'dir-item', text: '⬆ 上级目录',
          onclick: () => load(data.parent),
        }));
      }
      if (path) {
        items.push(el('button', {
          class: 'dir-item', text: '⤴ 回到盘符列表',
          onclick: () => load(''),
        }));
      }
      for (const entry of entries) {
        items.push(el('button', {
          class: 'dir-item',
          text: `📁 ${entry.name}`,
          title: entry.path,
          onclick: () => load(entry.path),
        }));
      }
      if (items.length === 0) items.push(emptyBox('没有子目录'));
      mount(list, items);
    } catch (err) {
      mount(list, errorBox(err.message || String(err), () => load(path)));
    }
  }

  const dialog = modal('选择目录', [pathText, list], [
    btn('取消', () => dialog.close(), { kind: 'ghost' }),
    btn('选择此目录', () => {
      if (!current) {
        toast('请先进入一个目录', 'error');
        return;
      }
      onPick(current);
      dialog.close();
    }, { kind: 'primary' }),
  ]);
  void load(current);
  return dialog;
}
