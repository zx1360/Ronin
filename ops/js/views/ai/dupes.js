// dupes.js —— 去重 / 已删除：近重复分组、已标记「非重复」与软删除清单。

import {
  aiDuplicates, aiIgnoreDuplicates, aiUnignoreDuplicates, aiIgnoredDuplicates,
  galleryMedia, galleryPatchMedia,
} from '../../api.js';
import {
  el, mount, card, tableEl, tr, badge, btn, errorBox, alertBox, emptyBox,
  fmtTime, fmtNum, fmtBytes, toast, toastError, text,
} from '../../dom.js';
import { mediaThumb, shortId } from './shared.js';

export async function render(host) {
  let groups = [];
  let ignored = [];
  let deleted = [];
  let error = null;
  let ignoredError = null;
  let deletedError = null;
  let maxDistance = 4;
  // 服务端可能返回数百个分组（每组几十张），一次性铺满 DOM 会让页面卡死：
  // 默认只渲染前 GROUP_PAGE 组，每组最多 MAX_THUMBS 张缩略图，其余按需展开。
  const GROUP_PAGE = 30;
  const MAX_THUMBS = 12;
  let visibleGroups = GROUP_PAGE;

  const toolbar = el('div', { class: 'toolbar' });
  const groupHost = el('div', { class: 'view-body' });
  const ignoredHost = el('div', { class: 'view-body' });
  const deletedHost = el('div', { class: 'view-body' });
  mount(host, toolbar, groupHost, ignoredHost, deletedHost);

  const distanceSelect = el('select', { class: 'w-140' }, [1, 2, 3, 4].map((value) => el('option', {
    value: String(value), text: `距离 ≤ ${value}`, selected: value === maxDistance,
  })));
  distanceSelect.addEventListener('change', () => {
    maxDistance = Number(distanceSelect.value) || 4;
    visibleGroups = GROUP_PAGE;
    void load();
  });

  function renderToolbar() {
    mount(toolbar,
      el('label', { class: 'inline' }, [el('span', { text: '近重复阈值' }), distanceSelect]),
      btn('刷新', () => { void load(); }),
      el('span', { class: 'hint', text: `已标记「非重复」${fmtNum(ignored.length)} 张` }),
      el('div', { class: 'spacer' }));
  }

  function renderGroups() {
    renderToolbar();
    if (error) {
      mount(groupHost, errorBox(`读取近重复分组失败：${error.message || error}`, () => { void load(); }));
      return;
    }
    if (groups.length === 0) {
      mount(groupHost, card('近重复分组', [emptyBox('没有发现近重复（或 pHash 尚未处理完）')]));
      return;
    }
    const shown = groups.slice(0, visibleGroups);
    const cards = shown.map((group, index) => {
      const ids = group.media_ids || [];
      const files = group.files || [];
      const visible = ids.slice(0, MAX_THUMBS);
      const thumbs = visible.map((id, position) => mediaThumb(id, files[position] || shortId(id), [
        btn('删除', () => { void softDelete([id]); }, { size: 'sm', kind: 'danger' }),
      ]));
      return card(`分组 ${index + 1}`, [
        el('div', { class: 'row' }, [
          badge(`距离 ${fmtNum(group.distance)}`, 'warn'),
          badge(`${ids.length} 张`, 'info'),
          el('div', { class: 'spacer' }),
          btn('整组标记为非重复', () => { void ignore(ids); }, { size: 'sm' }),
          btn('整组标记为已删除', () => { void softDelete(ids); }, { size: 'sm', kind: 'danger' }),
        ]),
        el('div', { class: 'thumbs' }, thumbs),
        ids.length > visible.length
          ? el('div', { class: 'hint', text: `仅展示前 ${visible.length} 张，另有 ${ids.length - visible.length} 张未展开（整组操作仍作用于全部 ${ids.length} 张）` })
          : null,
      ]);
    });
    mount(groupHost, card('近重复分组', [
      el('div', { class: 'view-body' }, cards),
      groups.length > shown.length
        ? el('div', { class: 'row' }, [
          btn(`显示更多（已展示 ${shown.length} / ${groups.length} 组）`, () => {
            visibleGroups += GROUP_PAGE;
            renderGroups();
          }, { size: 'sm' }),
        ])
        : null,
    ], {
      subtitle: `${groups.length} 组（max_distance=${maxDistance}）`,
    }));
  }

  function renderIgnored() {
    const body = [];
    if (ignoredError) {
      body.push(alertBox(`已忽略清单不可用：${ignoredError.message || ignoredError}`, 'warn'));
    }
    if (ignored.length === 0) {
      body.push(emptyBox('没有被标记为「非重复」的媒体'));
    } else {
      body.push(el('div', { class: 'thumbs' }, ignored.map((media) => mediaThumb(
        media.id,
        media.file_path,
        [
          btn('恢复', () => { void unignore([media.id]); }, { size: 'sm' }),
          btn('删除', () => { void softDelete([media.id]); }, { size: 'sm', kind: 'danger' }),
        ],
      ))));
    }
    mount(ignoredHost, card('已标记「非重复」', body));
  }

  function renderDeleted() {
    const body = [];
    if (deletedError) {
      body.push(alertBox(`已删除清单不可用：${deletedError.message || deletedError}`, 'warn'));
    }
    if (deleted.length === 0) {
      body.push(emptyBox('已软删除的媒体为空'));
    } else {
      body.push(tableEl(['缩略图', '文件', '大小', '修改时间', '操作'], deleted.map((media) => tr([
        mediaThumb(media.id, ''),
        el('span', { class: 'mono', text: text(media.file_path) }),
        el('span', { class: 'num', text: fmtBytes(media.size_bytes) }),
        el('span', { class: 'mono nowrap', text: fmtTime(media.updated_at) }),
        el('div', { class: 'row' }, [btn('恢复', () => { void restore([media.id]); }, { size: 'sm' })]),
      ]))));
    }
    mount(deletedHost, card('已删除（软删除）', body, { subtitle: `${deleted.length} 条` }));
  }

  async function load() {
    try {
      const data = await aiDuplicates({ max_distance: maxDistance, min_group: 2 });
      groups = (data && data.groups) || [];
      error = null;
    } catch (err) {
      error = err;
      groups = [];
    }
    try {
      const data = await aiIgnoredDuplicates();
      ignored = (data && data.media_assets) || [];
      ignoredError = null;
    } catch (err) {
      ignoredError = err;
      ignored = [];
    }
    try {
      const data = await galleryMedia({ only_deleted: 'true', limit: 100 });
      deleted = (data && data.media_assets) || [];
      deletedError = null;
    } catch (err) {
      deletedError = err;
      deleted = [];
    }
    renderGroups();
    renderIgnored();
    renderDeleted();
  }

  async function softDelete(mediaIds) {
    if (!window.confirm(`把选中的 ${mediaIds.length} 张标记为已删除？（可随时恢复）`)) return;
    try {
      await galleryPatchMedia({ media_ids: mediaIds, is_deleted: true });
      toast('已标记为已删除', 'ok');
      await load();
    } catch (err) {
      toastError(err);
    }
  }

  async function restore(mediaIds) {
    try {
      await galleryPatchMedia({ media_ids: mediaIds, is_deleted: false });
      toast('已恢复', 'ok');
      await load();
    } catch (err) {
      toastError(err);
    }
  }

  async function ignore(mediaIds) {
    try {
      const data = await aiIgnoreDuplicates(mediaIds);
      toast(`已标记为非重复（累计 ${fmtNum(data && data.total)} 张）`, 'ok');
      await load();
    } catch (err) {
      toastError(err);
    }
  }

  async function unignore(mediaIds) {
    try {
      const data = await aiUnignoreDuplicates(mediaIds);
      toast(`已恢复参与分组（累计 ${fmtNum(data && data.total)} 张）`, 'ok');
      await load();
    } catch (err) {
      toastError(err);
    }
  }

  await load();
}
