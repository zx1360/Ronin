// 请求层：网页端与 Monarch 同源，所有接口都走相对路径。
//
// 生产模式下 /API/* 需要 X-API-Key；密钥由 /API/ops/local/bootstrap 下发
// （仅本机回环可访问），页面不落盘、不写用户目录。

let apiKey = '';

/** 设置后续请求使用的 API 密钥（引导阶段调用一次）。 */
export function setApiKey(key) {
  apiKey = (key || '').trim();
}

/** 供 <img src> 等无法附加请求头的资源拼装带密钥的 URL。 */
export function assetUrl(path) {
  if (!apiKey) return path;
  return `${path}${path.includes('?') ? '&' : '?'}api_key=${encodeURIComponent(apiKey)}`;
}

/** 接口异常：把 HTTP 状态码与服务端 error 文案归一化为可读信息。 */
export class ApiError extends Error {
  constructor(message, status, body) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.body = body;
  }
}

/**
 * 发起一次接口请求。
 * @param {string} method HTTP 方法
 * @param {string} path 以 / 开头的接口路径
 * @param {{body?: any, signal?: AbortSignal, timeoutMs?: number}} [options]
 */
export async function request(method, path, options = {}) {
  const { body, signal, timeoutMs = 60000 } = options;
  const headers = { Accept: 'application/json' };
  if (apiKey) headers['X-API-Key'] = apiKey;
  if (body !== undefined) headers['Content-Type'] = 'application/json';

  const controller = new AbortController();
  const timer = timeoutMs > 0 ? setTimeout(() => controller.abort(), timeoutMs) : null;
  if (signal) {
    if (signal.aborted) controller.abort();
    else signal.addEventListener('abort', () => controller.abort(), { once: true });
  }

  let response;
  try {
    response = await fetch(path, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
      cache: 'no-store',
    });
  } catch (error) {
    throw new ApiError(error.name === 'AbortError' ? '请求超时或已取消' : `网络请求失败: ${error.message}`);
  } finally {
    if (timer) clearTimeout(timer);
  }

  const text = await response.text();
  let payload = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = null;
    }
  }

  if (!response.ok) {
    const detail = payload && typeof payload.error === 'string' ? `: ${payload.error}` : '';
    const hint = response.status === 401 ? '（API 密钥缺失或失效）' : '';
    throw new ApiError(`HTTP ${response.status}${detail}${hint}`, response.status, payload);
  }

  return payload;
}

export const api = {
  get: (path, options) => request('GET', path, options),
  post: (path, body, options) => request('POST', path, { ...options, body: body ?? {} }),
  put: (path, body, options) => request('PUT', path, { ...options, body: body ?? {} }),
  patch: (path, body, options) => request('PATCH', path, { ...options, body: body ?? {} }),
  del: (path, options) => request('DELETE', path, options),
};
