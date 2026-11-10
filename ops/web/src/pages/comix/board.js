import { ref, computed, onMounted } from '../../vue.js';
import { api, assetUrl } from '../../api.js';
import { state, toast, confirmAction } from '../../store.js';
import { usePolling } from '../../ui.js';
import { taskActive } from '../../utils.js';
import {
  chapterStatusKind,
  chapterStatusText,
  normalizeSubmit,
  submitResultView,
  validateLatest,
  validateRange,
} from './helpers.js';

/** 建立漫画页的共享状态；必须在组件的 setup() 中调用（内部注册 onMounted/onUnmounted）。 */
export function useComixBoard() {
  const unwrap = (payload) => payload.data;

  // ---- comix 集成可用性 ----

  const config = ref(null);
  const configError = ref('');
  const initRunning = ref(false);

  const loadConfig = async () => {
    try {
      config.value = unwrap(await api.get('/API/comix/config'));
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
      const data = unwrap(await api.post('/API/comix/init', {}, { timeoutMs: 120000 }));
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
      const data = unwrap(await api.get('/API/comix/sites'));
      sites.value = Array.isArray(data.sites) ? data.sites : [];
      sitesError.value = '';
    } catch (err) {
      sites.value = [];
      sitesError.value = err.message;
    }
  };

  // 网址提交结果只轮询任务摘要，详情统一在任务中心查看。

  const tasks = ref([]);
  const tasksError = ref('');
  /** 已提交但尚未出现在后端列表里的任务，用于兜底轮询。 */
  const pendingIds = ref([]);
  let pendingRounds = 0;

  const loadTasks = async (signal) => {
    try {
      const data = unwrap(await api.get('/API/comix/tasks', { signal }));
      if (signal.aborted) return;
      const list = Array.isArray(data.tasks) ? data.tasks : [];
      tasks.value = list;
      tasksError.value = '';
      const ids = new Set(list.map((item) => item.id));
      pendingIds.value = pendingIds.value.filter((id) => !ids.has(id));
    } catch (err) {
      if (!signal.aborted) tasksError.value = err.message;
    }
  };

  const runningCount = computed(() => tasks.value.filter((item) => taskActive(item.status)).length);
  const hasWork = computed(() => runningCount.value > 0 || pendingIds.value.length > 0);

  const poller = usePolling(async (signal) => {
    await loadTasks(signal);
    if (signal.aborted) return;
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
  }, { interval: () => 2, enabled: () => hasWork.value });

  /** 登记刚提交的任务，并立刻启动/续期轮询。 */
  const trackSubmitted = async (ids) => {
    const list = (ids || []).filter(Boolean);
    if (list.length) {
      pendingIds.value = Array.from(new Set([...pendingIds.value, ...list]));
      pendingRounds = 0;
    }
    await poller.trigger();
  };

  /** 启动一个异步 comix 任务，返回 task_id。 */
  const startTask = async (endpoint, body, label) => {
    const data = unwrap(await api.post(`/API/comix/${endpoint}`, body, { timeoutMs: 60000 }));
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
      const data = unwrap(await api.post('/API/comix/download-url', body, { timeoutMs: 60000 }));
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
      const data = unwrap(await api.get('/API/comix/list'));
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

  const togglePublic = async (comic) => {
    const next = comic.is_public !== true;
    const ok = await confirmAction(`将「${comic.title}」设为${next ? '公开' : '隐藏'}？`, {
      title: '更新书库管理字段',
    });
    if (!ok) return;
    try {
      await api.put(`/API/comic/comic-info/${comic.comic_id}`, { is_public: next });
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
      await api.put(`/API/comic/comic-info/${comic.comic_id}`, { readed: next });
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
      const data = unwrap(await api.get(`/API/comix/chapters/${comic.comic_id}`));
      if (chaptersComic.value?.comic_id !== comic.comic_id) return;
      chapters.value = Array.isArray(data.chapters) ? data.chapters : [];
    } catch (err) {
      if (chaptersComic.value?.comic_id === comic.comic_id) chaptersError.value = err.message;
    } finally {
      if (chaptersComic.value?.comic_id === comic.comic_id) chaptersLoading.value = false;
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

  const onTabChange = (name) => {
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
    tasksError,
    urlInput, latestInput, submitting, submitResults, submitUrls,
    comics, comicsError, comicsLoading, keyword, statusFilter, filteredComics, loadComics,
    checkDownload, checkLatest, runUpdateCheck, runClean,
    downloadTarget, downloadForm, downloadError, openDownload, submitDownload,
    togglePublic, toggleReaded, removeComic,
    chaptersComic, chapters, chaptersError, chaptersLoading, chapterKeyword,
    chapterDoneCount, chapterFailedCount, filteredChapters, openChapters, closeChapters,
  };
}
