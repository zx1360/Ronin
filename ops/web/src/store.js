// 全局状态：引导信息（密钥/偏好/路径/能力）、路由、通知与二次确认。
//
// 偏好由服务端持有（static/data/ops_web.json），页面只在内存中镜像一份，
// 不写 localStorage 等浏览器存储。

import { reactive, computed } from './vue.js';
import { api, setApiKey } from './api.js';

export const state = reactive({
  ready: false,
  bootError: '',
  apiKey: '',
  // 字段名与服务端 ops_web.json 一致（snake_case），不要另起一套命名
  settings: {
    auto_refresh_seconds: 10,
    ai_refresh_seconds: 3,
    log_line_limit: 800,
    confirm_destructive: true,
  },
  settingsPath: '',
  service: { port: '' },
  paths: { staticDir: '', galleryDir: '', galleryMedia: '', opsWebDir: '', dbFile: '' },
  cli: {
    gallery: { path: '', available: false, message: '', defaults: {} },
    comix: { available: false, message: '', root: '' },
  },
  deps: { ffmpeg: false, ffprobe: false },
  route: parseRoute(),
  toasts: [],
  dialog: null,
});

/** 当前路由（形如 /dashboard，不含前导 #）。 */
export function parseRoute() {
  const raw = window.location.hash.replace(/^#/, '');
  const path = raw.split('?')[0].trim();
  return path || '/dashboard';
}

/** 切换页面（写入 hash，由 hashchange 统一驱动视图）。 */
export function navigate(path) {
  if (window.location.hash === `#${path}`) return;
  window.location.hash = path;
}

/** 从服务端取回网页端引导信息；失败时页面显示明确原因而不是空白。 */
export async function bootstrap() {
  try {
    const data = await api.get('/API/ops/local/bootstrap');
    state.apiKey = data.apiKey || '';
    setApiKey(state.apiKey);
    state.settingsPath = data.settingsPath || '';
    Object.assign(state.settings, data.settings || {});
    Object.assign(state.service, data.service || {});
    Object.assign(state.paths, data.paths || {});
    Object.assign(state.cli, data.cli || {});
    Object.assign(state.deps, data.deps || {});
    state.ready = true;
    state.bootError = '';
  } catch (error) {
    state.ready = false;
    state.bootError = `无法连接 Monarch 本机接口：${error.message}`;
  }
}

/** 保存偏好（局部更新），成功后同步内存镜像。 */
export async function saveSettings(update) {
  const data = await api.put('/API/ops/local/settings', update);
  Object.assign(state.settings, data?.data?.settings || {});
  return state.settings;
}

/** 弹出提示（自动消失）。 */
export function toast(message, kind = 'info') {
  const id = Date.now() + Math.random();
  state.toasts.push({ id, message: String(message), kind });
  setTimeout(() => {
    const index = state.toasts.findIndex((item) => item.id === id);
    if (index >= 0) state.toasts.splice(index, 1);
  }, kind === 'error' ? 8000 : 3500);
}

/**
 * 二次确认。破坏性操作前调用，返回 Promise<boolean>。
 * 偏好里关掉确认（confirm_destructive=false）时直接放行。
 */
export function confirmAction(message, { title = '请确认', danger = false } = {}) {
  if (!state.settings.confirm_destructive) return Promise.resolve(true);
  return new Promise((resolve) => {
    state.dialog = { title, message, danger, resolve };
  });
}

/** 关闭确认框（供对话框组件调用）。 */
export function resolveDialog(ok) {
  const dialog = state.dialog;
  state.dialog = null;
  if (dialog) dialog.resolve(ok);
}

/** 统一处理页面里的异步动作错误：提示 + 可选的重新加载。 */
export async function runAction(action, { errorPrefix = '操作失败' } = {}) {
  try {
    return await action();
  } catch (error) {
    toast(`${errorPrefix}: ${error.message}`, 'error');
    return null;
  }
}

/** 服务端是否已就绪（供页面按钮禁用）。 */
export const serviceOnline = computed(() => state.ready);
