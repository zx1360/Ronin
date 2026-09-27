// gallery.js —— 媒体库：运行固定的 gallery CLI 任务并跟踪日志。
//
// 任务种类完全由后端下发（GET /API/ops/capabilities 的 gallery.modes）：
// 页面不提供"新增任务档案/自选可执行文件"的入口。

import { opsCapabilities, galleryRun, galleryTasks, galleryStop } from '../api.js';
import {
  el, mount, card, tableEl, tr, badge, btn, errorBox, alertBox, emptyBox,
  fmtTime, fmtDuration, toast, toastError,
} from '../dom.js';
import { createPoller } from '../poll.js';
import { collapsibleCard } from '../prefs.js';
import { statusBadge, autoscrollToggle, createLogPanels } from '../tasks.js';

export const title = '媒体库';

export async function render(root) {
  let caps = null;
  let capsError = null;
  let tasks = [];
  let tasksError = null;
  let submitting = false;

  const params = { mode: '', concurrency: 0, batch: 0, resize: 0, resizePreview: 0, resizeThumb: 0 };
  const paramInputs = new Map();
  let defaultsApplied = false;
  const expanded = new Set();
  const logPanels = createLogPanels();

  const formHost = el('div', { class: 'view-body' });
  const listHost = el('div', { class: 'view-body' });
  mount(root, formHost, listHost);

  // ---------- 任务列表 ----------

  const autoscrollBox = autoscrollToggle();

  const poller = createPoller(() => refreshTasks(), { interval: 2000 });

  function renderTasks() {
    const body = [];
    if (tasksError) {
      body.push(errorBox(`读取任务列表失败：${tasksError.message || tasksError}`, () => { void refreshTasks(); }));
    }
    if (tasks.length === 0) {
      body.push(emptyBox(tasksError ? '—' : '暂无任务'));
    } else {
      const rows = [];
      for (const task of tasks) {
        const isOpen = expanded.has(task.id);
        rows.push(tr([
          el('button', {
            class: 'icon-btn',
            title: isOpen ? '收起日志' : '展开日志',
            text: isOpen ? '▾' : '▸',
            onclick: () => {
              if (isOpen) expanded.delete(task.id);
              else expanded.add(task.id);
              renderTasks();
            },
          }),
          el('span', { class: 'mono', text: task.id }),
          badge(task.name || '—', 'info'),
          statusBadge(task.status),
          el('span', { class: 'mono nowrap', text: fmtTime(task.started_at) }),
          el('span', { class: 'nowrap', text: fmtDuration(task.started_at, task.finished_at) }),
          el('span', { class: 'mono muted', text: task.pid ? `PID ${task.pid}` : (task.exit_code === null || task.exit_code === undefined ? '—' : `退出码 ${task.exit_code}`) }),
          el('span', { class: 'row' }, [
            task.status === 'running'
              ? btn('中断', () => { void stopTask(task.id); }, { size: 'sm', kind: 'danger' })
              : null,
            task.error ? el('span', { class: 'err-text', text: task.error }) : null,
          ]),
        ]));
        if (isOpen) {
          const panel = logPanels.update(task.id, task.logs || []);
          rows.push(el('tr', null, el('td', { colspan: '8' }, [
            el('div', { class: 'hint mono', text: task.command || '' }),
            panel.node,
          ])));
        }
      }
      body.push(tableEl([
        '', '任务', '模式', '状态', '开始时间', '耗时', '进程',
        { title: '操作', class: 'ta-right' },
      ], rows));
    }
    mount(listHost, card('任务', body, {
      subtitle: `${tasks.length} 条（服务端保留最近 20 条已完成）`,
      actions: el('div', { class: 'row' }, [
        el('label', { class: 'inline' }, [autoscrollBox, el('span', { text: '日志自动滚动' })]),
        btn('刷新', () => { void refreshTasks(); }, { size: 'sm' }),
      ]),
    }));
  }

  async function refreshTasks() {
    try {
      const data = await galleryTasks();
      tasks = (data && data.tasks) || [];
      tasksError = null;
    } catch (err) {
      tasksError = err;
    }
    const running = tasks.some((task) => task.status === 'running');
    if (running) poller.start();
    else if (!poller.graceActive) poller.stop();
    logPanels.prune(tasks);
    renderTasks();
  }

  async function stopTask(taskId) {
    try {
      await galleryStop(taskId);
      toast(`已请求中断 ${taskId}`, 'ok');
      await refreshTasks();
    } catch (err) {
      toastError(err);
    }
  }

  // ---------- 运行表单 ----------

  function numberField(label, key, hint) {
    const input = el('input', {
      type: 'number', min: '0', class: 'w-90',
      value: String(params[key] || 0),
      onchange: (event) => {
        params[key] = readNumber(key, event.target.value);
        event.target.value = String(params[key]);
      },
    });
    paramInputs.set(key, input);
    return el('label', { class: 'inline', title: hint || '' }, [el('span', { text: label }), input]);
  }

  function readNumber(key, raw) {
    const text = raw === undefined ? (paramInputs.get(key) ? paramInputs.get(key).value.trim() : '') : String(raw).trim();
    const value = Number(text);
    return Number.isFinite(value) && value > 0 ? Math.round(value) : 0;
  }

  function renderForm() {
    if (capsError) {
      mount(formHost, errorBox(`读取运行能力失败：${capsError.message || capsError}`, () => { void loadCaps(); }));
      return;
    }
    if (!caps) {
      mount(formHost, emptyBox('正在读取可用模式…'));
      return;
    }
    const gallery = caps.gallery || {};
    const modes = gallery.modes || [];
    const defaults = gallery.defaults || {};
    // 只在首次渲染时填充后端下发的默认值；之后 0 就是用户自己的选择（= 用 CLI 默认）。
    if (!defaultsApplied) {
      params.concurrency = Number(defaults.concurrency) || 0;
      params.batch = Number(defaults.batch) || 0;
      defaultsApplied = true;
    }
    if (!params.mode || !modes.some((mode) => mode.value === params.mode)) {
      params.mode = modes.length ? modes[0].value : '';
    }
    const selected = modes.find((mode) => mode.value === params.mode);
    const available = Boolean(gallery.available);

    const modeSelect = el('select', {
      class: 'w-220',
      value: params.mode,
      disabled: modes.length === 0,
      onchange: (event) => {
        params.mode = event.target.value;
        renderForm();
      },
    }, modes.map((mode) => el('option', { value: mode.value, text: mode.label, title: mode.help || '' })));

    const controls = [
      el('label', { class: 'inline' }, [el('span', { text: '模式' }), modeSelect]),
      numberField('并发', 'concurrency', '并发处理的文件数'),
      numberField('批次', 'batch', '单批处理的文件数'),
    ];
    // resize 系列参数是否生效由后端随模式一并下发（modes[].resize）。
    const withResize = Boolean(selected && selected.resize);
    if (withResize) {
      controls.push(
        numberField('原图边长', 'resize', '0 = 不修改'),
        numberField('预览边长', 'resizePreview', '0 = 不修改'),
        numberField('缩略图边长', 'resizeThumb', '0 = 不修改'),
      );
    }
    controls.push(btn(submitting ? '提交中…' : '运行任务', () => { void submit(); }, {
      kind: 'primary',
      disabled: !available || submitting || !params.mode,
      title: available ? '' : (gallery.reason || 'gallery CLI 不可用'),
    }));

    const body = [
      el('div', { class: 'row' }, controls),
      selected && selected.help ? el('div', { class: 'hint', text: selected.help }) : null,
      withResize ? el('div', { class: 'hint', text: '留 0 表示不修改对应尺寸。' }) : null,
      gallery.cli ? el('div', { class: 'hint mono', text: `CLI：${gallery.cli}` }) : null,
    ];
    if (!available) {
      body.unshift(alertBox(`gallery CLI 不可用：${gallery.reason || '未知原因'}（可运行任务已被禁用）`, 'error'));
    }
    mount(formHost, collapsibleCard('gallery.run', '运行 gallery CLI', body));
  }

  async function submit() {
    if (!params.mode) return;
    // 直接读输入框当前值：用户改完没失焦就点运行也不会漏掉修改。
    const body = { mode: params.mode };
    const concurrency = readNumber('concurrency');
    const batch = readNumber('batch');
    if (concurrency > 0) body.concurrency = concurrency;
    if (batch > 0) body.batch = batch;
    const mode = ((caps && caps.gallery && caps.gallery.modes) || []).find((item) => item.value === params.mode);
    if (mode && mode.resize) {
      const resize = readNumber('resize');
      const resizePreview = readNumber('resizePreview');
      const resizeThumb = readNumber('resizeThumb');
      if (resize > 0) body.resize = resize;
      if (resizePreview > 0) body.resize_preview = resizePreview;
      if (resizeThumb > 0) body.resize_thumb = resizeThumb;
    }
    submitting = true;
    renderForm();
    try {
      await galleryRun(body);
      toast('任务已提交', 'ok');
      poller.kick(15);
      await refreshTasks();
    } catch (err) {
      toastError(err);
    } finally {
      submitting = false;
      renderForm();
    }
  }

  async function loadCaps() {
    try {
      caps = await opsCapabilities();
      capsError = null;
    } catch (err) {
      capsError = err;
    }
    renderForm();
  }

  await loadCaps();
  renderTasks();
  await refreshTasks();

  return () => {
    poller.dispose();
    logPanels.clear();
  };
}
