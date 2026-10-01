// 漫画资源的共享状态与接口调用：comix 可用性 / 站点 / 任务快照 / 漫画库 / 章节。
//
// 三个 Tab 共用同一份任务快照（对照桌面端 ComixBoardNotifier）：提交后的任务在
// 任务面板可见，网址下载的逐条结果也随它实时更新；轮询只在「有运行中任务」或
// 「刚提交、尚未出现在列表里」时按 2 秒开启。
//
// 时序注意：/API/comix/* 的业务错误是 HTTP 200 + {ok:false, error}，api.js 只在
// 非 2xx 时抛异常，因此每次调用后都要过 unwrap() 检查 ok 字段。

import { ref, computed, onMounted, nextTick } from '../../vue.js';
import { api, assetUrl } from '../../api.js';
import { state, toast, confirmAction } from '../../store.js';
import { usePolling } from '../../ui.js';
import { formatClock, formatDuration, formatTime } from '../../utils.js';
import {
  chapterStatusKind,
  chapterStatusText,
  isBusinessError,
  normalizeSubmit,
  submitResultView,
  taskFailure,
  taskFailureReason,
  taskSummary,
  validateLatest,
  validateRange,
} from './helpers.js';

/** 建立漫画页的共享状态；必须在组件的 setup() 中调用（内部注册 onMounted/onUnmounted）。 */
export function useComixBoard() {
  /** 业务错误（ok=false）也在这里抛出，避免页面把失败当成功。 */
  const unwrap = (payload, label) => {
    if (payload && payload.ok === false) throw new Error(payload.error || `${label}失败`);
    if (!payload) return {};
    return payload.data === undefined ? payload : payload.data;
  };

  // ---- comix 集成可用性 ----

  const config = ref(null);
  const configError = ref('');
  const initRunning = ref(false);

  const loadConfig = async () => {
    try {
      config.value = unwrap(await api.get('/API/comix/config'), '获取 comix 配置');
      configError.value = '';
    } catch (err) {
      config.value = null;
      configError.value = err.message;
    }
  };

  const comixAvailable = computed(() => {
    if (config.value) return config.value.available === true;
    return state.cli.comix.available === true;
  });
  const comixMessage = computed(() => {
    if (config.value && config.value.message) return config.value.message;
    return state.cli.comix.message || '';
  });
  const comixPython = computed(() => {
    const value = config.value && (config.value.python || config.value.configured_python);
    return value || state.cli.comix.python || '—';
  });
  const comixRoot = computed(() => (config.value && config.value.root) || state.cli.comix.root || '—');

  const runInit = async () => {
    const ok = await confirmAction('执行 comix init：建表并注册站点（幂等，可重复执行）。', {
      title: '确认初始化 comix',
    });
    if (!ok) return;
    initRunning.value = true;
    try {
      const data = unwrap(await api.post('/API/comix/init', {}, { timeoutMs: 120000 }), '初始化');
      const message = data && typeof data.message === 'string' ? data.message : '';
      toast(`初始化完成${message ? `：${message}` : ''}`, 'success');
      await Promise.all([loadSites(), loadConfig()]);
    } catch (err) {
      toast(`初始化失败: ${err.message}`, 'error');
    } finally {
      initRunning.value = false;
    }
  };

  // ---- 站点列表 ----

  const sites = ref([]);
  const sitesError = ref('');

  const loadSites = async () => {
    try {
      const data = unwrap(await api.get('/API/comix/sites'), '获取站点列表');
      sites.value = Array.isArray(data.sites) ? data.sites : [];
      sitesError.value = '';
    } catch (err) {
      sites.value = [];
      sitesError.value = err.message;
    }
  };

  // ---- 任务快照（三个 Tab 共用） ----

  const tasks = ref([]);
  const tasksError = ref('');
  const selectedTaskId = ref('');
  const taskDetail = ref(null);
  const detailError = ref('');
  const logKeyword = ref('');
  const autoScroll = ref(true);
  const viewRef = ref(null);
  /** 已提交但尚未出现在后端列表里的任务，用于兜底轮询。 */
  const pendingIds = ref([]);
  let pendingRounds = 0;

  const loadTasks = async () => {
    try {
      const data = unwrap(await api.get('/API/comix/tasks'), '获取任务列表');
      const list = Array.isArray(data.tasks) ? data.tasks : [];
      tasks.value = list;
      tasksError.value = '';
      const ids = new Set(list.map((item) => item.id));
      if (pendingIds.value.some((id) => ids.has(id))) {
        pendingIds.value = pendingIds.value.filter((id) => !ids.has(id));
      }
    } catch (err) {
      tasksError.value = err.message;
    }
  };

  const loadDetail = async (taskId) => {
    const id = taskId || selectedTaskId.value;
    if (!id) {
      taskDetail.value = null;
      return;
    }
    try {
      const data = unwrap(await api.get(`/API/comix/tasks/${encodeURIComponent(id)}`), '获取任务详情');
      taskDetail.value = data || null;
      detailError.value = '';
    } catch (err) {
      detailError.value = err.message;
    }
    if (autoScroll.value) {
      await nextTick();
      if (viewRef.value) viewRef.value.scrollTop = viewRef.value.scrollHeight;
    }
  };

  const runningCount = computed(() => tasks.value.filter((item) => item.status === 'running').length);
  const hasWork = computed(() => runningCount.value > 0 || pendingIds.value.length > 0);

  const poller = usePolling(async () => {
    await loadTasks();
    // 已提交的任务若始终不出现（被裁剪/提交被吞），不能让轮询永远跑下去
    if (pendingIds.value.length) {
      pendingRounds += 1;
      if (pendingRounds > 15) {
        pendingIds.value = [];
        pendingRounds = 0;
      }
    } else {
      pendingRounds = 0;
    }
    if (selectedTaskId.value) await loadDetail();
  }, { interval: () => 2, enabled: () => hasWork.value });

  /** 登记刚提交的任务，并立刻启动/续期轮询。 */
  const trackSubmitted = async (ids) => {
    const list = (ids || []).filter(Boolean);
    if (list.length) {
      pendingIds.value = Array.from(new Set([...pendingIds.value, ...list]));
      pendingRounds = 0;
    }
    if (!selectedTaskId.value && list.length === 1) selectedTaskId.value = list[0];
    await poller.trigger();
  };

  /** 启动一个异步 comix 任务，返回 task_id。 */
  const startTask = async (endpoint, body, label) => {
    const data = unwrap(await api.post(`/API/comix/${endpoint}`, body, { timeoutMs: 60000 }), label);
    const taskId = data && typeof data.task_id === 'string' ? data.task_id : '';
    if (!taskId) throw new Error(`${label}未返回 task_id`);
    toast(`${label}已提交: ${taskId}`, 'success');
    await trackSubmitted([taskId]);
    return taskId;
  };

  // ---- Tab 1：网址下载 ----

  const urlInput = ref('');
  const latestInput = ref('');
  const submitting = ref(false);
  const submitItems = ref([]);

  const submitResults = computed(() => {
    const byId = new Map(tasks.value.map((item) => [item.id, item]));
    return submitItems.value.map((item) => submitResultView(item, byId.get(item.taskId)));
  });

  const submitUrls = async () => {
    const urls = urlInput.value
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean);
    if (!urls.length) {
      toast('请先粘贴至少一个漫画详情页网址', 'error');
      return;
    }
    const latestText = latestInput.value.trim();
    const latestError = validateLatest(latestText);
    if (latestError) {
      // 非法输入会被后端当成"留空=全部"，静默变成全量下载，必须拦下
      toast(latestError, 'error');
      return;
    }

    submitting.value = true;
    submitItems.value = [];
    try {
      const body = { urls };
      if (latestText) body.latest = Number(latestText);
      const data = unwrap(await api.post('/API/comix/download-url', body, { timeoutMs: 60000 }), '提交下载');
      submitItems.value = (Array.isArray(data.tasks) ? data.tasks : []).map(normalizeSubmit);
      const ids = submitItems.value.map((item) => item.taskId).filter(Boolean);
      const failCount = submitItems.value.length - ids.length;
      if (!submitItems.value.length) toast('服务端未返回任何提交结果', 'error');
      else if (!ids.length) toast(`提交失败：${failCount} 个网址均未能启动任务`, 'error');
      else toast(`已启动 ${ids.length} 个下载任务${failCount ? `，${failCount} 个提交失败` : ''}`, 'success');
      await trackSubmitted(ids);
    } catch (err) {
      toast(`提交失败: ${err.message}`, 'error');
    } finally {
      submitting.value = false;
    }
  };

  // ---- Tab 2：漫画库 ----

  const comics = ref([]);
  const comicsError = ref('');
  const comicsLoading = ref(false);
  const keyword = ref('');
  const statusFilter = ref('all');
  const checkDownload = ref(false);
  const checkLatest = ref('');
  const downloadTarget = ref(null);
  const downloadForm = ref({ latest: '', range: '', noRetryFailed: false });
  const downloadError = ref('');
  const chaptersComic = ref(null);
  const chapters = ref([]);
  const chaptersLoading = ref(false);
  const chaptersError = ref('');
  const chapterKeyword = ref('');

  const loadComics = async () => {
    comicsLoading.value = true;
    try {
      const data = unwrap(await api.get('/API/comix/list'), '获取漫画库');
      comics.value = Array.isArray(data.comics) ? data.comics : [];
      comicsError.value = '';
    } catch (err) {
      comicsError.value = err.message;
    } finally {
      comicsLoading.value = false;
    }
  };

  const filteredComics = computed(() => {
    const word = keyword.value.trim().toLowerCase();
    const filter = statusFilter.value;
    return comics.value
      .filter((comic) => {
        if (word) {
          const hit =
            String(comic.title || '').toLowerCase().includes(word) ||
            String(comic.site_name || '').toLowerCase().includes(word) ||
            String(comic.comic_id) === word;
          if (!hit) return false;
        }
        if (filter === 'public') return comic.is_public === true;
        if (filter === 'hidden') return comic.is_public !== true;
        if (filter === 'readed') return comic.readed === true;
        if (filter === 'unread') return comic.readed !== true;
        if (filter === 'pending') return Number(comic.pending) > 0;
        if (filter === 'failed') return Number(comic.failed) > 0;
        if (filter === 'legacy') return comic.is_legacy === true;
        return true;
      })
      .map((comic) => {
        const total = Number(comic.total_chapters) || 0;
        const downloaded = Number(comic.downloaded) || 0;

        return {
          ...comic,
          // 封面地址必须经 assetUrl 带密钥；无封面时前端给占位样式
          coverPath: comic.cover_image ? assetUrl(`/static/${comic.cover_image}`) : '',
          percent: total > 0 ? Math.min(100, Math.round((downloaded / total) * 100)) : 0,
        };
      });
  });

  const openDownload = (comic) => {
    downloadTarget.value = comic;
    downloadForm.value = { latest: '', range: '', noRetryFailed: false };
    downloadError.value = '';
  };

  const submitDownload = async () => {
    const comic = downloadTarget.value;
    if (!comic) return;
    const latestText = downloadForm.value.latest.trim();
    const rangeText = downloadForm.value.range.trim();
    const latestError = validateLatest(latestText);
    const rangeError = validateRange(rangeText);
    if (latestError || rangeError) {
      downloadError.value = latestError || rangeError;
      return;
    }
    if (latestText && rangeText) {
      downloadError.value = '「最新 N 章」与「章节区间」不能同时填写';
      return;
    }
    const body = { comic_id: comic.comic_id };
    if (latestText) body.latest = Number(latestText);
    if (rangeText) body.range = rangeText;
    if (downloadForm.value.noRetryFailed) body.no_retry_failed = true;

    try {
      await startTask('download', body, '增量下载');
      downloadTarget.value = null;
      await loadComics();
    } catch (err) {
      downloadError.value = err.message;
      toast(`提交下载失败: ${err.message}`, 'error');
    }
  };

  const runUpdateCheck = async (comic, all) => {
    const latestText = checkLatest.value.trim();
    if (checkDownload.value) {
      const latestError = validateLatest(latestText);
      if (latestError) {
        toast(latestError, 'error');
        return;
      }
    }
    const body = {};
    if (all) body.all = true;
    else body.comic_id = comic.comic_id;
    if (checkDownload.value) {
      body.download = true;
      if (latestText) body.latest = Number(latestText);
    }
    const what = all ? '全部已登记漫画' : `「${comic.title}」`;
    const ok = await confirmAction(
      `对${what}执行追更检查${checkDownload.value ? '，并自动下载新章节' : ''}？`,
      { title: all ? '确认全站追更检查' : '确认追更检查' },
    );
    if (!ok) return;
    try {
      await startTask('update-check', body, all ? '全站追更检查' : '追更检查');
    } catch (err) {
      toast(`提交追更检查失败: ${err.message}`, 'error');
    }
  };

  /** 提交完整管理字段：后端按指针字段局部更新，补齐现有值避免误覆盖。 */
  const updateComicMeta = async (comic, patch) => {
    const body = {
      is_public: patch.is_public === undefined ? comic.is_public === true : patch.is_public,
      readed: patch.readed === undefined ? comic.readed === true : patch.readed,
    };
    if (typeof comic.cover_image === 'string') body.cover_image = comic.cover_image;
    await api.put(`/API/comic/comic-info/${comic.comic_id}`, body);
  };

  const togglePublic = async (comic) => {
    const next = comic.is_public !== true;
    const ok = await confirmAction(`将「${comic.title}」设为${next ? '公开' : '隐藏'}？`, {
      title: '更新书库管理字段',
    });
    if (!ok) return;
    try {
      await updateComicMeta(comic, { is_public: next });
      toast(`「${comic.title}」已设为${next ? '公开' : '隐藏'}`, 'success');
    } catch (err) {
      toast(`更新失败: ${err.message}`, 'error');
    }
    await loadComics();
  };

  const toggleReaded = async (comic) => {
    const next = comic.readed !== true;
    const ok = await confirmAction(`将「${comic.title}」标记为${next ? '已读' : '未读'}？`, {
      title: '更新书库管理字段',
    });
    if (!ok) return;
    try {
      await updateComicMeta(comic, { readed: next });
      toast(`「${comic.title}」已标记为${next ? '已读' : '未读'}`, 'success');
    } catch (err) {
      toast(`更新失败: ${err.message}`, 'error');
    }
    await loadComics();
  };

  const removeComic = async (comic) => {
    const ok = await confirmAction(
      `确认删除「${comic.title}」吗？\n将同时删除数据库记录与本地文件（${comic.rel_dir || '未知目录'}），不可恢复。`,
      { title: '删除漫画', danger: true },
    );
    if (!ok) return;
    try {
      const data = unwrap(
        await api.post('/API/comix/delete', { comic_id: comic.comic_id, keep_files: false }, { timeoutMs: 180000 }),
        '删除漫画',
      );
      if (data && data.files_removed === false) {
        toast(`记录已删除，文件清理失败，残留目录：${data.leftover_path || '未知'}`, 'error');
      } else {
        toast(`「${comic.title}」已删除`, 'success');
      }
    } catch (err) {
      toast(`删除失败: ${err.message}`, 'error');
    } finally {
      // 失败也要刷新：服务端可能已部分完成（DB 已删、文件残留）
      await loadComics();
    }
  };

  const runClean = async () => {
    const ok = await confirmAction('孤儿回收：清理数据库里中断残留的 running 任务与 .downloading 临时目录。', {
      title: '确认孤儿回收',
      danger: true,
    });
    if (!ok) return;
    try {
      await startTask('clean', {}, '孤儿回收');
    } catch (err) {
      toast(`提交清理失败: ${err.message}`, 'error');
    }
  };

  const openChapters = async (comic) => {
    chaptersComic.value = comic;
    chapters.value = [];
    chaptersError.value = '';
    chapterKeyword.value = '';
    chaptersLoading.value = true;
    try {
      const data = unwrap(await api.get(`/API/comix/chapters/${comic.comic_id}`), '获取章节');
      chapters.value = Array.isArray(data.chapters) ? data.chapters : [];
    } catch (err) {
      chaptersError.value = err.message;
    } finally {
      chaptersLoading.value = false;
    }
  };

  const closeChapters = () => {
    chaptersComic.value = null;
    chapters.value = [];
    chaptersError.value = '';
  };

  const chapterDoneCount = computed(() => chapters.value.filter((item) => item.status === 'done').length);
  const chapterFailedCount = computed(() => chapters.value.filter((item) => item.status === 'failed').length);

  const filteredChapters = computed(() => {
    const word = chapterKeyword.value.trim().toLowerCase();
    return chapters.value
      .filter((chapter) => {
        if (!word) return true;
        return (
          String(chapter.title || '').toLowerCase().includes(word) ||
          String(chapter.chapter_no).includes(word) ||
          String(chapter.status || '').toLowerCase().includes(word)
        );
      })
      .map((chapter) => ({
        ...chapter,
        statusKind: chapterStatusKind(chapter.status),
        statusText: chapterStatusText(chapter.status),
      }));
  });

  // ---- Tab 3：任务面板 ----

  const selectTask = (task) => {
    selectedTaskId.value = task.id;
    taskDetail.value = null;
    detailError.value = '';
    loadDetail(task.id);
    if (hasWork.value) poller.trigger();
  };

  const stopTask = async (task) => {
    const ok = await confirmAction(`中断任务「${task.name || task.id}」(${task.id})？`, {
      title: '确认中断',
      danger: true,
    });
    if (!ok) return;
    try {
      unwrap(await api.post(`/API/comix/tasks/${encodeURIComponent(task.id)}/stop`, {}), '中断任务');
      toast('已发送中断命令', 'success');
      await poller.trigger();
    } catch (err) {
      toast(`中断失败: ${err.message}`, 'error');
    }
  };

  /** 列表快照与详情合并后的展示信息，避免模板里出现可选链。 */
  const selectedInfo = computed(() => {
    const listItem = tasks.value.find((item) => item.id === selectedTaskId.value) || null;
    const detailItem = taskDetail.value && taskDetail.value.id === selectedTaskId.value ? taskDetail.value : null;
    const merged = detailItem ? { ...(listItem || {}), ...detailItem } : listItem;
    if (!merged) return null;
    return {
      id: merged.id,
      name: merged.name || merged.id,
      command: merged.command || '—',
      pid: merged.pid || '—',
      started: formatTime(merged.started_at),
      finished: merged.finished_at ? formatTime(merged.finished_at) : '—',
      exit: merged.exit_code === null || merged.exit_code === undefined ? '—' : merged.exit_code,
      running: merged.status === 'running',
      failureReason: taskFailure(merged) ? taskFailureReason(merged) : '',
      summary: taskSummary(merged),
      status: merged.status,
    };
  });

  const taskDuration = (task) => {
    if (!task || !task.started_at) return '—';
    const start = new Date(task.started_at).getTime();
    if (!Number.isFinite(start)) return '—';
    const end = task.finished_at ? new Date(task.finished_at).getTime() : Date.now();
    if (!Number.isFinite(end)) return '—';
    return formatDuration(end - start);
  };

  const logLines = computed(() => {
    const logs = taskDetail.value && Array.isArray(taskDetail.value.logs) ? taskDetail.value.logs : [];
    const limit = state.settings.log_line_limit || 800;
    const sliced = logs.length > limit ? logs.slice(logs.length - limit) : logs;
    const word = logKeyword.value.trim().toLowerCase();
    if (!word) return sliced;
    return sliced.filter((item) => String(item.text || '').toLowerCase().includes(word));
  });

  /** Tab 切换时机的副作用：任务面板刷新一次，漫画库重取（下载进度由服务端聚合）。 */
  const onTabChange = (name) => {
    if (name === 'tasks') poller.trigger();
    if (name === 'library') loadComics();
  };

  onMounted(() => {
    loadConfig();
    loadSites();
    loadComics();
    poller.trigger();
  });

  return {
    onTabChange,
    config, configError, initRunning, comixAvailable, comixMessage, comixPython, comixRoot,
    loadConfig, runInit,
    sites, sitesError, loadSites,
    tasks, tasksError, pendingIds, runningCount, hasWork, refreshTasks: () => poller.trigger(),
    selectedTaskId, selectedInfo, detailError, selectTask, stopTask, taskDuration,
    logKeyword, autoScroll, logLines, viewRef,
    urlInput, latestInput, submitting, submitResults, submitUrls,
    comics, comicsError, comicsLoading, keyword, statusFilter, filteredComics, loadComics,
    checkDownload, checkLatest, runUpdateCheck, runClean,
    downloadTarget, downloadForm, downloadError, openDownload, submitDownload,
    togglePublic, toggleReaded, removeComic,
    chaptersComic, chapters, chaptersError, chaptersLoading, chapterKeyword,
    chapterDoneCount, chapterFailedCount, filteredChapters, openChapters, closeChapters,
    formatTime, formatClock, isBusinessError,
  };
}
