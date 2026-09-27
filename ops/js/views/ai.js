// ai.js —— AI 媒体处理：能力/自动处理/状态队列/检索/人物/去重/近期回顾。
//
// 所有 AI 调用都做降级：能力清单与状态由后端下发，未就绪时显示原因并禁用相关控件；
// 非 2xx 一律把服务端的 error 显示出来，绝不渲染空白页。

import {
  aiCapabilities, aiStatus, aiJobs, aiEnqueue, aiRetry, aiCancel, aiResume,
  aiRebuildIndex, aiProcess, aiSearch, aiDuplicates, aiIgnoreDuplicates,
  aiUnignoreDuplicates, aiIgnoredDuplicates, aiPersons, aiPersonRename,
  aiPersonDelete, aiPersonsMerge, aiRecluster, aiReviewPresets,
  aiUpsertReviewPreset, aiDeleteReviewPreset, aiGenerateReview,
  galleryMedia, galleryPatchMedia, getSettings, putSettings, thumbUrl,
} from '../api.js';
import {
  el, mount, card, tableEl, tr, badge, btn, errorBox, alertBox, emptyBox,
  fmtTime, fmtNum, fmtBytes, toast, toastError, text, } from '../dom.js';
import { createPoller } from '../poll.js';
import { collapsibleCard } from '../prefs.js';

export const title = 'AI 媒体处理';

const SUBTABS = [
  { id: 'caps', label: '能力 / 概览' },
  { id: 'auto', label: '自动处理' },
  { id: 'status', label: '状态 / 队列' },
  { id: 'search', label: '检索' },
  { id: 'persons', label: '人物' },
  { id: 'dupes', label: '去重 / 已删除' },
  { id: 'review', label: '近期回顾' },
];

/** 自动入队开关的配置键（候选来自 schema，不在这里写候选）。 */
const AUTO_CAPS_KEY = 'ai.auto_capabilities';

/** /API/ai/search 支持的检索模式（与 handler 的 mode 取值一致）。 */
const SEARCH_MODES = [
  { value: 'auto', label: '智能（语义 + 关键词加权）' },
  { value: 'semantic', label: '语义' },
  { value: 'keyword', label: '关键词（OCR/描述/AI 标签）' },
  { value: 'filename', label: '文件名' },
];

/** ai_jobs.status 的取值。 */
const JOB_STATUSES = [
  { value: 'pending', label: '待处理' },
  { value: 'running', label: '处理中' },
  { value: 'done', label: '已完成' },
  { value: 'failed', label: '失败' },
];

const JOB_STATUS_LABEL = Object.fromEntries(JOB_STATUSES.map((item) => [item.value, item.label]));

function mediaThumb(mediaId, caption, extra = []) {
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

function shortId(id) {
  const value = String(id || '');
  return value.length > 8 ? value.slice(0, 8) : value;
}

function numberInput(value, opts = {}) {
  const { min = null, max = null, className = 'w-90' } = opts;
  return el('input', {
    type: 'number',
    class: className,
    value: String(value ?? ''),
    min: min === null ? null : String(min),
    max: max === null ? null : String(max),
  });
}

// ===========================================================================
// 能力 / 概览
// ===========================================================================

async function renderCaps(host) {
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
    const key = EXECUTOR_SETTING_KEY[info.capability];
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

// ===========================================================================
// 自动处理
// ===========================================================================

async function renderAuto(host) {
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

// ===========================================================================
// 状态 / 队列
// ===========================================================================

async function renderStatus(host) {
  let status = null;
  let jobs = [];
  let error = null;
  let jobsError = null;
  let jobFilter = { capability: '', status: '' };
  let busy = false;

  const toolbar = el('div', { class: 'toolbar' });
  const statusHost = el('div', { class: 'view-body' });
  const jobsHost = el('div', { class: 'view-body' });
  mount(host, toolbar, statusHost, jobsHost);

  const poller = createPoller(() => refresh({ withJobs: true }), { interval: 2000 });

  function capabilityOptions() {
    const list = (status && status.capabilities) || [];
    return list.map((item) => ({ value: item.capability, label: item.capability }));
  }

  function renderToolbar() {
    const capsSelect = el('select', {
      class: 'w-140',
      value: jobFilter.capability,
      onchange: (event) => { jobFilter.capability = event.target.value; void refresh({ withJobs: true }); },
    }, [el('option', { value: '', text: '全部能力' })].concat(
      capabilityOptions().map((option) => el('option', { value: option.value, text: option.label })),
    ));
    const statusSelect = el('select', {
      class: 'w-140',
      value: jobFilter.status,
      onchange: (event) => { jobFilter.status = event.target.value; void refresh({ withJobs: true }); },
    }, [el('option', { value: '', text: '全部状态' })].concat(
      JOB_STATUSES.map((item) => el('option', { value: item.value, text: item.label })),
    ));

    mount(toolbar,
      el('label', { class: 'inline' }, [el('span', { text: '能力' }), capsSelect]),
      el('label', { class: 'inline' }, [el('span', { text: '状态' }), statusSelect]),
      btn('刷新', () => { void refresh({ withJobs: true }); }),
      el('div', { class: 'spacer' }),
      btn('重试失败', () => { void action('retry'); }),
      btn('中断并暂停', () => { void action('cancel'); }, { kind: 'danger' }),
      btn('继续处理', () => { void action('resume'); }),
      btn('重建向量索引', () => { void action('rebuild'); }));
  }

  function renderStatusCards() {
    if (error) {
      mount(statusHost, errorBox(`读取 AI 状态失败：${error.message || error}`, () => { void refresh({ withJobs: true }); }));
      return;
    }
    if (!status) {
      mount(statusHost, emptyBox('正在读取 AI 状态…'));
      return;
    }
    const cards = [];
    if (status.enabled === false) {
      cards.push(alertBox('AI 处理层未启用：不会启动任何 worker，检索与标注接口会返回明确错误。', 'warn'));
    }
    if (status.schema_ready === false) {
      cards.push(alertBox('ai 表结构未初始化（GET /API/ai/status 报 schema_ready=false）：请先迁移数据库。', 'error'));
    }
    if (status.paused) {
      cards.push(alertBox('处理队列已暂停（POST /API/ai/resume 继续）。', 'warn'));
    }

    cards.push(collapsibleCard('ai.status.runtime', '运行状态', [el('dl', { class: 'kv' }, [
      el('dt', { text: '总开关' }), el('dd', null, status.enabled ? badge('启用', 'ok') : badge('关闭', 'err')),
      el('dt', { text: '启动状态' }), el('dd', null, status.started ? badge('已启动', 'ok') : badge('未启动', 'warn')),
      el('dt', { text: '队列' }), el('dd', null, status.paused ? badge('已暂停', 'warn') : badge('运行中', 'ok')),
      el('dt', { text: '推理设备' }), el('dd', null, el('span', { class: 'mono', text: text(status.device) })),
      el('dt', { text: '单批媒体数' }), el('dd', null, fmtNum(status.batch_size)),
      el('dt', { text: '侧车空闲退出' }), el('dd', null, `${fmtNum(status.idle_timeout_seconds)} 秒`),
      el('dt', { text: '单批超时' }), el('dd', null, `${fmtNum(status.job_timeout_seconds)} 秒`),
      el('dt', { text: '最大尝试次数' }), el('dd', null, fmtNum(status.max_attempts)),
      el('dt', { text: '向量模型' }), el('dd', null, el('span', { class: 'mono', text: text(status.embed_model) })),
      el('dt', { text: '待处理 / 失败' }), el('dd', null, `${fmtNum(status.pending_total)} / ${fmtNum(status.failed_total)}`),
      el('dt', { text: '人物数' }), el('dd', null, fmtNum(status.person_count)),
      el('dt', { text: '向量索引' }), el('dd', null, [
        badge(status.index && status.index.loaded ? '已载入' : '未载入', status.index && status.index.loaded ? 'ok' : 'warn'),
        el('span', { class: 'mono', text: `${fmtNum(status.index ? status.index.vectors : 0)} 条 · 约 ${fmtBytes(status.index ? status.index.memory_estimate_bytes : 0)}` }),
      ]),
      el('dt', { text: '聚类' }), el('dd', null, el('span', { class: 'mono', text: `${fmtNum(status.cluster ? status.cluster.persons : 0)} 组 · 阈值 ${text(status.cluster && status.cluster.threshold)}` })),
    ])]));

    const run = status.last_run;
    cards.push(collapsibleCard('ai.status.lastrun', '最近批次', run ? [
      el('dl', { class: 'kv' }, [
        el('dt', { text: '能力' }), el('dd', null, el('span', { class: 'mono', text: text(run.capability) })),
        el('dt', { text: '进度' }), el('dd', null, `${fmtNum(run.processed)} / ${fmtNum(run.total)}（失败 ${fmtNum(run.failed)}）`),
        el('dt', { text: '开始时间' }), el('dd', null, fmtTime(run.started_at)),
        el('dt', { text: '状态' }), el('dd', null, run.running ? badge('进行中', 'info') : badge('已结束', 'ok')),
      ]),
    ] : [emptyBox('本次服务启动后还没有运行过批次')]));

    const ollama = status.ollama || {};
    cards.push(collapsibleCard('ai.status.ollama', 'Ollama', [el('dl', { class: 'kv' }, [
      el('dt', { text: '地址' }), el('dd', null, el('span', { class: 'mono', text: text(ollama.url) })),
      el('dt', { text: '连通性' }), el('dd', null, ollama.reachable ? badge('可访问', 'ok') : badge('不可访问', 'err')),
      ollama.error ? el('dt', { text: '错误' }) : null,
      ollama.error ? el('dd', null, el('span', { class: 'err-text', text: ollama.error })) : null,
      el('dt', { text: '标注模型' }), el('dd', null, el('span', { class: 'mono', text: text(ollama.model) })),
      el('dt', { text: '模型就绪' }), el('dd', null, ollama.model_ready ? badge('就绪', 'ok') : badge('未就绪', 'warn')),
      el('dt', { text: '候选（默认 / 备选）' }), el('dd', null, [
        el('span', { class: 'mono muted', text: `${text(ollama.model_default)} / ${text(ollama.model_alt)}` }),
      ]),
      el('dt', { text: '正在推理' }), el('dd', null, ollama.active_model
        ? badge(ollama.active_model, 'info')
        : badge('空闲', '')),
      el('dt', { text: '进程' }), el('dd', null, el('span', { class: 'mono', text: ollama.owned_server ? `本服务拉起（PID ${text(ollama.pid)}）` : '复用用户进程' })),
      el('dt', { text: '驻留策略' }), el('dd', null, `${text(ollama.keep_alive)}（默认 ${fmtNum(ollama.keep_alive_default_seconds)} 秒）`),
      el('dt', { text: '上下文长度' }), el('dd', null, fmtNum(ollama.num_ctx)),
      el('dt', { text: '思考链' }), el('dd', null, ollama.thinking ? badge('支持', 'info') : badge('不支持', '')),
      ollama.last_switch ? el('dt', { text: '最近抢占' }) : null,
      ollama.last_switch ? el('dd', null, el('span', { class: 'warn-text', text: ollama.last_switch })) : null,
    ])]));

    const capRows = (status.capabilities || []).map((item) => {
      const sidecar = item.sidecar;
      const running = Boolean(sidecar && sidecar.running);
      return tr([
        el('span', { class: 'mono', text: item.capability }),
        item.ready ? badge('就绪', 'ok') : badge('未就绪', 'err'),
        el('span', { class: 'hint', text: text(item.reason) }),
        el('span', { class: 'num', text: fmtNum(item.missing_media) }),
        el('span', { class: 'num', text: fmtNum(item.pending) }),
        el('span', { class: 'num', text: fmtNum(item.done) }),
        el('span', { class: 'num', text: fmtNum(item.failed) }),
        el('span', null, [
          el('span', { class: 'mono', text: sidecar ? (running ? `PID ${text(sidecar.pid)}` : '未运行') : '进程内' }),
          sidecar ? el('span', { class: 'hint', text: running ? `空闲 ${fmtNum(sidecar.idle_seconds)}s / ${fmtNum(sidecar.idle_timeout_seconds)}s` : '' }) : null,
          sidecar && sidecar.probe_error ? el('span', { class: 'err-text', text: sidecar.probe_error }) : null,
        ]),
        el('div', { class: 'row' }, [
          btn('启动模型', () => { void action('start', item.capability); }, { size: 'sm' }),
          sidecar && running ? btn('停止', () => { void action('stop', item.capability); }, { size: 'sm' }) : null,
          btn('补处理', () => { void action('enqueue', item.capability); }, {
            size: 'sm', disabled: !item.ready, title: item.ready ? '为全库缺失该产物的媒体入队' : (item.reason || '未就绪'),
          }),
        ]),
      ]);
    });
    cards.push(collapsibleCard('ai.status.caps', '能力与进程', [
      tableEl(['能力', '就绪', '原因', { title: '缺产物', class: 'ta-right' }, { title: '待处理', class: 'ta-right' },
        { title: '已完成', class: 'ta-right' }, { title: '失败', class: 'ta-right' }, '侧车进程', '操作'], capRows),
    ]));

    mount(statusHost, cards);
  }

  function renderJobs() {
    const body = [];
    if (jobsError) {
      body.push(errorBox(`读取任务队列失败：${jobsError.message || jobsError}`, () => { void refresh({ withJobs: true }); }));
    }
    if (jobs.length === 0) {
      body.push(emptyBox(jobsError ? '—' : '没有匹配的任务'));
    } else {
      const rows = jobs.map((job) => tr([
        el('span', { class: 'mono', text: String(job.id) }),
        el('span', { class: 'mono', text: job.capability }),
        el('span', { class: 'mono', title: job.media_id, text: shortId(job.media_id) }),
        badge(JOB_STATUS_LABEL[job.status] || job.status, job.status === 'failed' ? 'err' : (job.status === 'done' ? 'ok' : 'info')),
        el('span', { class: 'num', text: fmtNum(job.attempts) }),
        el('span', { class: 'mono nowrap', text: fmtTime(job.updated_at) }),
        el('span', { class: 'err-text', text: text(job.last_error) }),
      ]));
      body.push(tableEl(['ID', '能力', '媒体', '状态', '尝试', '更新时间', '错误'], rows));
    }
    mount(jobsHost, card('任务队列', body, { subtitle: `${jobs.length} 条` }));
  }

  async function refresh({ withJobs = false } = {}) {
    try {
      status = await aiStatus();
      error = null;
    } catch (err) {
      error = err;
    }
    if (withJobs) {
      try {
        const data = await aiJobs({ limit: 200, capability: jobFilter.capability, status: jobFilter.status });
        jobs = (data && data.jobs) || [];
        jobsError = null;
      } catch (err) {
        jobsError = err;
      }
    }
    const runningJobs = jobs.some((job) => job.status === 'running');
    const active = Boolean(status) && (
      status.pending_total > 0 ||
      (status.last_run && status.last_run.running) ||
      (status.capabilities || []).some((item) => item.sidecar && item.sidecar.running) ||
      (status.ollama && (status.ollama.active_model || status.ollama.owned_server))
    );
    if (active || runningJobs) poller.start();
    else if (!poller.graceActive) poller.stop();

    renderToolbar();
    renderStatusCards();
    renderJobs();
  }

  async function action(kind, capability) {
    if (busy) return;
    busy = true;
    try {
      if (kind === 'retry') {
        const data = await aiRetry({});
        toast(`已重排 ${fmtNum(data && data.retried)} 条失败任务`, 'ok');
      } else if (kind === 'cancel') {
        if (!window.confirm('中断当前批次并暂停队列？之后需要点「继续处理」才会恢复。')) return;
        const data = await aiCancel();
        toast(`已中断 ${fmtNum(data && data.cancelled)} 条，队列已暂停`, 'ok');
      } else if (kind === 'resume') {
        await aiResume();
        toast('处理队列已恢复', 'ok');
      } else if (kind === 'rebuild') {
        const data = await aiRebuildIndex();
        toast(`向量索引已重建：${fmtNum(data && data.vectors)} 条`, 'ok');
      } else if (kind === 'start') {
        await aiProcess(capability, 'start');
        toast(`已请求启动 ${capability} 的模型/侧车`, 'ok');
      } else if (kind === 'stop') {
        await aiProcess(capability, 'stop');
        toast(`已请求停止 ${capability}`, 'ok');
      } else if (kind === 'enqueue') {
        if (!window.confirm(`为「${capability}」入队全库缺失项？任务会排队依次处理。`)) return;
        const data = await aiEnqueue({ capabilities: [capability], scope: 'missing' });
        const count = data && data.enqueued ? data.enqueued[capability] : 0;
        toast(`已入队 ${fmtNum(count)} 条（${capability}）`, 'ok');
        poller.kick(15);
      }
      await refresh({ withJobs: true });
    } catch (err) {
      toastError(err);
    } finally {
      busy = false;
    }
  }

  await refresh({ withJobs: true });
  return () => poller.dispose();
}

// ===========================================================================
// 检索
// ===========================================================================

async function renderSearch(host) {
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

// ===========================================================================
// 人物
// ===========================================================================

async function renderPersons(host) {
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

// ===========================================================================
// 去重 / 已删除
// ===========================================================================

async function renderDupes(host) {
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

// ===========================================================================
// 近期回顾
// ===========================================================================

async function renderReview(host) {
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

// ===========================================================================
// 视图入口
// ===========================================================================

export async function render(root, ctx) {
  const active = SUBTABS.some((tab) => tab.id === ctx.sub) ? ctx.sub : 'caps';

  const tabHost = el('div', { class: 'tabs' }, SUBTABS.map((tab) => el('button', {
    class: `tab${tab.id === active ? ' active' : ''}`,
    text: tab.label,
    onclick: () => { location.hash = `#/ai/${tab.id}`; },
  })));
  const bodyHost = el('div', { class: 'view-body' });
  mount(root, tabHost, bodyHost);

  let dispose = null;
  if (active === 'caps') dispose = await renderCaps(bodyHost);
  else if (active === 'auto') dispose = await renderAuto(bodyHost);
  else if (active === 'status') dispose = await renderStatus(bodyHost);
  else if (active === 'search') dispose = await renderSearch(bodyHost);
  else if (active === 'persons') dispose = await renderPersons(bodyHost);
  else if (active === 'dupes') dispose = await renderDupes(bodyHost);
  else if (active === 'review') dispose = await renderReview(bodyHost);

  return () => {
    if (typeof dispose === 'function') dispose();
  };
}
