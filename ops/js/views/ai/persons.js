// persons.js —— 人物：分组列表、改名、删除与合并、重新聚类。

import {
  aiPersons, aiPersonRename, aiPersonDelete, aiPersonsMerge, aiRecluster,
} from '../../api.js';
import {
  el, mount, card, tableEl, tr, btn, errorBox, emptyBox, fmtNum, toast, toastError,
} from '../../dom.js';
import { mediaThumb, shortId } from './shared.js';

export async function render(host) {
  let persons = [];
  let error = null;
  let busy = false;
  const picked = new Set();

  const toolbar = el('div', { class: 'toolbar' });
  const listHost = el('div', { class: 'view-body' });
  mount(host, toolbar, listHost);

  const mergeTarget = el('select', { class: 'w-220' });

  function renderToolbar() {
    mount(mergeTarget, [el('option', { value: '', text: '合并到…' })].concat(persons.map((person) => el('option', {
      value: person.id,
      text: `${person.name || '未命名'}（${person.face_count}）`,
    }))));
    mount(toolbar,
      btn('刷新', () => { void load(); }),
      el('span', { class: 'hint', text: `已选 ${picked.size} 组` }),
      mergeTarget,
      btn('合并所选', () => { void merge(); }),
      el('div', { class: 'spacer' }),
      btn('增量重新聚类', () => { void recluster(false); }),
      btn('重置并重新聚类', () => { void recluster(true); }, { kind: 'danger' }));
  }

  function draw() {
    renderToolbar();
    if (error) {
      mount(listHost, errorBox(`读取人物失败：${error.message || error}`, () => { void load(); }));
      return;
    }
    if (persons.length === 0) {
      mount(listHost, card('人物', [emptyBox('还没有人物分组（先完成人脸检测与聚类）')]));
      return;
    }
    const rows = persons.map((person) => {
      const box = el('input', { type: 'checkbox', checked: picked.has(person.id) });
      box.addEventListener('change', () => {
        if (box.checked) picked.add(person.id);
        else picked.delete(person.id);
        renderToolbar();
      });
      const nameInput = el('input', { type: 'text', class: 'w-140', value: person.name || '', placeholder: '未命名' });
      return tr([
        el('span', { class: 'ta-center' }, box),
        person.cover_media_id
          ? mediaThumb(person.cover_media_id, '')
          : el('span', { class: 'hint', text: '无封面' }),
        nameInput,
        el('span', { class: 'num', text: fmtNum(person.face_count) }),
        el('span', { class: 'mono muted', title: person.id, text: shortId(person.id) }),
        el('div', { class: 'row' }, [
          btn('保存名称', () => { void rename(person, nameInput.value); }, { size: 'sm' }),
          btn('删除分组', () => { void removePerson(person); }, { size: 'sm', kind: 'danger' }),
        ]),
      ]);
    });
    mount(listHost, card('人物分组', tableEl([
      { title: '', class: 'ta-center' }, '封面', '名称', { title: '人脸数', class: 'ta-right' }, 'ID', '操作',
    ], rows), {
      subtitle: `${persons.length} 组`,
      actions: el('span', { class: 'hint', text: '删除分组只解绑人脸，不删除媒体' }),
    }));
  }

  async function load() {
    try {
      const data = await aiPersons();
      persons = (data && data.persons) || [];
      error = null;
    } catch (err) {
      error = err;
    }
    for (const id of [...picked]) {
      if (!persons.some((person) => person.id === id)) picked.delete(id);
    }
    draw();
  }

  async function rename(person, value) {
    try {
      await aiPersonRename(person.id, value.trim());
      toast(`已更新「${value.trim() || '未命名'}」`, 'ok');
      await load();
    } catch (err) {
      toastError(err);
    }
  }

  async function removePerson(person) {
    if (!window.confirm(`删除人物分组「${person.name || '未命名'}」？人脸会回到未分配状态，媒体不受影响。`)) return;
    try {
      await aiPersonDelete(person.id);
      toast('已删除分组', 'ok');
      await load();
    } catch (err) {
      toastError(err);
    }
  }

  async function merge() {
    const target = mergeTarget.value;
    if (!target) {
      toast('请选择合并目标', 'error');
      return;
    }
    const sources = [...picked].filter((id) => id !== target);
    if (sources.length === 0) {
      toast('请至少勾选一个要合并的分组（不能只有目标）', 'error');
      return;
    }
    if (!window.confirm(`把 ${sources.length} 个分组合并到目标分组？`)) return;
    busy = true;
    try {
      const data = await aiPersonsMerge(sources, target);
      toast(`已迁移 ${fmtNum(data && data.moved_faces)} 张人脸`, 'ok');
      picked.clear();
      await load();
    } catch (err) {
      toastError(err);
    } finally {
      busy = false;
    }
  }

  async function recluster(reset) {
    if (reset && !window.confirm('重置会清空现有人物分组与人工命名，然后重新聚类。继续？')) return;
    busy = true;
    try {
      const data = await aiRecluster(reset);
      toast(`聚类完成：新增/调整 ${fmtNum(data && data.assigned)} 张，待定 ${fmtNum(data && data.pending)} 张`, 'ok');
      await load();
    } catch (err) {
      toastError(err);
    } finally {
      busy = false;
    }
  }

  await load();
}
