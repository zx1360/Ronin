// overview.js —— 概览：服务、数据库、存储用量与依赖。

import {
  opsOverview, opsCapabilities, opsDependencies, opsReveal,
} from '../api.js';
import {
  el, mount, kvList, tableEl, tr, badge, btn, copyBtn,
  errorBox, alertBox, emptyBox, fmtBytes, fmtNum, fmtTime, toast, text,
} from '../dom.js';
import { createPoller } from '../poll.js';
import { prefs, onPrefs, patchPrefs, collapsibleCard } from '../prefs.js';

export const title = '概览';

const STORAGE_ROWS = [
  ['static', '静态资源'],
  ['galleryRoot', '媒体库根目录'],
  ['galleryMedia', 'Media 原图'],
  ['galleryThumbs', 'Thumbs 缩略图'],
  ['galleryPreview', 'Preview 预览图'],
  ['galleryAI', 'AI 派生'],
  ['galleryDeleted', 'Deleted 已删除'],
];

async function revealPath(path) {
  if (!path) {
    toast('路径为空，无法定位', 'error');
    return;
  }
  try {
    await opsReveal(path);
  } catch (err) {
    toast(`打开目录失败：${err.message || err}`, 'error');
  }
}

function pathCell(pathValue) {
  if (!pathValue) return el('span', { class: 'muted', text: '—' });
  return el('span', { class: 'row' }, [
    el('span', { class: 'mono', text: pathValue }),
    copyBtn(pathValue),
  ]);
}

function serviceCard(overview, capabilities) {
  const service = overview.service || {};
  const paths = (capabilities && capabilities.paths) || {};
  const gallery = (capabilities && capabilities.gallery) || {};
  const items = [
    ['运行模式', service.isLocalMode
      ? badge('本地调试（HTTP，回环免鉴权）', 'info')
      : badge('生产（HTTPS，X-API-Key）', 'warn')],
    ['监听端口', el('span', { class: 'mono', text: text(service.port) })],
    ['访问地址', el('span', { class: 'mono', text: location.origin })],
    ['ops 网页目录', pathCell(service.opsDir || paths.opsDir)],
    ['gallery CLI', service.galleryCli
      ? pathCell(service.galleryCli)
      : el('span', { class: 'err-text', text: '未找到（媒体库任务不可用）' })],
    ['静态资源目录', pathCell(service.staticDir || paths.staticDir)],
  ];
  if (service.staticDirError) {
    items.push(['静态目录解析', el('span', { class: 'err-text', text: service.staticDirError })]);
  }
  items.push(['媒体库 CLI 状态', gallery.available
    ? badge('可用', 'ok')
    : badge(gallery.reason || '不可用', 'err')]);
  return collapsibleCard('overview.service', '服务', [kvList(items)]);
}

function databaseCard(overview) {
  const db = overview.database || {};
  const body = [
    kvList([
      ['数据库文件', pathCell(db.path)],
      ['文件大小', el('span', { class: 'mono', text: fmtBytes(db.bytes) })],
      ['WAL 大小', el('span', { class: 'mono', text: fmtBytes(db.walBytes) })],
      ['连通性', db.reachable ? badge('可访问', 'ok') : badge('不可访问', 'err')],
    ]),
  ];
  if (db.error) body.push(alertBox(db.error, 'error'));
  if (db.path) body.push(el('div', { class: 'row' }, [btn('打开所在目录', () => revealPath(dirName(db.path)), { size: 'sm' })]));
  return collapsibleCard('overview.database', '数据库（SQLite 单文件）', body);
}

function dirName(filePath) {
  const normalized = String(filePath).replace(/[\\/]+$/, '');
  const index = Math.max(normalized.lastIndexOf('\\'), normalized.lastIndexOf('/'));
  return index > 0 ? normalized.slice(0, index) : normalized;
}

function storageCard(overview) {
  const storage = overview.storage || {};
  const rows = STORAGE_ROWS.map(([key, label]) => {
    const usage = storage[key];
    if (!usage) {
      return tr([label, el('span', { class: 'muted', text: '—' }), '—', '—', '—', '—']);
    }
    return tr([
      label,
      pathCell(usage.path),
      usage.exists ? badge('存在', 'ok') : badge('不存在', 'warn'),
      el('span', { class: 'num', text: fmtNum(usage.files) }),
      el('span', { class: 'num', text: fmtBytes(usage.bytes) }),
      el('span', { class: 'row' }, [
        usage.error ? el('span', { class: 'err-text', text: usage.error }) : null,
        btn('打开目录', () => revealPath(usage.path), { size: 'sm', disabled: !usage.path }),
      ]),
    ]);
  });
  const table = tableEl(['名称', '路径', '存在', { title: '文件数', class: 'ta-right' }, { title: '占用', class: 'ta-right' }, '操作'], rows);
  return collapsibleCard('overview.storage', '存储', [
    table,
    el('div', { class: 'hint', text: 'Media / Deleted 的数量与体积由数据库聚合得出，其余由服务端后台按 5 分钟 TTL 统计。' }),
  ]);
}

function dependencyCard(dependencies) {
  const list = (dependencies && dependencies.dependencies) || [];
  if (list.length === 0) return collapsibleCard('overview.deps', '外部依赖', [emptyBox('服务端未返回依赖清单')]);
  const rows = list.map((item) => tr([
    el('span', { class: 'mono', text: item.name }),
    item.available ? badge('可用', 'ok') : badge('缺失', 'err'),
    el('span', { class: 'mono muted', text: text(item.path) }),
    el('span', { class: 'muted', text: text(item.required_for) }),
  ]));
  return collapsibleCard('overview.deps', '外部依赖', [tableEl(['命令', '状态', '解析路径', '用途'], rows)]);
}

export async function render(root, ctx) {
  let data = { overview: null, capabilities: null, dependencies: null };
  let lastError = null;
  let updatedAt = 0;

  const statusText = el('span', { class: 'muted', text: '尚未刷新' });
  const intervalInput = el('input', {
    type: 'number', min: '1', max: '3600', class: 'w-90',
    value: String(prefs().auto_refresh_seconds),
    title: '自动刷新间隔（秒），保存在服务端偏好里',
  });
  intervalInput.addEventListener('change', () => {
    const seconds = Number(intervalInput.value);
    if (!Number.isFinite(seconds) || seconds < 1 || seconds > 3600) {
      intervalInput.value = String(prefs().auto_refresh_seconds);
      toast('自动刷新间隔需在 1..3600 秒之间', 'error');
      return;
    }
    void patchPrefs({ auto_refresh_seconds: Math.round(seconds) });
  });

  const toolbar = el('div', { class: 'toolbar' }, [
    el('label', { class: 'inline' }, ['自动刷新', intervalInput, el('span', { text: '秒' })]),
    btn('立即刷新', () => { void refresh(); }),
    statusText,
    el('div', { class: 'spacer' }),
    el('span', { class: 'hint', text: '概览数据来自 /API/ops/overview、/capabilities、/dependencies' }),
  ]);

  const content = el('div', { class: 'view-body' });
  mount(root, toolbar, content);

  async function refresh() {
    try {
      const [overview, capabilities, dependencies] = await Promise.all([
        opsOverview(), opsCapabilities(), opsDependencies(),
      ]);
      data = { overview, capabilities, dependencies };
      lastError = null;
      updatedAt = Date.now();
    } catch (err) {
      lastError = err;
    }
    renderContent();
  }

  function renderContent() {
    statusText.textContent = updatedAt ? `最近更新 ${fmtTime(updatedAt)}` : '尚未刷新';
    if (lastError) {
      mount(content,
        errorBox(`读取概览失败：${lastError.message || lastError}`, () => { void refresh(); }),
        el('div', { class: 'hint', text: '若提示数据库未迁移，请先初始化 SQLite 库再重试；这是环境问题，不是页面问题。' }));
      return;
    }
    if (!data.overview) {
      mount(content, emptyBox('加载中…'));
      return;
    }
    mount(content,
      el('div', { class: 'grid-2' }, [
        serviceCard(data.overview, data.capabilities),
        databaseCard(data.overview),
      ]),
      storageCard(data.overview),
      dependencyCard(data.dependencies));
  }

  let pollerInterval = prefs().auto_refresh_seconds * 1000;
  let poller = createPoller(() => refresh(), { interval: pollerInterval });
  const offPrefs = onPrefs((next) => {
    const wanted = next.auto_refresh_seconds * 1000;
    intervalInput.value = String(next.auto_refresh_seconds);
    if (wanted === pollerInterval) return;
    poller.dispose();
    pollerInterval = wanted;
    poller = createPoller(() => refresh(), { interval: wanted });
    poller.start();
  });

  poller.start();
  await refresh();

  return () => {
    offPrefs();
    poller.dispose();
  };
}
