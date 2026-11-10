import { ref, computed, onMounted } from '../vue.js';
import { api } from '../api.js';
import { state, navigate, toast, confirmAction } from '../store.js';
import { usePolling, Card } from '../ui.js';
import { taskActive } from '../utils.js';

const MODES = [
  { value: 'ingest', label: '导入新媒体', action: '开始导入', hint: '从 Raw 导入媒体，生成缩略图和预览图；成功入库后清理对应的 Raw 文件。' },
  { value: 'execute', label: '执行媒体变更', action: '应用变更', hint: '应用待处理的裁剪、旋转与视频剪辑；软删除的媒体移入 Deleted 目录。' },
  { value: 'refresh', label: '修复预览与缩略图', action: '开始修复', hint: '补齐或重建派生图片；原件缺失时报告问题并保留记录。' },
];

export default {
  components: { Card },
  props: { form: { type: Object, required: true } },
  setup(props) {
    const tasks = ref([]);
    const error = ref('');
    const starting = ref(false);
    const loading = ref(true);

    const load = async (signal) => {
      try {
        const data = await api.get('/API/ops/local/tasks', { signal });
        tasks.value = data?.data?.tasks || [];
        error.value = '';
      } catch (err) {
        if (!signal.aborted) error.value = err.message;
      } finally { loading.value = false; }
    };

    const hasRunning = computed(() => tasks.value.some((task) => taskActive(task.status)));
    const poller = usePolling(load, { interval: () => 2, enabled: () => hasRunning.value });
    onMounted(() => poller.trigger());

    const currentMode = computed(() => MODES.find((item) => item.value === props.form.mode) || MODES[0]);
    const canStart = computed(() => state.cli.gallery.available && !loading.value && !error.value && !hasRunning.value && !starting.value);

    const start = async () => {
      if (!canStart.value) return;
      starting.value = true;
      const mode = currentMode.value;
      try {
        const ok = await confirmAction(
          `即将执行「${mode.label}」。\n${mode.hint}\n\n媒体库根目录: ${state.paths.galleryDir}`,
          { title: '确认媒体库维护', danger: true },
        );
        if (!ok) return;
        const form = props.form;
        const payload = {
          mode: form.mode,
          concurrency: form.concurrency,
          batch: form.batch,
        };
        if (form.mode === 'refresh') {
          payload.resizePreview = form.resizePreview;
          payload.resizeThumb = form.resizeThumb;
        }
        const data = await api.post('/API/ops/local/tasks', payload, { timeoutMs: 20000 });
        if (!data?.data?.task_id) throw new Error(data?.error || '未收到任务编号');
        toast(`任务已启动: ${data?.data?.task_id || ''}`, 'success');
        navigate(`/tasks?task=gallery:${encodeURIComponent(data?.data?.task_id || '')}`);
      } catch (err) {
        toast(`启动失败: ${err.message}`, 'error');
      } finally {
        starting.value = false;
      }
    };

    return {
      state, tasks, error, loading, starting, hasRunning, canStart, currentMode, MODES,
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

        <form class="col" @submit.prevent="start">
          <div v-if="error" class="row error">{{ error }} <button type="button" class="ghost sm" @click="poller.trigger()">重试</button></div>
          <div class="small" style="color: var(--warning)" v-if="!state.cli.gallery.available">
            {{ state.cli.gallery.message }}
          </div>
          <div class="small muted">媒体库根目录: <span class="mono">{{ state.paths.galleryDir }}</span></div>

          <label class="field" style="max-width: 480px">
            运行模式
            <select v-model="form.mode">
              <option v-for="item in MODES" :key="item.value" :value="item.value">{{ item.label }}</option>
            </select>
          </label>
          <div class="small muted">{{ currentMode.hint }}</div>

          <details @invalid.capture="$event.currentTarget.open = true">
            <summary>高级设置</summary>
            <div class="grid cols-2">
              <label class="field">
                并发数 (1-64)
                <input type="number" min="1" max="64" required v-model.number="form.concurrency" />
              </label>
              <label class="field">
                批量大小 (1-5000)
                <input type="number" min="1" max="5000" required v-model.number="form.batch" />
              </label>
            </div>

            <div class="grid cols-2" v-if="form.mode === 'refresh'" style="margin-top: 12px">
              <label class="field">
                预览图最大边（0 = 不重建）
                <input type="number" min="0" max="16384" required v-model.number="form.resizePreview" />
              </label>
              <label class="field">
                缩略图边长（0 = 不重建）
                <input type="number" min="0" max="16384" required v-model.number="form.resizeThumb" />
              </label>
            </div>
          </details>

          <div class="row">
            <button class="primary" :disabled="!canStart">
              {{ starting ? '启动中…' : currentMode.action }}
            </button>
            <span class="small" style="color: var(--warning)" v-if="hasRunning">已有任务在运行</span>
          </div>
        </form>
      </Card>
    </div>`,
};
