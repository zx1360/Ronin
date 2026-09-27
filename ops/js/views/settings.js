// settings.js —— 设置：完全由后端 schema 驱动的通用表单。
//
// 页面不硬编码任何配置键、标签、候选项、最小/最大值：控件类型取 spec.kind，
// 取值范围取 spec.min/max，候选项取 spec.options，分组取 spec.section。
// 只提交被修改过的键（PUT /API/settings 的 patch 语义），并如实回报 changed 与失败。

import { getSettings, putSettings, opsListDirs } from '../api.js';
import {
  el, mount, btn, dirPicker, errorBox, badge, toast, toastError, } from '../dom.js';
import { collapsibleCard } from '../prefs.js';

export const title = '设置';

/** 分组标题只是外壳文案；真正的分组键来自 schema.section。 */
const SECTION_LABELS = {
  app: '应用',
  comix: '漫画采集',
  ai: 'AI 处理层',
};

function sectionLabel(section) {
  return SECTION_LABELS[section] || section || '其他';
}

function csvToList(raw) {
  return String(raw || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export async function render(root) {
  let schema = [];
  let values = {};
  let dirty = new Map();
  let error = null;
  let lastChanged = [];

  const fieldRefs = new Map();
  const toolbar = el('div', { class: 'toolbar' });
  const formHost = el('div', { class: 'view-body' });
  const footer = el('div', { class: 'view-body' });
  mount(root, toolbar, formHost, footer);

  const saveBtn = btn('保存修改', () => { void save(); }, { kind: 'primary' });
  const discardBtn = btn('放弃修改', () => {
    dirty = new Map();
    renderForm();
    renderFooter();
  }, { kind: 'ghost' });
  const reloadBtn = btn('重新载入', () => { void load(); });
  const dirtyText = el('span', { class: 'muted' });

  mount(toolbar,
    saveBtn,
    discardBtn,
    reloadBtn,
    dirtyText,
    el('div', { class: 'spacer' }),
    el('span', { class: 'hint', text: '表单由 GET /API/settings 的 schema 生成；只提交被修改的项。' }));

  function currentValue(key) {
    return dirty.has(key) ? dirty.get(key) : String(values[key] ?? '');
  }

  function setValue(key, value) {
    const original = String(values[key] ?? '');
    if (String(value) === original) dirty.delete(key);
    else dirty.set(key, String(value));
    refreshField(key);
    renderFooter();
  }

  function dirtyBadges(spec) {
    return [
      spec.restart ? badge('需重启', 'warn') : null,
      dirty.has(spec.key) ? badge('已修改', 'info') : null,
    ];
  }

  function refreshField(key) {
    const ref = fieldRefs.get(key);
    if (!ref || !ref.row) return;
    const isDirty = dirty.has(key);
    ref.row.classList.toggle('dirty', isDirty);
    mount(ref.badges, dirtyBadges(ref.spec));
    if (ref.boolLabel) {
      ref.boolLabel.textContent = currentValue(key) === 'true' ? '已启用' : '已关闭';
    }
  }

  function controlFor(spec) {
    const value = currentValue(spec.key);
    switch (spec.kind) {
      case 'bool': {
        const box = el('input', {
          type: 'checkbox',
          checked: value === 'true',
          onchange: (event) => setValue(spec.key, event.target.checked ? 'true' : 'false'),
        });
        const label = el('span', { text: value === 'true' ? '已启用' : '已关闭' });
        const ref = fieldRefs.get(spec.key);
        if (ref) ref.boolLabel = label;
        return el('label', { class: 'inline' }, [box, label]);
      }
      case 'int':
        return el('input', {
          type: 'number',
          class: 'w-140',
          value,
          min: spec.min ? String(spec.min) : null,
          max: spec.max ? String(spec.max) : null,
          onchange: (event) => setValue(spec.key, event.target.value),
        });
      case 'select':
        return el('select', {
          class: 'w-220',
          value,
          onchange: (event) => setValue(spec.key, event.target.value),
        }, (spec.options || []).map((option) => el('option', {
          value: option.value,
          text: option.label || option.value,
        })));
      case 'multi':
        return el('div', { class: 'row' }, (spec.options || []).map((option) => {
          const box = el('input', { type: 'checkbox', checked: csvToList(value).includes(option.value) });
          box.addEventListener('change', () => {
            const next = new Set(csvToList(currentValue(spec.key)));
            if (box.checked) next.add(option.value);
            else next.delete(option.value);
            setValue(spec.key, [...next].join(','));
          });
          return el('label', { class: 'inline' }, [box, el('span', { text: option.label || option.value })]);
        }));
      case 'path': {
        const input = el('input', {
          type: 'text',
          class: 'w-full',
          value,
          placeholder: spec.default || '',
          onchange: (event) => setValue(spec.key, event.target.value),
        });
        const browse = btn('浏览', () => {
          dirPicker(opsListDirs, input.value || spec.default || '', (picked) => {
            input.value = picked;
            setValue(spec.key, picked);
          });
        }, { size: 'sm' });
        return el('div', { class: 'row w-full' }, [input, browse]);
      }
      case 'secret':
      case 'string':
      default:
        return el('input', {
          type: spec.kind === 'secret' ? 'password' : 'text',
          class: 'w-full',
          value,
          placeholder: spec.default || '',
          onchange: (event) => setValue(spec.key, event.target.value),
        });
    }
  }

  function fieldRow(spec) {
    const badges = el('span', { class: 'row' }, dirtyBadges(spec));
    // 先登记引用，再构造控件：bool 控件要把动态文案挂回这里（控件工厂需要能查到 ref）。
    const ref = { row: null, badges, spec, boolLabel: null };
    fieldRefs.set(spec.key, ref);
    ref.row = el('div', { class: `field${dirty.has(spec.key) ? ' dirty' : ''}` }, [
      el('div', { class: 'field-head' }, [
        el('span', { class: 'field-label', text: spec.label || spec.key }),
        badges,
        el('span', { class: 'spacer' }),
        el('span', { class: 'hint mono', text: spec.key }),
      ]),
      el('div', { class: 'field-control' }, controlFor(spec)),
      spec.help ? el('div', { class: 'hint', text: spec.help }) : null,
      spec.default ? el('div', { class: 'hint', text: `默认值：${spec.default}` }) : null,
    ]);
    return ref.row;
  }

  function renderForm() {
    fieldRefs.clear();
    if (error) {
      mount(formHost, errorBox(`读取配置失败：${error.message || error}`, () => { void load(); }));
      return;
    }
    if (schema.length === 0) {
      mount(formHost, emptyBox('正在读取配置 schema…'));
      return;
    }
    const sections = new Map();
    for (const spec of schema) {
      const key = spec.section || '其他';
      if (!sections.has(key)) sections.set(key, []);
      sections.get(key).push(spec);
    }
    const cards = [];
    for (const [section, specs] of sections) {
      cards.push(collapsibleCard(`settings.${section}`, sectionLabel(section), specs.map(fieldRow), {
        subtitle: `${specs.length} 项`,
      }));
    }
    mount(formHost, cards);
    // 控件里对 fieldRefs 的补充引用（如 bool 的动态文案）依赖行已建立，故此处再刷新一次
    for (const spec of schema) refreshField(spec.key);
  }

  function renderFooter() {
    saveBtn.disabled = dirty.size === 0;
    discardBtn.disabled = dirty.size === 0;
    dirtyText.textContent = dirty.size ? `待保存 ${dirty.size} 项` : '没有未保存的修改';
    const body = [];
    if (lastChanged.length) {
      body.push(el('div', { class: 'alert alert-ok' }, [
        el('span', { class: 'alert-text', text: `已保存并生效的配置项：${lastChanged.join('、')}` }),
      ]));
    }
    mount(footer, body);
  }

  async function save() {
    if (dirty.size === 0) return;
    const patch = Object.fromEntries(dirty);
    saveBtn.disabled = true;
    saveBtn.textContent = '保存中…';
    try {
      const result = await putSettings(patch);
      values = (result && result.values) || values;
      lastChanged = (result && result.changed) || Object.keys(patch);
      const applied = new Set(lastChanged);
      for (const key of Object.keys(patch)) {
        if (applied.has(key)) dirty.delete(key);
      }
      const ignored = Object.keys(patch).filter((key) => !applied.has(key));
      if (ignored.length) lastChanged.push(`（服务端未接受：${ignored.join('、')}）`);
      toast(ignored.length
        ? `已保存 ${lastChanged.length} 项，${ignored.length} 项未被接受`
        : `已保存 ${lastChanged.length} 项配置`, ignored.length ? 'error' : 'ok');
    } catch (err) {
      lastChanged = [];
      toastError(err);
      saveBtn.textContent = '保存修改';
      renderForm();
      renderFooter();
      mount(footer, errorBox(`保存失败：${err.message || err}（修改仍保留在表单里，可修正后重试）`));
      return;
    }
    saveBtn.textContent = '保存修改';
    renderForm();
    renderFooter();
  }

  async function load() {
    try {
      const data = await getSettings();
      values = (data && data.values) || {};
      schema = (data && data.schema) || [];
      error = null;
      dirty = new Map();
      lastChanged = [];
    } catch (err) {
      error = err;
    }
    renderForm();
    renderFooter();
  }

  await load();

  return () => {};
}
