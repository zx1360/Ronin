import { ref, computed, onMounted, onUnmounted, nextTick } from '../vue.js';
import { api } from '../api.js';
import { state, toast, confirmAction, navigate } from '../store.js';
import { usePolling, Card, Placeholder, Badge } from '../ui.js';
import { formatClock, formatTime, taskActive } from '../utils.js';
import { taskSummary, comixStatusText, comixStatusKind } from './comix/helpers.js';

const SOURCES = {
  gallery: { label: '媒体库', path: '/API/ops/local/tasks' },
  comix: { label: '漫画', path: '/API/comix/tasks' },
};

export default {
  components: { Card, Placeholder, Badge },
  setup() {
    const tasks = ref([]);
    const selectedKey = ref(new URLSearchParams(window.location.hash.split('?')[1]).get('task') || '');
    const detail = ref(null);
    const keyword = ref('');
    const autoScroll = ref(true);
    const listError = ref('');
    const detailError = ref('');
    const viewRef = ref(null);
    const outputRef = ref(null);
    const stopping = ref(false);

    const selected = computed(() => tasks.value.find((item) => item.key === selectedKey.value) || null);

    const collect = async (signal) => {
      const results = await Promise.allSettled(Object.entries(SOURCES).map(async ([source, { path }]) => {
        const response = await api.get(path, { signal });
        if (response?.ok === false) throw new Error(response.error || '无法读取任务');
        return (response?.data?.tasks || []).map((task) => ({ ...task, source, key: `${source}:${task.id}` }));
      }));
      if (signal.aborted) return;

      const sources = Object.keys(SOURCES);
      const merged = results.flatMap((result, i) => result.status === 'fulfilled' ? result.value : tasks.value.filter((item) => item.source === sources[i]));
      listError.value = results.flatMap((result, i) => result.status === 'rejected' ? [`${SOURCES[sources[i]].label}: ${result.reason.message}`] : []).join('；');
      merged.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
      tasks.value = merged;
      if (!selectedKey.value && merged.length) {
        selectedKey.value = merged[0]?.key || '';
        detail.value = null;
        history.replaceState(null, '', '#/tasks?task=' + encodeURIComponent(selectedKey.value));
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
        if (data?.ok === false) throw new Error(data.error || '无法读取任务详情');
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

    const runningSelected = computed(() => taskActive(selected.value?.status));
    const activeCount = computed(() => tasks.value.filter((item) => taskActive(item.status)).length);
    const { trigger: refresh } = usePolling(async (signal) => {
      await collect(signal);
      if (!signal.aborted) await loadDetail(signal);
    }, { interval: () => 2, enabled: () => activeCount.value > 0 });

    const syncSelection = () => {
      const key = new URLSearchParams(location.hash.split('?')[1]).get('task') || '';
      if (key !== selectedKey.value) {
        selectedKey.value = key;
        detail.value = null;
        detailError.value = '';
        refresh();
      }
    };
    onMounted(() => { refresh(); window.addEventListener('hashchange', syncSelection); });
    onUnmounted(() => window.removeEventListener('hashchange', syncSelection));
    const selectTask = async (key) => {
      selectedKey.value = key;
      detail.value = null;
      detailError.value = '';
      navigate('/tasks?task=' + encodeURIComponent(key));
      await refresh();
      await nextTick();
      outputRef.value?.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth', block: 'nearest' });
    };
    const stop = async () => {
      const task = selected.value;
      if (!task || stopping.value || !await confirmAction(`取消或中断「${task.name}」？`, { danger: true })) return;
      stopping.value = true;
      try {
        const response = await api.post(`${SOURCES[task.source].path}/${encodeURIComponent(task.id)}/stop`);
        if (response?.ok === false) throw new Error(response.error || '取消任务失败');
        await refresh();
        toast('已发送取消或中断请求', 'success');
      } catch (error) { toast(error.message, 'error'); }
      finally { stopping.value = false; }
    };

    const lines = computed(() => {
      const logs = (detail.value && detail.value.logs) || [];
      const limit = state.settings.log_line_limit || 800;
      const sliced = logs.length > limit ? logs.slice(logs.length - limit) : logs;
      const word = keyword.value.trim().toLowerCase();
      if (!word) return sliced;
      return sliced.filter((item) => (item.text || '').toLowerCase().includes(word));
    });

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
      tasks, selectedKey, selected, detail, keyword, autoScroll, lines, listError, detailError,
      viewRef, outputRef, runningSelected, selectTask, refresh, copyAll, formatClock, SOURCES,
      commandText, rawLineCount, activeCount, stop, stopping, formatTime, navigate, comixStatusText, comixStatusKind, summary: computed(() => taskSummary(detail.value)),
    };
  },
  template: `
    <div>
      <Card title="媒体与漫画任务">
        <template #actions>
          <span class="muted small">{{ activeCount ? activeCount + ' 项正在运行或排队' : '当前没有活动任务' }}</span>
          <button class="ghost sm" @click="refresh()">刷新任务</button>
        </template>
        <p class="small muted">任务与日志在服务重启后清空；媒体和漫画库中的数据会保留。AI 的持久处理队列在「AI 与检索」管理。</p>
        <Placeholder v-if="listError" :error="listError" />
        <div v-if="!tasks.length && !listError" class="placeholder">
          <p>还没有任务。可以导入媒体，或选择漫画开始下载。</p>
          <div class="row" style="justify-content: center">
            <button @click="navigate('/tasks?tab=gallery')">媒体库维护</button>
            <button class="ghost" @click="navigate('/comix')">漫画管理</button>
          </div>
        </div>
        <div class="task-list" v-if="tasks.length">
          <table class="data">
            <thead><tr><th>来源</th><th>任务</th><th>状态</th><th>提交时间</th><th></th></tr></thead>
            <tbody><tr v-for="task in tasks" :key="task.key" :class="{ 'selected-row': selectedKey === task.key }">
              <td>{{ SOURCES[task.source].label }}</td><td>{{ task.name }}</td>
              <td><Badge :kind="comixStatusKind(task)">{{ comixStatusText(task) }}</Badge></td><td>{{ formatTime(task.started_at) }}</td>
              <td><button class="ghost sm" @click="selectTask(task.key)">查看结果与日志</button></td>
            </tr></tbody>
          </table>
        </div>
      </Card>
      <div v-if="selected" class="task-output" ref="outputRef">
        <Card :title="selected.name">
          <template #actions>
            <Badge :kind="comixStatusKind(detail || selected)">{{ comixStatusText(detail || selected) }}</Badge>
            <button class="ghost sm" :disabled="!lines.length" @click="copyAll()">复制</button>
            <button class="danger sm" v-if="runningSelected" :disabled="stopping" @click="stop()">{{ selected.status === 'queued' ? '取消排队' : '中断任务' }}</button>
          </template>

          <p v-if="summary" class="small">{{ summary }}</p>
          <p v-if="detail && detail.error" class="placeholder error">{{ detail.error }}</p>
          <p v-if="selected && selected.status === 'queued'" class="muted small">正在等待前面的漫画写任务结束；尚未启动子进程，可随时取消排队。</p>
          <div class="row" style="margin-bottom: 12px">
            <label class="field" style="flex: 1; min-width: 200px">
              关键字过滤
              <input v-model="keyword" placeholder="只显示包含该关键字的行" />
            </label>
            <label class="row small muted" style="gap: 6px; padding-top: 16px">
              <input type="checkbox" v-model="autoScroll" /> 自动滚动到底部
            </label>
          </div>

          <details class="small muted" style="margin-bottom: 12px">
            <summary>执行信息</summary>
            <div class="mono">{{ commandText }}</div>
          </details>
          <span v-if="keyword" class="badge warning" style="margin-left: 8px">
            过滤后 {{ lines.length }} 行（原 {{ rawLineCount }} 行）
          </span>
          <Placeholder v-if="detailError" :error="'获取任务日志失败: ' + detailError" />
          <Placeholder v-else-if="!detail" text="正在加载任务结果…" />
          <Placeholder v-else-if="!lines.length" :text="keyword ? '没有匹配的日志' : '暂无日志'" />
          <div v-else class="log-view" ref="viewRef" style="max-height: 360px">
            <div v-for="(item, index) in lines" :key="index" :class="item.stream">
              [{{ formatClock(item.time) }}][{{ item.stream }}] {{ item.text }}
            </div>
          </div>
        </Card>
      </div>
      <Placeholder v-else-if="selectedKey && tasks.length" text="该任务已不可用，请在列表中重新选择。服务重启会清空任务历史。" />
    </div>`,
};
