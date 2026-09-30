// caps.js —— 能力 / 概览：能力清单、就绪原因与执行者切换。

import { aiCapabilities, putSettings } from '../../api.js';
import {
  el, mount, card, badge, errorBox, alertBox, emptyBox, toast, toastError, text,
} from '../../dom.js';

export async function render(host) {
  let data = null;
  let error = null;

  function draw() {
    if (error) {
      mount(host, errorBox(`读取能力清单失败：${error.message || error}`, () => { void load(); }));
      return;
    }
    if (!data) {
      mount(host, emptyBox('正在读取 AI 能力…'));
      return;
    }
    const cards = [];
    if (data.enabled === false) {
      cards.push(alertBox('AI 处理层未启用（ai.enabled=false）：以下能力均不可用，可在「设置」里开启。', 'warn'));
    }
    for (const info of data.capabilities || []) {
      cards.push(capabilityCard(info));
    }
    if (cards.length === 0) cards.push(emptyBox('服务端未下发任何能力'));
    mount(host, cards);
  }

  function capabilityCard(info) {
    // 配置键由后端下发：可切换执行者的能力才带 setting_key。
    const settingKey = info.setting_key || '';
    const candidates = info.candidates || [];
    const body = [];
    body.push(el('div', { class: 'row' }, [
      el('span', { class: 'hint', text: '输入档位' }),
      badge(info.input_tier || '未知', 'info'),
      el('span', { class: 'hint', text: '当前执行者' }),
      el('span', { class: 'mono', text: text(info.selected) }),
      info.ready ? badge('就绪', 'ok') : badge('未就绪', 'err'),
    ]));
    if (!info.ready && info.reason) body.push(alertBox(info.reason, 'error'));
    if (candidates.length > 1 && settingKey) {
      const select = el('select', {
        class: 'w-220',
        value: info.selected,
        disabled: data.enabled === false,
        onchange: (event) => { void switchExecutor(info, event.target.value, select); },
      }, candidates.map((candidate) => el('option', {
        value: candidate.id,
        text: candidate.note ? `${candidate.label} · ${candidate.note}` : candidate.label,
      })));
      body.push(el('div', { class: 'row' }, [el('span', { class: 'hint', text: '切换候选' }), select]));
    } else if (candidates.length > 1) {
      body.push(alertBox(`该能力有多个候选，但页面没有对应的配置键，请在设置中手动指定：${candidates.map((c) => c.id).join('、')}`, 'warn'));
    } else if (candidates.length === 1) {
      body.push(el('div', { class: 'row' }, [
        el('span', { class: 'hint', text: '唯一实现' }),
        el('span', { class: 'mono muted', text: candidates[0].label || candidates[0].id }),
        candidates[0].note ? el('span', { class: 'hint', text: candidates[0].note }) : null,
      ]));
    }
    return card(`${info.label || info.capability}`, body, { subtitle: info.capability });
  }

  async function switchExecutor(info, value, select) {
    const key = info.setting_key || '';
    if (!key) return;
    select.disabled = true;
    try {
      const result = await putSettings({ [key]: value });
      const changed = (result && result.changed) || [];
      if (!changed.includes(key)) {
        throw new Error(`服务端未接受 ${key} 的修改`);
      }
      toast(`已把「${info.label || info.capability}」切换为 ${value}`, 'ok');
      await load();
    } catch (err) {
      toastError(err);
      select.disabled = false;
      select.value = info.selected;
    }
  }

  async function load() {
    try {
      data = await aiCapabilities();
      error = null;
    } catch (err) {
      error = err;
    }
    draw();
  }

  await load();
}
