// auto.js —— 自动处理：入库后自动入队的能力开关。

import { aiCapabilities, getSettings, putSettings } from '../../api.js';
import {
  el, mount, card, errorBox, alertBox, emptyBox, toast, toastError,
} from '../../dom.js';

/** 自动入队开关的配置键（候选来自 schema，不在这里写候选）。 */
const AUTO_CAPS_KEY = 'ai.auto_capabilities';

export async function render(host) {
  let caps = null;
  let schema = [];
  let error = null;
  let busy = false;

  function autoSpec() {
    return schema.find((spec) => spec.key === AUTO_CAPS_KEY) || null;
  }

  function options() {
    const spec = autoSpec();
    if (spec && spec.options && spec.options.length) return spec.options;
    return (caps && caps.capabilities ? caps.capabilities : []).map((info) => ({
      value: info.capability,
      label: info.label || info.capability,
    }));
  }

  function draw() {
    if (error) {
      mount(host, errorBox(`读取自动处理配置失败：${error.message || error}`, () => { void load(); }));
      return;
    }
    if (!caps) {
      mount(host, emptyBox('正在读取自动处理配置…'));
      return;
    }
    const selected = new Set(caps.auto || []);
    const spec = autoSpec();
    const list = options();
    const boxes = list.map((option) => {
      const box = el('input', {
        type: 'checkbox',
        checked: selected.has(option.value),
        dataset: { value: option.value },
      });
      box.addEventListener('change', () => { void apply(); });
      return el('label', { class: 'inline' }, [box, el('span', { text: option.label || option.value })]);
    });
    const disabled = caps.enabled === false || busy;
    for (const label of boxes) {
      const box = label.querySelector('input');
      if (box) box.disabled = disabled;
    }

    const body = [
      el('div', { class: 'row' }, boxes),
      el('div', { class: 'hint', text: spec && spec.help ? spec.help : '入库后自动入队的能力；留空表示只能手动提交。' }),
      autoSpec() ? el('div', { class: 'hint mono', text: `配置键：${AUTO_CAPS_KEY}` }) : null,
    ];
    if (caps.enabled === false) {
      body.unshift(alertBox('AI 处理层未启用，自动入队不会生效。', 'warn'));
    }
    mount(host, card('入库后自动处理', body));
  }

  async function apply() {
    const values = [...host.querySelectorAll('input[type="checkbox"]')]
      .filter((box) => box.checked && box.dataset.value)
      .map((box) => box.dataset.value);
    busy = true;
    try {
      const result = await putSettings({ [AUTO_CAPS_KEY]: values.join(',') });
      const changed = (result && result.changed) || [];
      if (!changed.includes(AUTO_CAPS_KEY)) {
        throw new Error(`服务端未接受 ${AUTO_CAPS_KEY} 的修改`);
      }
      toast(`自动处理已更新为：${values.length ? values.join('、') : '关闭'}`, 'ok');
      await load();
    } catch (err) {
      toastError(err);
      await load();
    } finally {
      busy = false;
    }
  }

  async function load() {
    try {
      const [capsData, settings] = await Promise.all([aiCapabilities(), getSettings().catch(() => null)]);
      caps = capsData;
      schema = (settings && settings.schema) || [];
      error = null;
    } catch (err) {
      error = err;
    }
    draw();
  }

  await load();
}
