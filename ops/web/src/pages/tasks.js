// 任务管理：启动/中断 gallery CLI 任务（ingest / execute / refresh）。
//
// 进程由服务端托管（/API/ops/local/tasks），页面只提交参数并观察状态；
// Monarch 自身不再由运维端启动——服务端就是托管网页的那一方。

import { ref, computed, onMounted } from '../vue.js';
import { api } from '../api.js';
import { state, navigate, toast, confirmAction } from '../store.js';
import { usePolling, Card, Placeholder, TaskStatusBadge } from '../ui.js';
import { formatTime, formatDuration } from '../utils.js';

const MODES = [
  { value: 'ingest', label: 'ingest · 摄入 Raw 到媒体库', hint: '扫描 Raw 目录，生成缩略图/预览图并入库。' },
  { value: 'execute', label: 'execute · 执行删除', hint: '把标记为软删除的媒体移入 Deleted 目录。' },
  { value: 'refresh', label: 'refresh · 刷新修复', hint: '校验库内记录与文件，清理无效源记录并可重建缩略图/预览图。' },
];

export default {
  components: { Card, Placeholder, TaskStatusBadge },
  setup() {
    const form = ref({
      mode: 'ingest',
      concurrency: 10,
      batch: 160,
      resize: 0,
      resizePreview: 0,
      resizeThumb: 0,
    });
    const tasks = ref([]);
    const error = ref('');
    const starting = ref(false);

    const load = async () => {
      try {
        const data = await api.get('/API/ops/local/tasks');
        tasks.value = data?.data?.tasks || [];
        error.value = '';
      } catch (err) {
        error.value = err.message;
      }
    };

    const hasRunning = computed(() => tasks.value.some((task) => task.status === 'running'));
    // enabled 只在"有任务在跑"时为真，因此每次操作后都必须经 poller.trigger() 走一遍：
    // 它才是那个会按 enabled 续期轮询的入口，直接调 load() 会让页面停在启动前的快照上。
    const poller = usePolling(load, { interval: () => 2, enabled: () => hasRunning.value });
    onMounted(() => poller.trigger());

    const currentMode = computed(() => MODES.find((item) => item.value === form.value.mode) || MODES[0]);
    const canStart = computed(() => state.cli.gallery.available && !hasRunning.value && !starting.value);

    const start = async () => {
      if (hasRunning.value) {
        toast('已有 Gallery 任务在运行，请先等待或中断', 'error');
        return;
      }
      const mode = currentMode.value;
      const ok = await confirmAction(
        `即将执行「${mode.label}」。\n${mode.hint}\n\n媒体库根目录: ${state.paths.galleryDir}`,
        { title: '确认执行 Gallery 任务', danger: true },
      );
      if (!ok) return;

      starting.value = true;
      try {
        // resize 系列只在 refresh 模式合法：其它模式带上会被服务端判为非法参数
        const payload = {
          mode: form.value.mode,
          concurrency: form.value.concurrency,
          batch: form.value.batch,
        };
        if (form.value.mode === 'refresh') {
          payload.resize = form.value.resize;
          payload.resizePreview = form.value.resizePreview;
          payload.resizeThumb = form.value.resizeThumb;
        }
        const data = await api.post('/API/ops/local/tasks', payload, { timeoutMs: 20000 });
        toast(`任务已启动: ${data?.data?.task_id || ''}`, 'success');
        await poller.trigger();
      } catch (err) {
        toast(`启动失败: ${err.message}`, 'error');
      } finally {
        starting.value = false;
      }
    };

    const stop = async (task) => {
      const ok = await confirmAction(`中断任务「${task.name}」(${task.id})？`, { title: '确认中断', danger: true });
      if (!ok) return;
      try {
        await api.post(`/API/ops/local/tasks/${task.id}/stop`);
        toast('已发送中断命令', 'success');
        await poller.trigger();
      } catch (err) {
        toast(`中断失败: ${err.message}`, 'error');
      }
    };

    const duration = (task) => {
      const end = task.finished_at ? new Date(task.finished_at) : new Date();
      return formatDuration(end - new Date(task.started_at));
    };

    /** 退出码文案：未结束/未记录时显示占位符（模板里不用 ??）。 */
    const exitCodeText = (task) => (
      task.exit_code === null || task.exit_code === undefined ? '—' : String(task.exit_code)
    );

    return {
      state, form, tasks, error, starting, hasRunning, canStart, currentMode, MODES,
      start, stop, poller, duration, exitCodeText, formatTime, navigate,
    };
  },
  template: `
    <div>
      <Card title="Gallery CLI">
        <template #actions>
          <span class="badge" :class="state.cli.gallery.available ? 'success' : 'error'">
            {{ state.cli.gallery.available ? '就绪' : '不可用' }}
          </span>
        </template>

        <div class="col">
          <div class="mono muted">{{ state.cli.gallery.path }}</div>
          <div class="small" style="color: var(--warning)" v-if="!state.cli.gallery.available">
            {{ state.cli.gallery.message }}
          </div>
          <div class="small muted">媒体库根目录: <span class="mono">{{ state.paths.galleryDir }}</span></div>

          <div class="grid cols-3">
            <label class="field">
              运行模式
              <select v-model="form.mode">
                <option v-for="item in MODES" :key="item.value" :value="item.value">{{ item.label }}</option>
              </select>
            </label>
            <label class="field">
              并发数 (1-64)
              <input type="number" min="1" max="64" v-model.number="form.concurrency" />
            </label>
            <label class="field">
              批量大小 (1-5000)
              <input type="number" min="1" max="5000" v-model.number="form.batch" />
            </label>
          </div>

          <div class="small muted">{{ currentMode.hint }}</div>

          <div class="grid cols-3" v-if="form.mode === 'refresh'">
            <label class="field">
              预览图最大边（0 = 不重建）
              <input type="number" min="0" max="16384" v-model.number="form.resize" />
            </label>
            <label class="field">
              单独设置预览图最大边
              <input type="number" min="0" max="16384" v-model.number="form.resizePreview" />
            </label>
            <label class="field">
              缩略图边长
              <input type="number" min="0" max="16384" v-model.number="form.resizeThumb" />
            </label>
          </div>

          <div class="row">
            <button class="primary" :disabled="!canStart" @click="start()">
              {{ starting ? '启动中…' : '启动任务' }}
            </button>
            <span class="small" style="color: var(--warning)" v-if="hasRunning">已有任务在运行</span>
          </div>
        </div>
      </Card>

      <Card title="Gallery 任务">
        <template #actions>
          <button class="ghost sm" @click="poller.trigger()">刷新</button>
        </template>
        <Placeholder v-if="error" :error="'获取任务列表失败: ' + error" />
        <Placeholder v-else-if="!tasks.length" text="暂无任务" />
        <table class="data" v-else>
          <thead>
            <tr>
              <th>任务</th><th>状态</th><th>PID</th><th>开始</th><th>耗时</th><th>退出码</th><th>命令</th><th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="task in tasks" :key="task.id">
              <td>
                {{ task.name }}
                <div class="small muted" v-if="task.error" style="color: var(--error)">{{ task.error }}</div>
              </td>
              <td><TaskStatusBadge :status="task.status" /></td>
              <td>{{ task.pid || '—' }}</td>
              <td class="small">{{ formatTime(task.started_at, false) }}</td>
              <td class="small">{{ duration(task) }}</td>
              <td>{{ exitCodeText(task) }}</td>
              <td class="mono muted">{{ task.command }}</td>
              <td class="row">
                <button class="ghost sm" @click="navigate('/logs')">日志</button>
                <button class="danger sm" v-if="task.status === 'running'" @click="stop(task)">中断</button>
              </td>
            </tr>
          </tbody>
        </table>
      </Card>
    </div>`,
};
