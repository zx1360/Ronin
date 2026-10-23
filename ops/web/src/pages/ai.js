// AI 媒体处理：能力就绪与进度、任务队列、人物分组、检索、近重复与软删除。
//
// 进入/手动刷新时取诊断与配置；活动期间仅轮询 /API/ai/progress。
// 各标签页只在被选中时挂载，自带加载与空态提示。

import { ref, computed, watch, onMounted, onUnmounted } from '../vue.js';
import { api } from '../api.js';
import { state, toast } from '../store.js';
import { usePolling } from '../ui.js';
import OverviewTab from './ai/overview.js';
import JobsTab from './ai/jobs.js';
import PersonsTab from './ai/persons.js';
import SearchTab from './ai/search.js';
import DuplicatesTab from './ai/duplicates.js';
import DeletedTab from './ai/deleted.js';
import { mergeProgress } from './ai/state.js';

const TABS = [
  { key: 'overview', label: '概览' },
  { key: 'jobs', label: '任务' },
  { key: 'persons', label: '人物' },
  { key: 'search', label: '检索' },
  { key: 'duplicates', label: '去重' },
  { key: 'deleted', label: '已删除' },
];

export default {
  components: {
    OverviewTab, JobsTab, PersonsTab, SearchTab, DuplicatesTab, DeletedTab,
  },
  setup() {
    const tab = ref('overview');
    const status = ref(null);
    const runtime = ref(null);
    const error = ref('');
    const pollError = ref('');
    const loading = ref(false);
    const busy = ref(false);

    const disabled = computed(() => !!status.value && status.value.enabled === false);
    const schemaMissing = computed(() => {
      if (!status.value) return false;
      return status.value.schema_ready === false;
    });
    const capabilities = computed(() => status.value?.capabilities || []);
    const controller = new AbortController();
    let disposed = false;
    onUnmounted(() => { disposed = true; controller.abort(); });

    /** 是否还有值得持续观察的活动（排队中/批次执行中/侧车或自拉 Ollama 在跑）。 */
    const active = computed(() => {
      const source = status.value;
      if (!source) return false;
      if (source.sidecars?.some((sidecar) => sidecar.running)) return true;
      if (Array.isArray(source.capabilities) && source.capabilities.some(
        (cap) => cap && cap.sidecar && cap.sidecar.running === true,
      )) return true;
      if (source.last_run && source.last_run.running === true) return true;
      if (source.paused === true) return false;
      if (Number(source.pending_total) > 0) return true;
      return !!(source.ollama && source.ollama.owned_server === true);
    });

    /** 拉取一次页面状态；silent 用于轮询，失败只在角落里小声提示，不打扰也不刷屏。 */
    let inFlight = false;
    let pendingRefresh = null;
    const load = async (options) => {
      const silent = !!(options && options.silent);
      if (inFlight) {
        if (!silent) pendingRefresh = { refresh: pendingRefresh?.refresh || options?.refresh };
        return;
      }
      inFlight = true;
      // 轮询不切换「刷新中…」，避免每几秒闪一次
      if (!silent) loading.value = true;
      const results = await Promise.allSettled([
        api.get(silent ? '/API/ai/progress' : `/API/ai/status${options?.refresh ? '?refresh=true' : ''}`, { signal: controller.signal }),
        ...(!silent ? [api.get('/API/ai/settings', { signal: controller.signal })] : []),
      ]);
      if (disposed) return;
      const [statusResult, settingsResult] = results;

      if (statusResult.status === 'fulfilled') {
        status.value = silent ? mergeProgress(status.value, statusResult.value) : statusResult.value;
        error.value = '';
        pollError.value = '';
      } else {
        const reason = statusResult.reason;
        const message = reason && reason.message ? reason.message : '状态接口不可用';
        // 503 = AI 表未初始化或处理层未装配，给明确提示而不是反复静默重试
        if (reason && reason.status === 503) error.value = message;
        else if (silent) pollError.value = message;
        else error.value = message;
      }

      if (settingsResult?.status === 'fulfilled') runtime.value = settingsResult.value || null;

      inFlight = false;
      loading.value = false;
      if (pendingRefresh) {
        const pending = pendingRefresh;
        pendingRefresh = null;
        await load(pending);
      }
    };

    // AI 关闭时一个请求都不再发出（状态里 enabled=false 即可判定），也不做任何重试
    const poller = usePolling(() => {
      if (disabled.value) return null;
      return load({ silent: true });
    }, {
      interval: () => state.settings.ai_refresh_seconds || 3,
      enabled: () => !disabled.value && active.value,
    });

    const reload = async () => {
      await load({ refresh: true });
      return poller.trigger();
    };

    onMounted(async () => { await load(); poller.trigger(); });
    watch(active, (value) => {
      if (value && !disabled.value) poller.trigger();
    });
    watch(() => status.value?.pending_total, (next, previous) => {
      if (next === 0 && previous > 0 && !disabled.value) load();
    });

    /** 统一的动作通道：忙标记 + 成功提示 + 重新拉取状态；失败提示具体原因。 */
    const run = async (notice, action) => {
      if (busy.value) return false;
      busy.value = true;
      try {
        const result = await action();
        if (notice) toast(notice, 'success');
        await load();
        poller.trigger();
        return result === undefined ? true : result;
      } catch (err) {
        toast('操作失败: ' + (err && err.message ? err.message : String(err)), 'error');
        return false;
      } finally {
        busy.value = false;
      }
    };

    return {
      TABS, tab, status, runtime, capabilities, error, pollError, loading, busy,
      disabled, schemaMissing, active, reload, run,
    };
  },
  template: `
    <div>
      <div class="row between">
        <div class="row">
          <span class="small muted" v-if="loading">刷新中…</span>
          <span class="small muted" v-if="!active && status && !disabled">无排队任务，已停止轮询</span>
        </div>
      </div>

      <div class="tabs">
        <button
          v-for="item in TABS"
          :key="item.key"
          :class="{ active: tab === item.key }"
          @click="tab = item.key"
        >{{ item.label }}</button>
      </div>

      <OverviewTab
        v-if="tab === 'overview'"
        :status="status"
        :capabilities="capabilities"
        :runtime="runtime"
        :error="error"
        :busy="busy"
        :ai-disabled="disabled"
        :schema-missing="schemaMissing"
        :poll-error="pollError"
        :run="run"
        :refresh="reload"
      />
      <JobsTab
        v-else-if="tab === 'jobs'"
        :capabilities="capabilities"
        :ai-disabled="disabled"
        :active="active"
      />
      <PersonsTab v-else-if="tab === 'persons'" :ai-disabled="disabled" />
      <SearchTab v-else-if="tab === 'search'" :ai-disabled="disabled" />
      <DuplicatesTab v-else-if="tab === 'duplicates'" :ai-disabled="disabled" />
      <DeletedTab v-else :ai-disabled="disabled" />
    </div>`,
};
