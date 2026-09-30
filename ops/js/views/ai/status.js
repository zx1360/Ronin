// status.js —— 状态 / 队列：运行状态卡片、能力与侧车进程启停、任务队列与批量入队。
//
// 侧车（模型进程）的启停按钮就挂在能力表里，与队列操作共用同一份 busy/刷新/轮询状态，
// 因此不单独成模块。仅在队列或模型进程活跃时轮询。

import {
  aiStatus, aiJobs, aiRetry, aiCancel, aiResume, aiRebuildIndex, aiProcess, aiEnqueue,
} from '../../api.js';
import {
  el, mount, card, tableEl, tr, badge, btn, errorBox, alertBox, emptyBox,
  fmtTime, fmtNum, fmtBytes, toast, toastError, text,
} from '../../dom.js';
import { createPoller } from '../../poll.js';
import { collapsibleCard } from '../../prefs.js';
import { shortId } from './shared.js';

/** ai_jobs.status 的取值。 */
const JOB_STATUSES = [
  { value: 'pending', label: '待处理' },
  { value: 'running', label: '处理中' },
  { value: 'done', label: '已完成' },
  { value: 'failed', label: '失败' },
];

const JOB_STATUS_LABEL = Object.fromEntries(JOB_STATUSES.map((item) => [item.value, item.label]));

export async function render(host) {
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
