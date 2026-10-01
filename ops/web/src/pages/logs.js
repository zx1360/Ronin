// 日志：查看 gallery CLI 与 comix 爬虫任务的实时输出。
//
// 两类任务分别由 /API/ops/local/tasks 与 /API/comix/tasks 托管，这里统一成
// 一个下拉列表；只在选中任务仍在运行时轮询详情，落定后停止。

import { ref, computed, onMounted, nextTick, watch } from '../vue.js';
import { api } from '../api.js';
import { state, toast } from '../store.js';
import { usePolling, Card, Placeholder, TaskStatusBadge } from '../ui.js';
import { formatClock, taskStatusText } from '../utils.js';

const SOURCES = {
  gallery: { label: 'Gallery', detail: (id) => `/API/ops/local/tasks/${id}` },
  comix: { label: 'Comix', detail: (id) => `/API/comix/tasks/${id}` },
};

export default {
  components: { Card, Placeholder, TaskStatusBadge },
  setup() {
    const tasks = ref([]);
    const selectedKey = ref('');
    const detail = ref(null);
    const keyword = ref('');
    const autoScroll = ref(true);
    const listError = ref('');
    const viewRef = ref(null);

    const selected = computed(() => tasks.value.find((item) => item.key === selectedKey.value) || null);

    const collect = async () => {
      const merged = [];
      const results = await Promise.allSettled([
        api.get('/API/ops/local/tasks'),
        api.get('/API/comix/tasks'),
      ]);

      const [galleryResult, comixResult] = results;
      if (galleryResult.status === 'fulfilled') {
        for (const task of galleryResult.value?.data?.tasks || []) {
          merged.push({ ...task, source: 'gallery', key: `gallery:${task.id}` });
        }
      }
      if (comixResult.status === 'fulfilled') {
        for (const task of comixResult.value?.data?.tasks || []) {
          merged.push({ ...task, source: 'comix', key: `comix:${task.id}` });
        }
      }
      if (galleryResult.status === 'rejected' && comixResult.status === 'rejected') {
        listError.value = galleryResult.reason?.message || '任务列表不可用';
      } else {
        listError.value = '';
      }

      merged.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
      tasks.value = merged;
      if (!merged.some((item) => item.key === selectedKey.value)) {
        selectedKey.value = merged[0]?.key || '';
      }
    };

    const loadDetail = async () => {
      const task = selected.value;
      if (!task) {
        detail.value = null;
        return;
      }
      try {
        const data = await api.get(SOURCES[task.source].detail(task.id));
        detail.value = data?.data || null;
        listError.value = '';
      } catch (err) {
        listError.value = err.message;
      }
      if (autoScroll.value) {
        await nextTick();
        if (viewRef.value) viewRef.value.scrollTop = viewRef.value.scrollHeight;
      }
    };

    const runningSelected = computed(() => selected.value?.status === 'running');
    const poller = usePolling(async () => {
      await collect();
      await loadDetail();
    }, { interval: () => 2, enabled: () => runningSelected.value });

    onMounted(() => poller.trigger());
    watch(selectedKey, () => {
      detail.value = null;
      loadDetail();
      if (runningSelected.value) poller.trigger();
    });

    const lines = computed(() => {
      const logs = detail.value?.logs || [];
      const limit = state.settings.log_line_limit || 800;
      const sliced = logs.length > limit ? logs.slice(logs.length - limit) : logs;
      const word = keyword.value.trim().toLowerCase();
      if (!word) return sliced;
      return sliced.filter((item) => (item.text || '').toLowerCase().includes(word));
    });

    const copyAll = async () => {
      const text = lines.value
        .map((item) => `[${formatClock(item.time)}][${item.stream}] ${item.text}`)
        .join('\n');
      try {
        await navigator.clipboard.writeText(text);
        toast('日志已复制到剪贴板', 'success');
      } catch (err) {
        toast(`复制失败: ${err.message}`, 'error');
      }
    };

    return {
      state, tasks, selectedKey, selected, detail, keyword, autoScroll, lines, listError,
      viewRef, runningSelected, loadDetail, copyAll, formatClock, taskStatusText, SOURCES,
    };
  },
  template: `
    <div>
      <h1 class="page-title">日志</h1>

      <Card title="任务输出">
        <template #actions>
          <span class="badge" v-if="selected" :class="runningSelected ? 'info' : ''">
            {{ taskStatusText(selected.status) }}
          </span>
          <button class="ghost sm" :disabled="!lines.length" @click="copyAll()">复制</button>
        </template>

        <Placeholder v-if="listError" :error="'获取任务列表失败: ' + listError" />
        <Placeholder v-else-if="!tasks.length" text="暂无任务：请先在任务管理或漫画页提交任务" />

        <template v-else>
          <div class="row" style="margin-bottom: 12px">
            <label class="field" style="min-width: 300px">
              任务
              <select v-model="selectedKey">
                <option v-for="task in tasks" :key="task.key" :value="task.key">
                  [{{ SOURCES[task.source].label }}] {{ task.name }} · {{ taskStatusText(task.status) }}
                </option>
              </select>
            </label>
            <label class="field" style="flex: 1; min-width: 200px">
              关键字过滤
              <input v-model="keyword" placeholder="只显示包含该关键字的行" />
            </label>
            <label class="row small muted" style="gap: 6px; padding-top: 16px">
              <input type="checkbox" v-model="autoScroll" /> 自动滚动到底部
            </label>
            <button class="ghost sm" style="margin-top: 16px" @click="loadDetail()">刷新</button>
          </div>

          <div class="small muted" style="margin-bottom: 8px">
            命令: <span class="mono">{{ selected?.command }}</span>
            <span v-if="keyword" class="badge warning" style="margin-left: 8px">
              过滤后 {{ lines.length }} 行（原 {{ (detail?.logs || []).length }} 行）
            </span>
          </div>

          <div class="log-view" ref="viewRef" style="height: calc(100vh - 320px)">
            <div v-if="!lines.length" class="muted">暂无日志</div>
            <div v-for="(item, index) in lines" :key="index" :class="item.stream">
              [{{ formatClock(item.time) }}][{{ item.stream }}] {{ item.text }}
            </div>
          </div>
        </template>
      </Card>
    </div>`,
};
