// AI 媒体处理：能力就绪与进度、任务队列、人物分组、检索、近重复与软删除。
//
// 页面只负责装配与「按需轮询」：状态来自 /API/ai/status（配合 /API/ai/capabilities
// 与 /API/ai/settings），只有确实有排队/运行中的任务或模型进程在跑时才定时刷新；
// 各标签页只在被选中时挂载，自带加载与空态提示。

import { ref, computed, watch, onMounted } from '../vue.js';
import { api } from '../api.js';
import { state, toast } from '../store.js';
import { usePolling } from '../ui.js';
import OverviewTab from './ai/overview.js';
import JobsTab from './ai/jobs.js';
import PersonsTab from './ai/persons.js';
import SearchTab from './ai/search.js';
import DuplicatesTab from './ai/duplicates.js';
import DeletedTab from './ai/deleted.js';

const TABS = [
  { key: 'overview', label: '概览' },
  { key: 'jobs', label: '任务' },
  { key: 'persons', label: '人物' },
  { key: 'search', label: '检索' },
  { key: 'duplicates', label: '去重' },
  { key: 'deleted', label: '已删除' },
];

/** 状态里缺 capabilities 段时（如尚未启动 worker）退回 /API/ai/capabilities。 */
function capList(status, fallback) {
  const fromStatus = status && Array.isArray(status.capabilities) ? status.capabilities : [];
  if (fromStatus.length) return fromStatus;
  return Array.isArray(fallback) ? fallback : [];
}

export default {
  components: {
    OverviewTab, JobsTab, PersonsTab, SearchTab, DuplicatesTab, DeletedTab,
  },
  setup() {
    const tab = ref('overview');
    const status = ref(null);
    const runtime = ref(null);
    const fallbackCapabilities = ref([]);
    const error = ref('');
    const pollError = ref('');
    const loading = ref(false);
    const busy = ref(false);

    const disabled = computed(() => !!status.value && status.value.enabled === false);
    const schemaMissing = computed(() => {
      if (!status.value) return false;
      return status.value.schema_ready === false;
    });
    const capabilities = computed(() => capList(status.value, fallbackCapabilities.value));

    /** 是否还有值得持续观察的活动（排队中/批次执行中/侧车或自拉 Ollama 在跑）。 */
    const active = computed(() => {
      const source = status.value;
      if (!source) return false;
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
    const load = async (options) => {
      const silent = !!(options && options.silent);
      if (inFlight) return;
      inFlight = true;
      // 轮询不切换「刷新中…」，避免每几秒闪一次
      if (!silent) loading.value = true;
      const results = await Promise.allSettled([
        api.get('/API/ai/status', { timeoutMs: 60000 }),
        api.get('/API/ai/settings'),
        api.get('/API/ai/capabilities'),
      ]);
      const [statusResult, settingsResult, capsResult] = results;

      if (statusResult.status === 'fulfilled') {
        status.value = statusResult.value || null;
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

      if (settingsResult.status === 'fulfilled') runtime.value = settingsResult.value || null;

      if (capsResult.status === 'fulfilled') {
        const data = capsResult.value || {};
        fallbackCapabilities.value = Array.isArray(data.capabilities) ? data.capabilities : [];
        // 能力契约也带配置段：设置接口不可用时用它兜底显示处理配置
        if (!runtime.value && data.settings) runtime.value = data.settings;
      } else {
        fallbackCapabilities.value = [];
      }

      inFlight = false;
      loading.value = false;
    };

    // AI 关闭时一个请求都不再发出（状态里 enabled=false 即可判定），也不做任何重试
    const poller = usePolling(() => {
      if (disabled.value) return null;
      return load({ silent: true });
    }, {
      interval: () => state.settings.ai_refresh_seconds || 3,
      enabled: () => !disabled.value && active.value,
    });

    const reload = () => {
      if (disabled.value) return undefined;
      return poller.trigger();
    };

    onMounted(() => poller.trigger());
    watch(active, (value) => {
      if (value && !disabled.value) poller.trigger();
    });

    /** 统一的动作通道：忙标记 + 成功提示 + 重新拉取状态；失败提示具体原因。 */
    const run = async (notice, action) => {
      if (busy.value) return false;
      busy.value = true;
      try {
        const result = await action();
        if (notice) toast(notice, 'success');
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
