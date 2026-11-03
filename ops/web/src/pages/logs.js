import { ref, computed, onMounted, nextTick } from '../vue.js';
import { api } from '../api.js';
import { state, toast } from '../store.js';
import { usePolling, Card, Placeholder } from '../ui.js';
import { formatClock, taskStatusText } from '../utils.js';

const SOURCES = {
  gallery: { label: 'Gallery', path: '/API/ops/local/tasks' },
  comix: { label: 'Comix', path: '/API/comix/tasks' },
};

export default {
  components: { Card, Placeholder },
  setup() {
    const tasks = ref([]);
    const selectedKey = ref('');
    const detail = ref(null);
    const keyword = ref('');
    const autoScroll = ref(true);
    const listError = ref('');
    const detailError = ref('');
    const viewRef = ref(null);

    const selected = computed(() => tasks.value.find((item) => item.key === selectedKey.value) || null);

    const collect = async (signal) => {
      const results = await Promise.allSettled(Object.entries(SOURCES).map(async ([source, { path }]) => {
        const response = await api.get(path, { signal });
        return (response?.data?.tasks || []).map((task) => ({ ...task, source, key: `${source}:${task.id}` }));
      }));
      if (signal.aborted) return;

      const merged = results.flatMap((result) => result.value || []);
      listError.value = results.every((result) => result.status === 'rejected')
        ? results[0].reason.message : '';
      merged.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
      tasks.value = merged;
      if (!merged.some((item) => item.key === selectedKey.value)) {
        selectedKey.value = merged[0]?.key || '';
        detail.value = null;
      }
    };

    const loadDetail = async (signal) => {
      const task = selected.value;
      detailError.value = '';
      if (!task) {
        detail.value = null;
        return;
      }
      try {
        const data = await api.get(`${SOURCES[task.source].path}/${encodeURIComponent(task.id)}`, { signal });
        if (signal.aborted || task.key !== selectedKey.value) return;
        detail.value = data?.data || null;
      } catch (err) {
        if (!signal.aborted && task.key === selectedKey.value) detailError.value = err.message;
      }
      if (autoScroll.value) {
        await nextTick();
        if (viewRef.value) viewRef.value.scrollTop = viewRef.value.scrollHeight;
      }
    };

    const runningSelected = computed(() => selected.value?.status === 'running');
    const { trigger: refresh } = usePolling(async (signal) => {
      await collect(signal);
      if (!signal.aborted) await loadDetail(signal);
    }, { interval: () => 2, enabled: () => runningSelected.value });

    onMounted(refresh);
    const selectTask = (key) => {
      selectedKey.value = key;
      detail.value = null;
      detailError.value = '';
      refresh();
    };

    const lines = computed(() => {
      const logs = (detail.value && detail.value.logs) || [];
      const limit = state.settings.log_line_limit || 800;
      const sliced = logs.length > limit ? logs.slice(logs.length - limit) : logs;
      const word = keyword.value.trim().toLowerCase();
      if (!word) return sliced;
      return sliced.filter((item) => (item.text || '').toLowerCase().includes(word));
    });

    /** 模板里不用 `?.`：命令行与总行数在 setup 里算好（未选中任务时为空）。 */
    const commandText = computed(() => ((selected.value && selected.value.command) || '—'));
    const rawLineCount = computed(() => (((detail.value && detail.value.logs) || []).length));

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
      tasks, selectedKey, selected, keyword, autoScroll, lines, listError, detailError,
      viewRef, runningSelected, selectTask, refresh, copyAll, formatClock, taskStatusText, SOURCES,
      commandText, rawLineCount,
    };
  },
  template: `
    <div>
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
              <select :value="selectedKey" @change="selectTask($event.target.value)">
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
            <button class="ghost sm" style="margin-top: 16px" @click="refresh()">刷新</button>
          </div>

          <div class="small muted" style="margin-bottom: 8px">
            命令: <span class="mono">{{ commandText }}</span>
            <span v-if="keyword" class="badge warning" style="margin-left: 8px">
              过滤后 {{ lines.length }} 行（原 {{ rawLineCount }} 行）
            </span>
          </div>

          <Placeholder v-if="detailError" :error="'获取任务日志失败: ' + detailError" />
          <div v-else class="log-view" ref="viewRef" style="height: calc(100vh - 320px)">
            <div v-if="!lines.length" class="muted">暂无日志</div>
            <div v-for="(item, index) in lines" :key="index" :class="item.stream">
              [{{ formatClock(item.time) }}][{{ item.stream }}] {{ item.text }}
            </div>
          </div>
        </template>
      </Card>
    </div>`,
};
