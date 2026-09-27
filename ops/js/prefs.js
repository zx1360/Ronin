// prefs.js —— UI 偏好。
//
// 偏好由后端持有（GET/PUT /API/ops/preferences），不使用 localStorage：
// 换浏览器/清缓存后界面状态仍在。写失败要如实提示，不能假装已保存。

import { putPreferences, getPreferences } from './api.js';
import { toast, card } from './dom.js';

const DEFAULTS = {
  auto_refresh_seconds: 5,
  collapsed_sections: [],
  last_tab: '',
  log_autoscroll: true,
};

let state = { ...DEFAULTS };
const listeners = new Set();

export function prefs() {
  return state;
}

export function onPrefs(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function notify() {
  for (const listener of listeners) {
    try {
      listener(state);
    } catch (err) {
      console.warn('[prefs] listener', err);
    }
  }
}

function normalize(value) {
  const merged = { ...DEFAULTS, ...(value || {}) };
  if (!Array.isArray(merged.collapsed_sections)) merged.collapsed_sections = [];
  const seconds = Number(merged.auto_refresh_seconds);
  merged.auto_refresh_seconds = Number.isFinite(seconds) && seconds >= 1 ? Math.min(3600, Math.round(seconds)) : DEFAULTS.auto_refresh_seconds;
  merged.log_autoscroll = Boolean(merged.log_autoscroll);
  merged.last_tab = typeof merged.last_tab === 'string' ? merged.last_tab : '';
  return merged;
}

/** 启动时载入偏好；失败时沿用默认值（页面仍可用）。 */
export async function loadPrefs() {
  try {
    state = normalize(await getPreferences());
  } catch (err) {
    console.warn('[prefs] 读取失败，使用默认值', err);
  }
  notify();
  return state;
}

/** 局部更新偏好并落库；返回落库后的完整偏好。 */
export async function patchPrefs(patch) {
  const previous = state;
  state = normalize({ ...state, ...patch });
  notify();
  try {
    state = normalize(await putPreferences(patch));
  } catch (err) {
    // 写失败必须回滚本地状态：否则界面显示的是没落库的值，下次刷新又变回去。
    state = previous;
    toast(`偏好保存失败：${err.message || err}`, 'error');
  }
  notify();
  return state;
}

function isCollapsed(id) {
  return state.collapsed_sections.includes(id);
}

/**
 * 折叠状态记在服务端偏好里的卡片。
 * 点击立即切换本地样式（不等网络），同时把新状态写回 /API/ops/preferences。
 */
export function collapsibleCard(id, title, body, opts = {}) {
  const node = card(title, body, {
    ...opts,
    collapsed: isCollapsed(id),
    onToggle: () => {
      const collapsed = !node.classList.contains('collapsed');
      node.classList.toggle('collapsed', collapsed);
      const next = new Set(state.collapsed_sections);
      if (collapsed) next.add(id);
      else next.delete(id);
      void patchPrefs({ collapsed_sections: [...next] });
    },
  });
  return node;
}

export function setLastTab(tab) {
  if (!tab || state.last_tab === tab) return;
  void patchPrefs({ last_tab: tab });
}
