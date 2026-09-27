// main.js —— 引导、hash 路由与左侧导航。
//
// 路由：#/<视图>[/<子标签>]，例如 #/overview、#/ai/status。
// 视图模块约定：导出 title 与 render(root, { sub })，render 返回可选的清理函数。

import { el, clear, mount, errorBox } from './dom.js';
import { loadPrefs, prefs, setLastTab } from './prefs.js';
import * as overview from './views/overview.js';
import * as gallery from './views/gallery.js';
import * as ai from './views/ai.js';
import * as comix from './views/comix.js';
import * as settings from './views/settings.js';

const NAV = [
  { id: 'overview', label: '概览', icon: '▤' },
  { id: 'gallery', label: '媒体库', icon: '▧' },
  { id: 'ai', label: 'AI 媒体处理', icon: '◈' },
  { id: 'comix', label: '漫画资源', icon: '▣' },
  { id: 'settings', label: '设置', icon: '⚙' },
];

const VIEWS = { overview, gallery, ai, comix, settings };

const navEl = document.getElementById('nav');
const viewEl = document.getElementById('view');
const titleEl = document.getElementById('view-title');
const stateEl = document.getElementById('boot-state');

let disposeCurrent = null;
let currentKey = '';

function parseHash() {
  const raw = (location.hash || '').replace(/^#\/?/, '');
  const parts = raw.split('/').filter(Boolean).map((part) => {
    try {
      return decodeURIComponent(part);
    } catch (err) {
      return part;
    }
  });
  return { id: parts[0] || '', sub: parts[1] || '' };
}

function renderNav() {
  mount(navEl, NAV.map((item) => el('button', {
    class: 'nav-item',
    dataset: { nav: item.id },
    onclick: () => { location.hash = `#/${item.id}`; },
  }, [
    el('span', { class: 'nav-icon', text: item.icon }),
    el('span', { text: item.label }),
  ])));
}

function markNav(activeId) {
  for (const node of navEl.querySelectorAll('.nav-item')) {
    node.classList.toggle('active', node.dataset.nav === activeId);
  }
}

async function renderRoute() {
  const { id, sub } = parseHash();
  const viewId = VIEWS[id] ? id : 'overview';
  const key = `${viewId}/${sub}`;
  if (key === currentKey) return;
  currentKey = key;

  if (typeof disposeCurrent === 'function') {
    try {
      disposeCurrent();
    } catch (err) {
      console.warn('[router] dispose', err);
    }
  }
  disposeCurrent = null;

  markNav(viewId);
  setLastTab(viewId);

  const view = VIEWS[viewId];
  titleEl.textContent = view.title || viewId;
  clear(viewEl);
  try {
    const dispose = await view.render(viewEl, { sub });
    if (typeof dispose === 'function') disposeCurrent = dispose;
  } catch (err) {
    console.error('[router] 渲染失败', err);
    clear(viewEl);
    viewEl.appendChild(errorBox(`页面渲染失败：${err.message || err}`, () => {
      currentKey = '';
      void renderRoute();
    }));
  }
}

async function boot() {
  renderNav();
  await loadPrefs();
  if (!VIEWS[parseHash().id]) {
    const remembered = NAV.some((item) => item.id === prefs().last_tab) ? prefs().last_tab : 'overview';
    location.replace(`#/${remembered}`);
  }
  window.addEventListener('hashchange', () => { void renderRoute(); });
  await renderRoute();
  stateEl.textContent = `服务端：${location.host}`;
}

void boot();
