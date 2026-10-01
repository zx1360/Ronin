// 任务队列：/API/ai/jobs 的列表与进度，按能力/状态过滤，支持一键重试失败项。
//
// 能力过滤项来自服务端状态（capabilities），端上不硬编码能力清单。

import { ref, computed, watch, onMounted } from '../../vue.js';
import { api } from '../../api.js';
import { state, toast } from '../../store.js';
import { usePolling, Card, Placeholder, Badge } from '../../ui.js';
import { formatTime } from '../../utils.js';
import { capabilityLabel, jobStatusKind, jobStatusText, num } from './shared.js';

const STATUS_OPTIONS = [
  { value: '', label: '全部' },
  { value: 'pending', label: '待处理' },
  { value: 'running', label: '执行中' },
  { value: 'done', label: '已完成' },
  { value: 'failed', label: '失败' },
];

export default {
  components: { Card, Placeholder, Badge },
  props: {
    capabilities: { type: Array, default: () => [] },
    aiDisabled: { type: Boolean, default: false },
    active: { type: Boolean, default: false },
  },
  setup(props) {
    const jobs = ref([]);
    const total = ref(0);
    const capability = ref('');
    const status = ref('');
    const error = ref('');
    const loading = ref(false);
    const retrying = ref(false);

    const load = async () => {
      loading.value = true;
      const params = ['limit=200', 'offset=0'];
      if (capability.value) params.push('capability=' + encodeURIComponent(capability.value));
      if (status.value) params.push('status=' + encodeURIComponent(status.value));
      try {
        const data = await api.get('/API/ai/jobs?' + params.join('&'));
        jobs.value = Array.isArray(data && data.jobs) ? data.jobs : [];
        total.value = num(data && data.total);
        error.value = '';
      } catch (err) {
        error.value = err.message;
      } finally {
        loading.value = false;
      }
    };

    // 只有确实有活可看（有排队/运行中的任务）时才轮询
    const poller = usePolling(load, {
      interval: () => state.settings.ai_refresh_seconds || 3,
      enabled: () => props.active && !props.aiDisabled,
    });
    onMounted(() => poller.trigger());
    watch(() => props.active, (value) => {
      if (value) poller.trigger();
    });

    const capabilityOptions = computed(() => (props.capabilities || []).map((cap) => ({
      value: (cap && cap.capability) || '',
      label: (cap && (cap.label || cap.capability)) || '',
    })));

    const rows = computed(() => jobs.value.map((job) => ({
      id: String(job.id),
      capability: job.capability || '',
      capabilityLabel: capabilityLabel(props.capabilities, job.capability),
      status: job.status || '',
      statusText: jobStatusText(job.status),
      statusKind: jobStatusKind(job.status),
      mediaId: job.media_id || '',
      mediaShort: String(job.media_id || '').slice(0, 8),
      attempts: num(job.attempts),
      inputSig: job.input_sig || '',
      lastError: job.last_error || '',
      created: formatTime(job.created_at, false),
    })));

    const retryFailed = async () => {
      retrying.value = true;
      try {
        const data = await api.post('/API/ai/retry', capability.value ? { capability: capability.value } : {});
        toast('已重新排队 ' + num(data && data.retried) + ' 条失败任务', 'success');
        await load();
        if (props.active) poller.trigger();
      } catch (err) {
        toast('重试失败: ' + err.message, 'error');
      } finally {
        retrying.value = false;
      }
    };

    const reload = () => {
      poller.trigger();
    };

    return {
      jobs, total, capability, status, error, loading, retrying, rows,
      capabilityOptions, STATUS_OPTIONS, retryFailed, reload,
      capabilityLabel, jobStatusText,
    };
  },
  template: `
    <div>
      <Card title="任务队列">
        <template #actions>
          <span class="small muted" v-if="loading">加载中…</span>
          <button class="ghost sm" :disabled="retrying" @click="retryFailed()">
            重试失败{{ capability ? '（当前能力）' : '（全部能力）' }}
          </button>
          <button class="ghost sm" @click="reload()">刷新</button>
        </template>

        <div class="small" style="color: var(--warning)" v-if="aiDisabled">
          AI 处理层已通过 AI_ENABLED=false 关闭，队列不会有新进展。
        </div>

        <div class="row" style="margin-bottom: 10px">
          <label class="field" style="min-width: 200px">
            能力
            <select v-model="capability" @change="reload()">
              <option value="">全部</option>
              <option v-for="item in capabilityOptions" :key="item.value" :value="item.value">{{ item.label }}</option>
            </select>
          </label>
          <label class="field" style="min-width: 160px">
            状态
            <select v-model="status" @change="reload()">
              <option v-for="item in STATUS_OPTIONS" :key="item.value" :value="item.value">{{ item.label }}</option>
            </select>
          </label>
          <span class="small muted" style="align-self: flex-end; padding-bottom: 8px">
            共 {{ total }} 条（显示 {{ rows.length }} 条）
          </span>
        </div>

        <Placeholder v-if="error" :error="'获取 /API/ai/jobs 失败: ' + error" />
        <Placeholder v-else-if="!rows.length" text="没有符合条件的任务" />
        <table class="data" v-else>
          <thead>
            <tr>
              <th>能力</th><th>状态</th><th>媒体</th><th>尝试</th><th>输入指纹</th><th>创建</th><th>最近错误</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in rows" :key="row.id">
              <td>{{ row.capabilityLabel }}</td>
              <td><Badge :kind="row.statusKind">{{ row.statusText }}</Badge></td>
              <td class="mono" :title="row.mediaId">{{ row.mediaShort }}</td>
              <td>{{ row.attempts }}</td>
              <td class="mono">{{ row.inputSig || '—' }}</td>
              <td class="small">{{ row.created }}</td>
              <td class="small" style="color: var(--warning)">{{ row.lastError }}</td>
            </tr>
          </tbody>
        </table>
      </Card>
    </div>`,
};
