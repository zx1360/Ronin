// search.js —— 检索：语义 / 关键词 / 文件名查询与结果缩略图。

import { aiSearch, aiPersons } from '../../api.js';
import {
  el, mount, card, badge, btn, alertBox, errorBox, emptyBox, fmtNum, text,
} from '../../dom.js';
import { mediaThumb, numberInput } from './shared.js';

/** /API/ai/search 支持的检索模式（与 handler 的 mode 取值一致）。 */
const SEARCH_MODES = [
  { value: 'auto', label: '智能（语义 + 关键词加权）' },
  { value: 'semantic', label: '语义' },
  { value: 'keyword', label: '关键词（OCR/描述/AI 标签）' },
  { value: 'filename', label: '文件名' },
];

export async function render(host) {
  let persons = [];
  let personsError = null;
  let result = null;
  let error = null;
  let searched = false;
  let busy = false;

  const fields = {
    q: el('input', { type: 'search', class: 'w-220', placeholder: '自然语言或关键词' }),
    mode: el('select', { class: 'w-220' }, SEARCH_MODES.map((mode) => el('option', { value: mode.value, text: mode.label }))),
    mime: el('select', { class: 'w-140' }, [
      el('option', { value: '', text: '全部类型' }),
      el('option', { value: 'image', text: '仅图片' }),
      el('option', { value: 'video', text: '仅视频' }),
    ]),
    person: el('select', { class: 'w-220' }, [el('option', { value: '', text: '全部人物' })]),
    minScore: numberInput('', { min: 0, max: 1 }),
    limit: numberInput(60, { min: 1, max: 200 }),
  };

  const toolbar = el('div', { class: 'toolbar' }, [
    el('label', { class: 'inline' }, [el('span', { text: '检索' }), fields.q]),
    el('label', { class: 'inline' }, [el('span', { text: '模式' }), fields.mode]),
    el('label', { class: 'inline' }, [el('span', { text: '类型' }), fields.mime]),
    el('label', { class: 'inline' }, [el('span', { text: '人物' }), fields.person]),
    el('label', { class: 'inline' }, [el('span', { text: '最小相似度' }), fields.minScore]),
    el('label', { class: 'inline' }, [el('span', { text: '数量' }), fields.limit]),
    btn('搜索', () => { void search(); }, { kind: 'primary' }),
    el('div', { class: 'spacer' }),
    el('span', { class: 'hint', text: '缩略图直接取自 /API/gallery/<id>/thumb' }),
  ]);
  const resultHost = el('div', { class: 'view-body' });
  mount(host, toolbar, resultHost);

  fields.q.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') void search();
  });

  function draw() {
    const body = [];
    if (personsError) {
      body.push(alertBox(`人物清单不可用：${personsError.message || personsError}`, 'warn'));
    }
    if (error) {
      body.push(errorBox(`检索失败：${error.message || error}`, () => { void search(); }));
    } else if (!searched) {
      body.push(emptyBox('输入关键词后开始检索；语义模式需要先完成向量处理与索引载入。'));
    } else if (result && (result.hits || []).length === 0) {
      body.push(emptyBox(`没有命中（实际使用模式：${text(result.mode)}）`));
    } else if (result) {
      const hits = result.hits || [];
      body.push(el('div', { class: 'hint', text: `命中 ${fmtNum(result.total)} 条，实际使用模式：${text(result.mode)}` }));
      body.push(el('div', { class: 'thumbs' }, hits.map((hit) => mediaThumb(
        hit.id,
        hit.file_path,
        [
          hit.score ? badge(`相似度 ${Number(hit.score).toFixed(3)}`, 'info') : null,
          ...(hit.source || []).map((source) => badge(source, '')),
        ].filter(Boolean),
      ))));
    }
    mount(resultHost, card('检索结果', body));
  }

  async function search() {
    const mode = fields.mode.value;
    const q = fields.q.value.trim();
    const query = { mode, limit: Number(fields.limit.value) || 60 };
    if (q) query.q = q;
    if (fields.mime.value) query.mime_type = fields.mime.value;
    if (fields.person.value) query.person_ids = fields.person.value;
    const minScore = fields.minScore.value.trim();
    if (minScore !== '') query.min_score = minScore;
    busy = true;
    try {
      result = await aiSearch(query);
      error = null;
      searched = true;
    } catch (err) {
      error = err;
      result = null;
      searched = true;
    } finally {
      busy = false;
    }
    draw();
  }

  async function loadPersons() {
    try {
      const data = await aiPersons();
      persons = (data && data.persons) || [];
      personsError = null;
      mount(fields.person,
        [el('option', { value: '', text: '全部人物' })].concat(persons.map((person) => el('option', {
          value: person.id,
          text: `${person.name || '未命名'}（${person.face_count}）`,
        }))));
      fields.person.value = '';
    } catch (err) {
      personsError = err;
    }
    draw();
  }

  draw();
  await loadPersons();
}
