// comix.js —— 漫画资源：comix 配置、网址下载、漫画库与爬虫任务面板。
//
// comix 接口统一使用 {ok,data} / {ok:false,error} 信封（api.js 的 unwrap 负责解码）。
// 刻意不实现"替换封面"：PUT /API/comic/comic-info/:id 只发 is_public / readed。

import {
  comixConfig, comixInit, comixList, comixTasks, comixTask, comixStop,
  comixDownloadUrl, comixDownload, comixUpdateCheck, comixDelete, comixClean,
  comicUpdate, staticUrl,
} from '../api.js';
import {
  el, mount, card, tableEl, tr, badge, btn, errorBox, emptyBox,
  fmtTime, fmtDuration, toast, toastError, text,
} from '../dom.js';
import { createPoller } from '../poll.js';
import { collapsibleCard } from '../prefs.js';
import { statusBadge, autoscrollToggle, createLogPanels } from '../tasks.js';

export const title = '漫画资源';

function coverCell(comic) {
  if (!comic.cover_image) {
    return el('span', { class: 'hint', text: '无封面' });
  }
  const img = el('img', {
    src: staticUrl(comic.cover_image),
    alt: comic.title || '',
    loading: 'lazy',
    style: { width: '38px', height: '52px', objectFit: 'cover', borderRadius: '3px', background: '#0e1116' },
  });
  img.addEventListener('error', () => {
    img.replaceWith(el('span', { class: 'hint', text: '封面不可用' }));
  });
  return img;
}

export async function render(root) {
  let config = null;
  let configError = null;
  let comics = [];
  let comicsError = null;
  let tasks = [];
  let tasksError = null;
  let initOutput = '';
  let urlResults = [];
  let submitting = false;
  let lastRunning = 0;

  const expanded = new Set();
  const logPanels = createLogPanels();
  const logsCache = new Map();

  const configHost = el('div', { class: 'view-body' });
  const downloadHost = el('div', { class: 'view-body' });
  const listHost = el('div', { class: 'view-body' });
  const taskHost = el('div', { class: 'view-body' });
  mount(root, configHost, downloadHost, listHost, taskHost);

  const autoscrollBox = autoscrollToggle();

  const poller = createPoller(() => refreshTasks(), { interval: 2000 });

  // ---------- comix 配置 ----------

  async function loadConfig() {
    try {
      config = await comixConfig();
      configError = null;
    } catch (err) {
      configError = err;
    }
    renderConfig();
  }

  function renderConfig() {
    if (configError) {
      mount(configHost, errorBox(`读取 comix 配置失败：${configError.message || configError}`, () => { void loadConfig(); }));
      return;
    }
    if (!config) {
      mount(configHost, emptyBox('正在读取 comix 配置…'));
      return;
    }
    const body = [
      el('dl', { class: 'kv' }, [
        el('dt', { text: '可用状态' }),
        el('dd', null, config.available ? badge('可用', 'ok') : badge('不可用', 'err')),
        el('dt', { text: 'Python 解释器' }),
        el('dd', null, el('span', { class: 'mono', text: text(config.python) })),
        el('dt', { text: '配置的解释器' }),
        el('dd', null, el('span', { class: 'mono muted', text: text(config.configured_python) })),
        el('dt', { text: 'comix 项目目录' }),
        el('dd', null, el('span', { class: 'mono', text: text(config.root) })),
        el('dt', { text: '说明' }),
        el('dd', null, el('span', { class: config.available ? 'muted' : 'err-text', text: text(config.message) })),
      ]),
      el('div', { class: 'row' }, [
        btn('初始化（建表 + 注册站点）', () => { void runInit(); }, { kind: 'primary', disabled: submitting }),
      ]),
      initOutput ? el('pre', { class: 'logs', text: initOutput }) : null,
    ];
    mount(configHost, collapsibleCard('comix.config', 'comix 集成', body));
  }

  async function runInit() {
    submitting = true;
    renderConfig();
    try {
      const result = await comixInit();
      initOutput = JSON.stringify(result, null, 2);
      toast('初始化完成', 'ok');
    } catch (err) {
      initOutput = err.message || String(err);
      toastError(err);
    } finally {
      submitting = false;
      renderConfig();
    }
  }

  // ---------- 网址下载 ----------

  const urlInput = el('textarea', { placeholder: '每行一个详情页 URL（可混用多个站点）' });
  const latestInput = el('input', { type: 'number', min: '1', class: 'w-140', placeholder: '留空 = 全部' });

  function renderDownload() {
    mount(downloadHost, card('网址下载', [
      urlInput,
      el('div', { class: 'row' }, [
        el('label', { class: 'inline' }, [el('span', { text: '仅最近 N 章' }), latestInput]),
        btn('开始下载', () => { void submitUrls(); }, { kind: 'primary', disabled: submitting }),
        el('span', { class: 'hint', text: '留空表示下载整本；只接受正整数。' }),
      ]),
      urlResults.length
        ? tableEl(['URL', '站点', '任务', '结果'], urlResults.map((item) => tr([
          el('span', { class: 'mono', text: item.url }),
          el('span', { text: text(item.site) }),
          el('span', { class: 'mono', text: text(item.task_id) }),
          item.error ? el('span', { class: 'err-text', text: item.error }) : badge('已入队', 'ok'),
        ])))
        : null,
    ]));
  }

  async function submitUrls() {
    const urls = urlInput.value.split(/[\s,]+/).map((item) => item.trim()).filter(Boolean);
    if (urls.length === 0) {
      toast('请先填写至少一个详情页 URL', 'error');
      return;
    }
    const raw = latestInput.value.trim();
    const body = { urls };
    if (raw !== '') {
      const value = Number(raw);
      if (!Number.isInteger(value) || value <= 0) {
        toast('「仅最近 N 章」需为正整数，留空表示下载全部', 'error');
        return;
      }
      body.latest = value;
    }
    submitting = true;
    renderDownload();
    try {
      const data = await comixDownloadUrl(body);
      urlResults = (data && data.tasks) || [];
      const failed = urlResults.filter((item) => item.error).length;
      toast(failed ? `已提交 ${urlResults.length - failed} 个任务，${failed} 个失败` : `已提交 ${urlResults.length} 个任务`,
        failed ? 'error' : 'ok');
      poller.kick(15);
      await refreshTasks();
    } catch (err) {
      toastError(err);
    } finally {
      submitting = false;
      renderDownload();
    }
  }

  // ---------- 漫画库 ----------

  async function refreshComics() {
    try {
      const data = await comixList();
      comics = (data && data.comics) || [];
      comicsError = null;
    } catch (err) {
      comicsError = err;
    }
    renderLibrary();
  }

  async function toggleComic(comic, field, checked, revert) {
    try {
      await comicUpdate(comic.comic_id, { [field]: checked });
      comic[field] = checked;
      toast(`已更新 #${comic.comic_id} 的${field === 'is_public' ? '公开' : '已读'}状态`, 'ok');
    } catch (err) {
      toastError(err);
      revert.checked = !checked;
    }
    renderLibrary();
  }

  async function comicAction(action, comic) {
    try {
      if (action === 'download') {
        await comixDownload({ comic_id: comic.comic_id });
        toast(`已提交下载任务：#${comic.comic_id}`, 'ok');
      } else if (action === 'update') {
        await comixUpdateCheck({ comic_id: comic.comic_id, download: true });
        toast(`已提交追更任务：#${comic.comic_id}`, 'ok');
      } else if (action === 'delete') {
        if (!window.confirm(`删除《${comic.title || comic.comic_id}》？数据库记录与已下载文件都会被删除。`)) return;
        await comixDelete({ comic_id: comic.comic_id });
        toast(`已删除 #${comic.comic_id}`, 'ok');
        await refreshComics();
      }
      poller.kick(15);
      await refreshTasks();
    } catch (err) {
      toastError(err);
    }
  }

  function renderLibrary() {
    const body = [];
    if (comicsError) {
      body.push(errorBox(`读取漫画库失败：${comicsError.message || comicsError}`, () => { void refreshComics(); }));
    }
    if (comics.length === 0) {
      body.push(emptyBox(comicsError ? '—' : '漫画库为空'));
    } else {
      const rows = comics.map((comic) => {
        const total = Number(comic.total_chapters) || 0;
        const done = Number(comic.downloaded) || 0;
        const pending = Number(comic.pending) || 0;
        const failed = Number(comic.failed) || 0;
        const publicBox = el('input', { type: 'checkbox', checked: Boolean(comic.is_public) });
        publicBox.addEventListener('change', () => { void toggleComic(comic, 'is_public', publicBox.checked, publicBox); });
        const readBox = el('input', { type: 'checkbox', checked: Boolean(comic.readed) });
        readBox.addEventListener('change', () => { void toggleComic(comic, 'readed', readBox.checked, readBox); });
        return tr([
          coverCell(comic),
          el('div', { class: 'col' }, [
            el('span', { text: text(comic.title) }),
            el('span', { class: 'hint mono', text: `#${comic.comic_id}` }),
          ]),
          el('span', { text: `${text(comic.site_name || comic.site)}${comic.is_legacy ? '（历史）' : ''}` }),
          el('div', { class: 'col' }, [
            el('span', { class: 'mono', text: `${done}/${total}` }),
            el('span', { class: 'hint', text: failed ? `失败 ${failed} · 待下 ${pending}` : `待下 ${pending}` }),
          ]),
          el('span', { class: 'ta-center' }, publicBox),
          el('span', { class: 'ta-center' }, readBox),
          el('span', { class: 'num', text: String(total) }),
          el('span', { class: 'num', text: String(comic.image_count ?? 0) }),
          el('div', { class: 'row' }, [
            btn('下载', () => { void comicAction('download', comic); }, { size: 'sm' }),
            btn('追更', () => { void comicAction('update', comic); }, { size: 'sm' }),
            btn('删除', () => { void comicAction('delete', comic); }, { size: 'sm', kind: 'danger' }),
          ]),
        ]);
      });
      body.push(tableEl([
        '封面', '标题', '站点', '进度', { title: '公开', class: 'ta-center' }, { title: '已读', class: 'ta-center' },
        { title: '章节', class: 'ta-right' }, { title: '图片', class: 'ta-right' }, '操作',
      ], rows));
    }
    mount(listHost, collapsibleCard('comix.library', '漫画库', body, {
      subtitle: `${comics.length} 本`,
      actions: el('div', { class: 'row' }, [
        btn('刷新列表', () => { void refreshComics(); }, { size: 'sm' }),
        btn('全站追更检查', () => { void allUpdateCheck(); }, { size: 'sm' }),
        btn('清理残留', () => { void cleanOrphans(); }, { size: 'sm' }),
      ]),
    }));
  }

  async function allUpdateCheck() {
    try {
      await comixUpdateCheck({ all: true, download: true });
      toast('已提交全站追更检查', 'ok');
      poller.kick(15);
      await refreshTasks();
    } catch (err) {
      toastError(err);
    }
  }

  async function cleanOrphans() {
    if (!window.confirm('回收中断残留（running 任务 + .downloading 临时目录）？')) return;
    try {
      await comixClean();
      toast('已提交清理任务', 'ok');
      poller.kick(15);
      await refreshTasks();
    } catch (err) {
      toastError(err);
    }
  }

  // ---------- 任务面板 ----------

  async function loadLogs(task) {
    const cached = logsCache.get(task.id);
    if (cached && task.status !== 'running') return cached;
    try {
      const detail = await comixTask(task.id);
      const logs = (detail && detail.logs) || [];
      logsCache.set(task.id, logs);
      return logs;
    } catch (err) {
      return cached || [];
    }
  }

  function renderTasks() {
    const body = [];
    if (tasksError) {
      body.push(errorBox(`读取任务失败：${tasksError.message || tasksError}`, () => { void refreshTasks(); }));
    }
    if (tasks.length === 0) {
      body.push(emptyBox(tasksError ? '—' : '暂无爬虫任务'));
    } else {
      const rows = [];
      for (const task of tasks) {
        const isOpen = expanded.has(task.id);
        const result = task.result || null;
        rows.push(tr([
          el('button', {
            class: 'icon-btn',
            title: isOpen ? '收起日志' : '展开日志',
            text: isOpen ? '▾' : '▸',
            onclick: () => {
              if (isOpen) expanded.delete(task.id);
              else expanded.add(task.id);
              void refreshTasks();
            },
          }),
          el('div', { class: 'col' }, [
            el('span', { text: text(task.name) }),
            el('span', { class: 'hint mono', text: `${task.id} · ${text(task.command)}` }),
          ]),
          statusBadge(task.status),
          el('span', { class: 'mono nowrap', text: fmtTime(task.started_at) }),
          el('span', { class: 'nowrap', text: fmtDuration(task.started_at, task.finished_at) }),
          el('div', { class: 'col' }, [
            result && result.ok === false ? el('span', { class: 'err-text', text: text(result.error) }) : null,
            task.error ? el('span', { class: 'err-text', text: task.error }) : null,
            result && result.ok ? badge('ok', 'ok') : null,
          ]),
          el('span', { class: 'row' }, [
            task.status === 'running'
              ? btn('中断', () => { void stopTask(task.id); }, { size: 'sm', kind: 'danger' })
              : null,
          ]),
        ]));
        if (isOpen) {
          const panel = logPanels.update(task.id, logsCache.get(task.id) || []);
          rows.push(el('tr', null, el('td', { colspan: '7' }, [
            result && result.stderr ? el('pre', { class: 'logs', text: result.stderr }) : null,
            panel.node,
          ])));
        }
      }
      body.push(tableEl(['', '任务', '状态', '开始时间', '耗时', '结果', { title: '操作', class: 'ta-right' }], rows));
    }
    mount(taskHost, card('爬虫任务', body, {
      actions: el('div', { class: 'row' }, [
        el('label', { class: 'inline' }, [autoscrollBox, el('span', { text: '日志自动滚动' })]),
        btn('刷新', () => { void refreshTasks(); }, { size: 'sm' }),
      ]),
    }));
  }

  async function refreshTasks() {
    try {
      const data = await comixTasks();
      tasks = (data && data.tasks) || [];
      tasksError = null;
    } catch (err) {
      tasksError = err;
    }
    const running = tasks.filter((task) => task.status === 'running').length;
    if (running > 0) poller.start();
    else if (!poller.graceActive) poller.stop();

    logPanels.prune(tasks);
    await Promise.all([...expanded].map((id) => {
      const task = tasks.find((item) => item.id === id);
      return task ? loadLogs(task) : Promise.resolve(null);
    }));
    renderTasks();
    if (running === 0 && lastRunning > 0) void refreshComics();
    lastRunning = running;
  }

  async function stopTask(taskId) {
    try {
      await comixStop(taskId);
      toast(`已请求中断 ${taskId}`, 'ok');
      await refreshTasks();
    } catch (err) {
      toastError(err);
    }
  }

  await loadConfig();
  renderDownload();
  renderLibrary();
  renderTasks();
  await Promise.all([refreshComics(), refreshTasks()]);

  return () => {
    poller.dispose();
    logPanels.clear();
    logsCache.clear();
  };
}
