// 媒体库维护任务的提交入口。
//
// 进程由服务端托管（/API/ops/local/tasks），页面只提交参数并观察状态；

import { ref, computed, onMounted } from '../vue.js';
import { api } from '../api.js';
import { state, navigate, toast, confirmAction } from '../store.js';
import { usePolling, Card } from '../ui.js';
import { taskActive } from '../utils.js';

const MODES = [
  { value: 'ingest', label: '导入新媒体', hint: '从 Raw 导入媒体，生成缩略图和预览图；成功入库后清理对应的 Raw 文件。' },
  { value: 'execute', label: '执行媒体变更', hint: '应用待处理的裁剪、旋转与视频剪辑；软删除的媒体移入 Deleted 目录。' },
  { value: 'refresh', label: '修复预览与缩略图', hint: '补齐或重建派生图片；原件缺失时报告问题并保留记录。' },
];

export default {
  components: { Card },
  emits: ['started'],
  setup(_, { emit }) {
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

    const load = async (signal) => {
      try {
        const data = await api.get('/API/ops/local/tasks', { signal });
        tasks.value = data?.data?.tasks || [];
        error.value = '';
      } catch (err) {
        if (!signal.aborted) error.value = err.message;
      }
    };

    const hasRunning = computed(() => tasks.value.some((task) => taskActive(task.status)));
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
        navigate(`/tasks?task=gallery:${encodeURIComponent(data?.data?.task_id || '')}`);
        emit('started');
      } catch (err) {
        toast(`启动失败: ${err.message}`, 'error');
      } finally {
        starting.value = false;
      }
    };

    return {
      state, form, tasks, error, starting, hasRunning, canStart, currentMode, MODES,
      start, poller,
    };
  },
  template: `
    <div>
      <Card title="媒体库维护">
        <template #actions>
          <span class="badge" :class="state.cli.gallery.available ? 'success' : 'error'">
            {{ state.cli.gallery.available ? '就绪' : '不可用' }}
          </span>
        </template>

        <div class="col">
          <p v-if="error" class="error">{{ error }}</p>
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


    </div>`,
};
