// shared.js —— AI 各子视图共用的小零件（缩略图、短 ID、数字输入）。

import { el } from '../../dom.js';
import { thumbUrl } from '../../api.js';

/** 缩略图块：加载失败退化为占位块；extra 为缩略图下方的操作按钮。 */
export function mediaThumb(mediaId, caption, extra = []) {
  const img = el('img', { src: thumbUrl(mediaId), loading: 'lazy', alt: caption || mediaId });
  img.addEventListener('error', () => {
    img.replaceWith(el('div', { class: 'thumb-fallback', text: '无缩略图' }));
  });
  return el('div', { class: 'thumb' }, [
    img,
    el('div', { class: 'thumb-meta', text: caption || mediaId }),
    extra.length ? el('div', { class: 'thumb-actions' }, extra) : null,
  ]);
}

export function shortId(id) {
  const value = String(id || '');
  return value.length > 8 ? value.slice(0, 8) : value;
}

export function numberInput(value, opts = {}) {
  const { min = null, max = null, className = 'w-90' } = opts;
  return el('input', {
    type: 'number',
    class: className,
    value: String(value ?? ''),
    min: min === null ? null : String(min),
    max: max === null ? null : String(max),
  });
}
