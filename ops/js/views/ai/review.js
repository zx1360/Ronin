// review.js —— 近期回顾：预设（增删改）与按天数/预设生成回顾。

import {
  aiReviewPresets, aiUpsertReviewPreset, aiDeleteReviewPreset, aiGenerateReview,
} from '../../api.js';
import {
  el, mount, card, tableEl, tr, badge, btn, errorBox, alertBox, emptyBox,
  fmtNum, toast, toastError, text,
} from '../../dom.js';
import { numberInput } from './shared.js';

export async function render(host) {
  let presets = [];
  let error = null;
  let draft = null;
  let result = null;
  let runError = null;
  let busy = false;

  const presetHost = el('div', { class: 'view-body' });
  const runHost = el('div', { class: 'view-body' });
  mount(host, presetHost, runHost);

  const daysInput = numberInput(30, { min: 1, max: 365 });
  const forceBox = el('input', { type: 'checkbox' });
  const presetSelect = el('select', { class: 'w-220' });

  function presetRows() {
    const list = draft ? [...presets, draft] : presets;
    return list.map((preset) => {
      const isDraft = Boolean(draft) && preset === draft;
      const nameInput = el('input', { type: 'text', class: 'w-140', value: preset.name || '', placeholder: '预设名称' });
      const toneInput = el('input', { type: 'text', class: 'w-full', value: preset.tone || '', placeholder: '语气，例如：平实、克制' });
      const roleInput = el('input', { type: 'text', class: 'w-full', value: preset.role || '', placeholder: '角色，例如：熟悉我日常的记录者' });
      const defaultBox = el('input', { type: 'radio', name: 'review-default', checked: Boolean(preset.is_default) });
      defaultBox.addEventListener('change', () => { preset.is_default = true; });
      return tr([
        nameInput,
        toneInput,
        roleInput,
        el('span', { class: 'ta-center' }, defaultBox),
        preset.is_default ? badge('默认', 'ok') : (isDraft ? badge('新预设', 'info') : null),
        el('div', { class: 'row' }, [
          btn('保存', () => { void savePreset(preset, { nameInput, toneInput, roleInput, defaultBox }); }, { size: 'sm', kind: 'primary' }),
          preset.is_default
            ? btn('删除', null, { size: 'sm', kind: 'danger', disabled: true, title: '默认预设不可删除' })
            : btn('删除', () => { void removePreset(preset); }, { size: 'sm', kind: 'danger' }),
        ]),
      ]);
    });
  }

  function renderPresets() {
    const body = [];
    if (error) {
      body.push(errorBox(`读取回顾预设失败：${error.message || error}`, () => { void load(); }));
    }
    body.push(tableEl(['名称', '语气', '角色', { title: '默认', class: 'ta-center' }, '', '操作'], presetRows()));
    body.push(el('div', { class: 'row' }, [
      btn('新建预设', () => {
        draft = { id: '', name: '', tone: '', role: '', is_default: presets.length === 0 };
        renderPresets();
      }),
      el('span', { class: 'hint', text: '语气与角色会作为提示词的一部分；默认预设用于未指定 preset_id 的生成。' }),
    ]));
    mount(presetHost, card('回顾预设（可编辑）', body));
  }

  function renderRun() {
    const previous = presetSelect.value;
    mount(presetSelect, presets.map((preset) => el('option', {
      value: preset.id,
      text: `${preset.name}${preset.is_default ? '（默认）' : ''}`,
    })));
    if (previous && presets.some((preset) => preset.id === previous)) presetSelect.value = previous;
    const body = [
      el('div', { class: 'row' }, [
        el('label', { class: 'inline' }, [el('span', { text: '回溯天数' }), daysInput]),
        el('label', { class: 'inline' }, [el('span', { text: '预设' }), presetSelect]),
        el('label', { class: 'inline' }, [forceBox, el('span', { text: '强制重新生成（忽略缓存）' })]),
        btn(busy ? '生成中…' : '生成回顾', () => { void generate(); }, { kind: 'primary', disabled: busy }),
      ]),
    ];
    if (runError) body.push(errorBox(`生成失败：${runError.message || runError}`, () => { void generate(); }));
    if (result) {
      if (result.notice) body.push(alertBox(result.notice, 'warn'));
      body.push(el('div', { class: 'row' }, [
        badge(`预设：${text(result.preset_name)}`, 'info'),
        result.model ? badge(`模型：${result.model}`, '') : badge('未使用模型', 'warn'),
        result.cached ? badge('命中缓存', '') : badge('新生成', 'ok'),
        el('span', { class: 'hint', text: text(result.created_at) }),
      ]));
      body.push(el('div', { class: 'card' }, [
        el('div', { class: 'card-body' }, el('pre', { class: 'logs', text: result.narrative || '（模型没有返回叙述，以下为确定性统计）' })),
      ]));
      const facts = (result.stats && result.stats.facts) || [];
      body.push(el('div', { class: 'col' }, [
        el('div', { class: 'hint', text: '确定性统计（由后端计算，与模型无关）' }),
        facts.length
          ? el('ul', { class: 'facts' }, facts.map((fact) => el('li', { text: fact })))
          : emptyBox('统计为空'),
        el('div', { class: 'hint', text: `区间：${text(result.stats && result.stats.from)} ~ ${text(result.stats && result.stats.to)}（${fmtNum(result.stats && result.stats.days)} 天）` }),
      ]));
    } else {
      body.push(emptyBox('尚未生成回顾'));
    }
    mount(runHost, card('生成近期回顾', body));
  }

  async function savePreset(preset, fields) {
    const payload = {
      id: preset.id || '',
      name: fields.nameInput.value.trim(),
      tone: fields.toneInput.value.trim(),
      role: fields.roleInput.value.trim(),
      is_default: Boolean(fields.defaultBox.checked),
    };
    if (!payload.name) {
      toast('预设名称不能为空', 'error');
      return;
    }
    try {
      const data = await aiUpsertReviewPreset(payload);
      presets = (data && data.presets) || presets;
      draft = null;
      toast('预设已保存', 'ok');
      renderPresets();
      renderRun();
    } catch (err) {
      toastError(err);
    }
  }

  async function removePreset(preset) {
    if (!window.confirm(`删除预设「${preset.name}」？`)) return;
    try {
      const data = await aiDeleteReviewPreset(preset.id);
      presets = (data && data.presets) || presets;
      draft = null;
      toast('预设已删除', 'ok');
      renderPresets();
      renderRun();
    } catch (err) {
      toastError(err);
    }
  }

  async function generate() {
    busy = true;
    renderRun();
    try {
      result = await aiGenerateReview({
        days: Number(daysInput.value) || 30,
        preset_id: presetSelect.value || '',
        force: forceBox.checked,
      });
      runError = null;
    } catch (err) {
      runError = err;
      result = null;
    } finally {
      busy = false;
    }
    renderRun();
  }

  async function load() {
    try {
      const data = await aiReviewPresets();
      presets = (data && data.presets) || [];
      error = null;
    } catch (err) {
      error = err;
    }
    renderPresets();
    renderRun();
  }

  await load();
}
