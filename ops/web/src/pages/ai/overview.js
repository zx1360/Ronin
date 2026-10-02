// 概览：能力就绪/输入档位/进度、按能力重试与重生成、模型进程启停、
// 运行时信息、VLM 标注模型切换与运行时可调配置。
//
// 能力名称、说明、档位、执行者与候选全部来自服务端（status / capabilities），
// 端上只渲染列表，不硬编码能力语义。

import { ref, computed, watch } from '../../vue.js';
import { api } from '../../api.js';
import { toast, confirmAction } from '../../store.js';
import { Card, Placeholder, Badge } from '../../ui.js';
import { formatTime } from '../../utils.js';
import {
  baseName, capabilityLabel, doneCount, num, progressPercent, revealMedia, thumbUrl,
} from './shared.js';

/** 失败项单批加载条数：处理失败通常是个位数，留出足够的排查余地即可。 */
const FAILURE_PAGE_SIZE = 60;

export default {
  components: { Card, Placeholder, Badge },
  props: {
    status: { type: Object, default: null },
    capabilities: { type: Array, default: () => [] },
    runtime: { type: Object, default: null },
    error: { type: String, default: '' },
    busy: { type: Boolean, default: false },
    aiDisabled: { type: Boolean, default: false },
    schemaMissing: { type: Boolean, default: false },
    pollError: { type: String, default: '' },
    run: { type: Function, default: null },
    refresh: { type: Function, default: null },
  },
  setup(props) {
    const saving = ref(false);
    const configError = ref('');
    const form = ref(null);
    const dirty = ref(false);

    /** 统一走服务端的「操作 + 提示 + 刷新状态」通道；失败不吞异常。 */
    const act = async (notice, action) => {
      if (typeof props.run === 'function') return props.run(notice, action);
      try {
        await action();
        if (notice) toast(notice, 'success');
        return true;
      } catch (err) {
        toast('操作失败: ' + err.message, 'error');
        return false;
      }
    };

    const doRefresh = () => {
      if (typeof props.refresh === 'function') props.refresh();
    };

    const header = computed(() => {
      const source = props.status || {};
      const enabled = source.enabled === true;
      const started = source.started === true;
      return {
        enabled,
        started,
        paused: source.paused === true,
        pending: num(source.pending_total),
        failed: num(source.failed_total),
        stateText: enabled ? (started ? 'AI 处理层运行中' : '已启用但未启动') : '已通过 AI_ENABLED=false 关闭',
        stateKind: enabled && started ? 'success' : 'error',
      };
    });

    const cards = computed(() => {
      const mediaTotal = num(props.status && props.status.media_total);
      return (props.capabilities || []).map((cap) => {
        const source = cap || {};
        const sidecar = source.sidecar || null;
        const done = doneCount(source.done, mediaTotal);
        const pending = num(source.pending);
        const missing = num(source.missing_media);
        const failed = num(source.failed);
        return {
          name: source.capability || '',
          label: source.label || source.capability || '',
          description: source.description || '',
          tier: source.input_tier || '',
          tierNote: source.tier_note || '',
          executor: source.executor || '',
          inputSig: source.input_sig || '',
          ready: source.ready === true,
          reason: source.reason || '',
          stale: num(source.stale_media),
          done,
          pending,
          missing,
          failed,
          total: mediaTotal,
          percent: progressPercent(done, mediaTotal),
          // 侧车能力（embed/face/ocr）由服务端下发 sidecar；无 sidecar 的能力不提供进程按钮
          hasSidecar: !!sidecar,
          running: !!(sidecar && sidecar.running === true),
          pid: sidecar ? num(sidecar.pid) : 0,
          idleSeconds: sidecar ? num(sidecar.idle_seconds) : 0,
          idleTimeout: sidecar ? num(sidecar.idle_timeout_seconds) : 0,
          probeError: (sidecar && sidecar.probe_error) || '',
          missingModels: sidecar && Array.isArray(sidecar.missing_models) ? sidecar.missing_models : [],
          isVlm: source.capability === 'vlm',
        };
      });
    });

    const lastRun = computed(() => {
      const source = props.status && props.status.last_run ? props.status.last_run : null;
      if (!source) return null;
      const total = num(source.total);
      const processed = num(source.processed);
      return {
        label: capabilityLabel(props.capabilities, source.capability) || source.capability || '',
        running: source.running === true,
        processed,
        failed: num(source.failed),
        total,
        pending: Math.max(0, total - processed),
        percent: total > 0 ? Math.min(100, Math.round((processed / total) * 100)) : 0,
      };
    });

    const index = computed(() => {
      const source = (props.status && props.status.index) || {};
      return {
        model: source.model || '',
        vectors: num(source.vectors),
        loaded: source.loaded === true,
        memory: Math.round(num(source.memory_estimate_bytes) / 1024 / 1024),
      };
    });

    const cluster = computed(() => {
      const source = (props.status && props.status.cluster) || {};
      const threshold = num(source.threshold);
      return {
        persons: num(source.persons),
        threshold: threshold > 0 ? threshold.toFixed(2) : '—',
        minGroupFaces: num(source.min_group_faces),
        centroidsLoaded: source.centroids_loaded === true,
      };
    });

    const ollama = computed(() => {
      const source = (props.status && props.status.ollama) || {};
      const models = Array.isArray(source.models) ? source.models : [];
      return {
        url: source.url || '',
        model: source.model || '',
        activeModel: source.active_model || '',
        lastSwitch: source.last_switch || '',
        numCtx: num(source.num_ctx),
        reachable: source.reachable === true,
        modelReady: source.model_ready === true,
        error: source.error || '',
        owned: source.owned_server === true,
        pid: num(source.pid),
        idleSeconds: num(source.idle_seconds),
        modelRoot: source.model_root || '',
        modelCount: models.length,
      };
    });

    const workerText = computed(() => {
      const source = props.status;
      if (!source) return '';
      return '推理设备 ' + (source.device || '—')
        + ' · 并发 ' + num(source.workers)
        + ' · 批大小 ' + num(source.batch_size)
        + ' · 批次超时 ' + num(source.job_timeout_seconds) + 's'
        + ' · 重试上限 ' + num(source.max_attempts);
    });

    // 候选模型就是本机已安装的模型（/API/ai/capabilities 下发，按名称排序）；
    // 不可达时列表为空，界面先把"服务没起"说清楚，而不是列一堆点不动的名字。
    const vlmCandidates = computed(() => {
      const cap = (props.capabilities || []).find((item) => item && item.capability === 'vlm');
      const list = cap && Array.isArray(cap.executor_candidates) ? cap.executor_candidates : [];
      return list.map((item) => ({
        model: item.model || '',
        installed: item.installed === true,
        vision: item.vision === true,
        current: item.is_current === true,
      }));
    });

    const autoCapabilities = computed(() => {
      const list = props.runtime && Array.isArray(props.runtime.auto_capabilities)
        ? props.runtime.auto_capabilities
        : [];
      return list.map((item) => String(item));
    });

    const capabilityOptions = computed(() => (props.capabilities || []).map((cap) => ({
      name: (cap && cap.capability) || '',
      label: (cap && (cap.label || cap.capability)) || '',
    })));

    const configPath = computed(() => {
      if (props.runtime && props.runtime.config_path) return props.runtime.config_path;
      return (props.status && props.status.config_path) || '';
    });

    const inAuto = (name) => autoCapabilities.value.indexOf(name) >= 0;

    // ---- 失败项 ----

    const failureCap = ref('');
    const failures = ref([]);
    const failureTotal = ref(0);
    const failureError = ref('');
    const failureLoading = ref(false);
    const failureSelected = ref([]);

    const failureLabel = computed(
      () => capabilityLabel(props.capabilities, failureCap.value) || failureCap.value,
    );
    const failureHasMore = computed(() => failures.value.length < failureTotal.value);

    /** 取某个能力"到底哪些文件失败了"；失败项通常是个位数，按批加载即可。 */
    const loadFailures = async (more) => {
      if (!failureCap.value || failureLoading.value) return;
      if (more && !failureHasMore.value) return;
      failureLoading.value = true;
      failureError.value = '';
      const offset = more ? failures.value.length : 0;
      try {
        const data = await api.get(
          '/API/ai/failures?capability=' + encodeURIComponent(failureCap.value)
          + '&limit=' + FAILURE_PAGE_SIZE + '&offset=' + offset,
        );
        const page = (Array.isArray(data && data.failures) ? data.failures : []).map((item) => ({
          mediaId: item.media_id || '',
          name: baseName(item.file_path) || String(item.media_id || '').slice(0, 8),
          filePath: item.file_path || '',
          mimeType: item.mime_type || '',
          attempts: num(item.attempts),
          lastError: item.last_error || '',
          updated: formatTime(item.updated_at, false),
          // 没有缩略图的媒体（视频、源文件已缺失）直接给占位，省掉一次必 404 的请求
          thumb: item.thumb_path ? thumbUrl(item.media_id) : '',
          thumbFailed: !item.thumb_path,
          isDeleted: item.is_deleted === true,
        }));
        failures.value = more ? failures.value.concat(page) : page;
        failureTotal.value = num(data && data.total);
        const alive = failures.value.map((item) => item.mediaId);
        failureSelected.value = failureSelected.value.filter((id) => alive.indexOf(id) >= 0);
      } catch (err) {
        failureError.value = err.message;
      } finally {
        failureLoading.value = false;
      }
    };

    const openFailures = (card) => {
      if (failureCap.value === card.name) {
        closeFailures();
        return;
      }
      failureCap.value = card.name;
      failures.value = [];
      failureTotal.value = 0;
      failureSelected.value = [];
      return loadFailures(false);
    };

    const closeFailures = () => {
      failureCap.value = '';
      failures.value = [];
      failureTotal.value = 0;
      failureSelected.value = [];
      failureError.value = '';
    };

    const toggleFailure = (id) => {
      const next = failureSelected.value.slice();
      const position = next.indexOf(id);
      if (position >= 0) next.splice(position, 1);
      else next.push(id);
      failureSelected.value = next;
    };

    const isFailureSelected = (id) => failureSelected.value.indexOf(id) >= 0;

    /** 缩略图加载失败（媒体没有缩略图或源文件已缺失）：退回文字占位，别留破图。 */
    const markThumbMissing = (item) => {
      item.thumbFailed = true;
    };

    /** 只作用于已加载的条目：没进 DOM 的不替用户做看不见的选择。 */
    const selectAllFailures = () => {
      failureSelected.value = failures.value.map((item) => item.mediaId);
    };

    const clearFailureSelection = () => {
      failureSelected.value = [];
    };

    /**
     * 标记软删除：复用 gallery 的软删除标记，磁盘文件不动。
     *
     * 失败项往往就是"这个文件本身没救"（损坏、非图片、源文件缺失），
     * 标掉之后既不会再被补处理反复排队，也能在「已删除」页恢复。
     */
    const softDeleteFailures = async (ids) => {
      if (!ids.length) return;
      const ok = await confirmAction(
        '将把选中的 ' + ids.length + ' 个文件标记为软删除（只改数据库标记，磁盘文件仍在，可在「已删除」页恢复）。',
        { title: '确认标记软删除', danger: true },
      );
      if (!ok) return;
      await act('', async () => {
        await api.patch('/API/gallery/media', { media_ids: ids, is_deleted: true });
        toast('已标记软删除 ' + ids.length + ' 个文件', 'success');
        failureSelected.value = [];
        await loadFailures(false);
      });
    };

    // ---- 能力卡片动作 ----

    const retryFailed = (card) => act('', async () => {
      const data = await api.post('/API/ai/retry', { capability: card.name });
      toast('已重试 ' + num(data && data.retried) + ' 条失败任务', 'success');
    });

    /** 补处理：把尚无该能力产物的媒体全部入队（幂等）。 */
    const enqueueMissing = async (card) => {
      if (card.isVlm) {
        const ok = await confirmAction(
          '将把全库尚无 VLM 标注的 ' + card.missing + ' 张图片加入队列。\n'
          + 'VLM 单张耗时以秒计，全库补处理可能需要数小时至数天，建议先用「全量重生成」以外的小批量试用。',
          { title: '确认全库 VLM 标注', danger: false },
        );
        if (!ok) return;
      }
      await act('', async () => {
        const data = await api.post('/API/ai/enqueue', { capabilities: [card.name], scope: 'missing' });
        const affected = (data && data.enqueued) || {};
        toast('已提交 ' + num(affected[card.name]) + ' 条待处理任务', 'success');
      });
    };

    /** 全量重生成：清空该能力既有产物后全库重排，破坏性，必须二次确认。 */
    const regenerate = async (card) => {
      const ok = await confirmAction(
        '将先清空「' + card.label + '」的 ' + card.done + ' 条既有结果，再把全部媒体重新排队。\n'
        + '清空期间这项能力的检索/筛选会短暂为空；其它能力的产物不受影响。\n'
        + '本操作只作用于「' + card.label + '」。',
        { title: '确认全量重生成', danger: true },
      );
      if (!ok) return;
      await act('', async () => {
        const data = await api.post('/API/ai/regenerate', { capability: card.name }, { timeoutMs: 1800000 });
        toast(
          '已清空 ' + num(data && data.cleared) + ' 条旧结果，重新排队 ' + num(data && data.enqueued) + ' 条',
          'success',
        );
      });
    };

    const toggleProcess = (card) => act('', async () => {
      const action = card.running ? 'stop' : 'start';
      await api.post('/API/ai/process/' + card.name + '/' + action, {}, { timeoutMs: 180000 });
      toast(card.running ? '已释放模型进程' : '模型已就绪', 'success');
    });

    const unloadVlm = () => act('', async () => {
      await api.post('/API/ai/process/vlm/stop', {}, { timeoutMs: 60000 });
      toast('已请求卸载 VLM 模型', 'success');
    });

    /** 暂停 = 中断当前批次并停止认领新任务（可随时继续）；中断前仍做一次确认。 */
    const togglePause = async () => {
      const paused = !!(props.status && props.status.paused);
      if (!paused) {
        const ok = await confirmAction(
          '中断当前批次并暂停认领新任务？\n已完成的产物会保留，未完成的任务留在队列里，随时可以「继续处理」。',
          { title: '确认暂停处理', danger: false },
        );
        if (!ok) return;
      }
      await act('', async () => {
        if (paused) {
          await api.post('/API/ai/resume');
          toast('已继续处理', 'success');
          return;
        }
        const data = await api.post('/API/ai/cancel');
        toast(data && data.cancelled ? '已中断当前批次并暂停认领' : '处理队列已暂停', 'success');
      });
    };

    const rebuildIndex = () => act('', async () => {
      const data = await api.post('/API/ai/index/rebuild', {}, { timeoutMs: 1800000 });
      toast('向量索引已重建，共 ' + num(data && data.vectors) + ' 条', 'success');
    });

    const switchVlmModel = (candidate) => {
      if (!candidate.installed || candidate.current) return;
      return act('', async () => {
        await api.put('/API/ai/settings', { vlm_model: candidate.model });
        toast('已切换 VLM 标注模型: ' + candidate.model, 'success');
      });
    };

    const toggleAuto = (name) => {
      const next = autoCapabilities.value.slice();
      const position = next.indexOf(name);
      if (position >= 0) next.splice(position, 1);
      else next.push(name);
      return act('', async () => {
        await api.put('/API/ai/settings', { auto_capabilities: next });
        toast('自动处理能力已更新', 'success');
      });
    };

    // ---- 处理配置 ----

    /** 从服务端配置镜像表单；用户正在编辑（dirty）时不覆盖，避免轮询打断输入。 */
    const applyRuntime = (source) => {
      if (!source) return;
      form.value = {
        idle: num(source.idle_timeout_seconds),
        job: num(source.job_timeout_seconds),
        batch: num(source.batch_size),
        attempts: num(source.max_attempts),
        workers: num(source.workers),
        device: source.device || '',
      };
    };

    watch(() => props.runtime, (value) => {
      if (!form.value || !dirty.value) applyRuntime(value);
    }, { immediate: true });

    const markDirty = () => {
      dirty.value = true;
      configError.value = '';
    };

    const saveConfig = async () => {
      if (!form.value) return;
      configError.value = '';
      saving.value = true;
      try {
        const data = await api.put('/API/ai/settings', {
          idle_timeout_seconds: num(form.value.idle),
          job_timeout_seconds: num(form.value.job),
          batch_size: num(form.value.batch),
          max_attempts: num(form.value.attempts),
          workers: num(form.value.workers),
          device: form.value.device,
        });
        dirty.value = false;
        applyRuntime(data);
        toast('处理配置已保存', 'success');
        doRefresh();
      } catch (err) {
        // 服务端会按取值范围回 400 并带原因，原样展示而不是笼统提示
        configError.value = err.message;
        toast('保存失败: ' + err.message, 'error');
      } finally {
        saving.value = false;
      }
    };

    const resetConfig = () => {
      dirty.value = false;
      configError.value = '';
      applyRuntime(props.runtime);
    };

    return {
      saving, configError, form, dirty,
      header, cards, lastRun, index, cluster, ollama, workerText,
      vlmCandidates, autoCapabilities, capabilityOptions, configPath, inAuto,
      retryFailed, enqueueMissing, regenerate, toggleProcess, unloadVlm,
      togglePause, rebuildIndex, switchVlmModel, toggleAuto,
      failureCap, failures, failureTotal, failureError, failureLoading, failureSelected,
      failureLabel, failureHasMore, openFailures, closeFailures, toggleFailure,
      isFailureSelected, selectAllFailures, clearFailureSelection, softDeleteFailures,
      loadFailures, markThumbMissing,
      revealMedia, FAILURE_PAGE_SIZE,
      markDirty, saveConfig, resetConfig, doRefresh,
    };
  },
  template: `
    <div>
      <div class="row between">
        <div class="row" v-if="status">
          <Badge :kind="header.stateKind">{{ header.stateText }}</Badge>
          <Badge :kind="header.pending > 0 ? 'info' : ''">待处理 {{ header.pending }}</Badge>
          <Badge :kind="header.failed > 0 ? 'error' : ''">失败 {{ header.failed }}</Badge>
          <Badge kind="warning" v-if="header.paused">已暂停</Badge>
        </div>
        <div class="row">
          <button class="ghost sm" v-if="status && !aiDisabled" :disabled="busy" @click="togglePause()">
            {{ header.paused ? '继续处理' : '暂停处理' }}
          </button>
          <button class="ghost sm" v-if="!aiDisabled" :disabled="busy" @click="doRefresh()">刷新</button>
        </div>
      </div>

      <div class="small muted" style="margin: 6px 0" v-if="pollError">状态刷新失败：{{ pollError }}</div>

      <Placeholder
        v-if="aiDisabled"
        text="AI 处理层已通过 AI_ENABLED=false 关闭：不会处理任何任务，页面也不做轮询。启用请修改服务端 .env 后重启 Monarch。"
      />
      <Placeholder
        v-else-if="schemaMissing"
        error="AI 表尚未初始化：请先对数据库执行 backend/references/db/ai.sql（幂等，只新增 ai 侧的表与列，不影响既有数据），然后重启 Monarch。"
      />
      <Placeholder v-else-if="!status" :error="error" :text="error ? '' : '正在获取 /API/ai/status…'" />
      <template v-else>
        <Card title="当前批次" v-if="lastRun">
          <div class="row between">
            <div class="row">
              <strong>{{ lastRun.label }}</strong>
              <Badge :kind="lastRun.running ? 'info' : ''">{{ lastRun.running ? '执行中' : '已结束' }}</Badge>
              <span class="small muted">本批 {{ lastRun.processed }} / {{ lastRun.total }} · 失败 {{ lastRun.failed }}</span>
            </div>
          </div>
          <div class="progress" style="margin-top: 8px"><div :style="{ width: lastRun.percent + '%' }"></div></div>
        </Card>

        <div class="row between">
          <h2 class="section-title" style="margin: 0">处理能力</h2>
          <span class="small muted">
            同一张图按能力分档取源：轻量能力用 256 预览档，人脸/文字/描述用长边 1024 的 AI 派生档（缺失时按需生成并缓存）。
          </span>
        </div>

        <Card v-for="card in cards" :key="card.name" :title="card.label">
          <template #actions>
            <Badge :kind="card.ready ? 'success' : 'error'">{{ card.ready ? '就绪' : '未就绪' }}</Badge>
            <Badge v-if="card.tier" kind="primary" :title="card.tierNote">{{ card.tier }}</Badge>
            <Badge
              v-if="card.stale > 0"
              kind="warning"
              title="输入档位或执行者已变更，这些旧产物会被服务端自动重排"
            >待重排 {{ card.stale }}</Badge>
            <Badge v-if="card.running" kind="info">进程运行中 PID {{ card.pid }}</Badge>
          </template>

          <div class="col">
            <div class="small muted">{{ card.description }}</div>
            <div class="small">
              执行者 <span class="mono">{{ card.executor }}</span>
              <span class="muted" v-if="card.inputSig"> · 指纹 <span class="mono">{{ card.inputSig }}</span></span>
            </div>
            <div class="small" style="color: var(--warning)" v-if="!card.ready && card.reason">{{ card.reason }}</div>
            <div class="small" style="color: var(--warning)" v-if="card.probeError">侧车探测失败：{{ card.probeError }}</div>
            <div class="small" style="color: var(--warning)" v-if="card.missingModels.length">
              缺少模型：{{ card.missingModels.join('、') }}（运行 tools/ai/install.ps1）
            </div>

            <div class="progress"><div :style="{ width: card.percent + '%' }"></div></div>
            <div class="small muted">
              已处理 {{ card.done }} / {{ card.total }} · 排队 {{ card.pending }} · 尚无产物 {{ card.missing }} · 失败 {{ card.failed }}
              <span v-if="card.idleSeconds > 0"> · 空闲 {{ card.idleSeconds }}s（{{ card.idleTimeout }}s 后自动退出）</span>
            </div>

            <div class="row">
              <button
                class="ghost sm"
                v-if="card.hasSidecar"
                :disabled="busy"
                @click="toggleProcess(card)"
              >{{ card.running ? '释放模型' : '启动模型' }}</button>
              <button class="ghost sm" v-if="card.isVlm" :disabled="busy" @click="unloadVlm()">卸载 VLM 模型</button>
              <button
                class="ghost sm"
                :disabled="busy || card.missing === 0"
                @click="enqueueMissing(card)"
              >补处理 {{ card.missing }}</button>
              <button
                class="ghost sm"
                :disabled="busy || card.failed === 0"
                @click="retryFailed(card)"
              >重试失败项 {{ card.failed }}</button>
              <button
                class="ghost sm"
                :disabled="busy || card.failed === 0"
                @click="openFailures(card)"
              >{{ failureCap === card.name ? '收起失败项' : '查看失败项 ' + card.failed }}</button>
              <button class="danger sm" :disabled="busy" @click="regenerate(card)">全量重生成</button>
            </div>

            <div v-if="failureCap === card.name">
              <div class="row between">
                <span class="small muted">
                  处理失败的媒体清单（{{ failureLabel }}）· 每批最多 {{ FAILURE_PAGE_SIZE }} 条 ·
                  已加载 {{ failures.length }} / 共 {{ failureTotal }} 项
                </span>
                <span class="row">
                  <button class="ghost sm" :disabled="failureLoading" @click="loadFailures(false)">刷新</button>
                  <button class="ghost sm" :disabled="failureLoading" @click="closeFailures()">关闭</button>
                </span>
              </div>

              <Placeholder v-if="failureError" :error="'获取 /API/ai/failures 失败: ' + failureError" />
              <Placeholder v-else-if="failureLoading && !failures.length" text="正在读取失败项…" />
              <Placeholder v-else-if="!failures.length" text="没有失败项" />
              <template v-else>
                <div class="row" style="margin: 6px 0">
                  <button
                    class="ghost sm"
                    :disabled="busy"
                    @click="selectAllFailures()"
                  >全选已加载的 {{ failures.length }} 项</button>
                  <button
                    class="ghost sm"
                    :disabled="busy || !failureSelected.length"
                    @click="clearFailureSelection()"
                  >取消选择（{{ failureSelected.length }}）</button>
                  <button
                    class="danger sm"
                    :disabled="busy || !failureSelected.length"
                    @click="softDeleteFailures(failureSelected)"
                  >标记软删除（{{ failureSelected.length }}）</button>
                  <span class="grow"></span>
                  <button
                    class="ghost sm"
                    v-if="failureHasMore"
                    :disabled="failureLoading"
                    @click="loadFailures(true)"
                  >加载更多</button>
                </div>

                <div class="media-grid wide">
                  <div
                    v-for="item in failures"
                    :key="item.mediaId"
                    class="media-tile"
                    :class="{ selected: isFailureSelected(item.mediaId) }"
                    @click="toggleFailure(item.mediaId)"
                  >
                    <img v-if="!item.thumbFailed" :src="item.thumb" alt="" loading="lazy" @error="markThumbMissing(item)" />
                    <div v-else class="thumb-missing">无缩略图</div>
                    <div class="meta">
                      <div :title="item.filePath">{{ item.name }}</div>
                      <div class="small muted">{{ item.updated }} · 尝试 {{ item.attempts }} 次</div>
                      <div class="small" v-if="item.isDeleted">已标记软删除</div>
                      <div class="small clamp-2" style="color: var(--warning)" :title="item.lastError">{{ item.lastError }}</div>
                      <div class="row" style="margin-top: 4px">
                        <button class="danger sm" :disabled="busy" @click.stop="softDeleteFailures([item.mediaId])">
                          标记软删除
                        </button>
                        <button class="ghost sm" @click.stop="revealMedia(item.filePath)">打开目录</button>
                      </div>
                    </div>
                  </div>
                </div>
              </template>
            </div>
          </div>
        </Card>

        <Card title="运行时">
          <template #actions>
            <button class="ghost sm" :disabled="busy" @click="rebuildIndex()">重建向量索引</button>
          </template>
          <table class="data">
            <tbody>
              <tr><th style="width: 160px">向量模型</th><td class="mono">{{ index.model || '—' }}</td></tr>
              <tr>
                <th>向量索引</th>
                <td>
                  {{ index.vectors }} 条
                  <span class="muted">{{ index.loaded ? '（已载入内存，约 ' + index.memory + ' MiB）' : '（尚未载入）' }}</span>
                </td>
              </tr>
              <tr>
                <th>人物分组</th>
                <td>
                  {{ cluster.persons }} 组（阈值 {{ cluster.threshold }}，至少 {{ cluster.minGroupFaces }} 张成组）
                  <span class="muted">{{ cluster.centroidsLoaded ? '· 质心已载入' : '· 质心未载入' }}</span>
                </td>
              </tr>
              <tr>
                <th>Ollama</th>
                <td>
                  <span v-if="!ollama.reachable" style="color: var(--warning)">
                    不可达（{{ ollama.url || '未配置' }}）{{ ollama.error ? '：' + ollama.error : '' }}
                  </span>
                  <span v-else>
                    <span class="mono">{{ ollama.model || '—' }}</span>
                    {{ ollama.modelReady ? '已安装' : '未安装' }}
                    · 上下文 {{ ollama.numCtx }}
                    · 已装模型 {{ ollama.modelCount }} 个
                    <span v-if="ollama.owned"> · 自拉服务 PID {{ ollama.pid }}（空闲 {{ ollama.idleSeconds }}s）</span>
                  </span>
                </td>
              </tr>
              <tr><th>Ollama 模型目录</th><td class="mono small">{{ ollama.modelRoot || '—' }}</td></tr>
              <tr><th>worker 配置</th><td class="small">{{ workerText }}</td></tr>
              <tr><th>配置文件</th><td class="mono">{{ configPath || '（未启用）' }}</td></tr>
            </tbody>
          </table>

          <div class="col" style="margin-top: 12px">
            <div class="row">
              <span class="small">VLM 标注模型</span>
              <span class="small muted">
                {{ ollama.activeModel ? '正在推理：' + ollama.activeModel : '当前空闲' }}
              </span>
            </div>
            <div class="small" style="color: var(--warning)" v-if="ollama.lastSwitch">最近模型切换：{{ ollama.lastSwitch }}</div>
            <div class="small" style="color: var(--warning)" v-if="!ollama.reachable">
              本机 Ollama 未运行（或没有已安装模型）：模型清单此刻是空的，点上面的「启动模型」由服务端
              按需拉起（模型目录 {{ ollama.modelRoot || '默认' }}）。
            </div>
            <div class="small muted" v-if="!vlmCandidates.length">当前没有可用模型，因此没有可选清单</div>
            <div class="row" v-else>
              <button
                v-for="candidate in vlmCandidates"
                :key="candidate.model"
                class="sm"
                :class="candidate.current ? 'primary' : 'ghost'"
                :disabled="busy || candidate.current"
                :title="candidate.model"
                @click="switchVlmModel(candidate)"
              >{{ candidate.model }}{{ candidate.vision ? '' : '（非视觉模型）' }}</button>
            </div>
            <div class="small muted">
              候选实时来自本机 Ollama 的已安装模型（ollama pull/rm 后刷新即可，无需改配置）；
              换模型后该能力的旧产物会被服务端自动重排（输入档位/执行者不匹配即重排）。
              标注必须有视觉能力，只有对话模型时请勿切到它。
            </div>

            <div class="row">
              <span class="small">入库自动处理</span>
              <button
                v-for="option in capabilityOptions"
                :key="option.name"
                class="sm"
                :class="inAuto(option.name) ? 'primary' : 'ghost'"
                :disabled="busy"
                @click="toggleAuto(option.name)"
              >{{ option.label }}</button>
            </div>
            <div class="small muted">选中的能力会在媒体入库后自动排队；未选中的需要手动提交。VLM 标注耗时长，默认不自动执行。</div>
          </div>
        </Card>

        <Card title="处理配置">
          <template #actions>
            <button class="ghost sm" :disabled="!dirty || saving" @click="resetConfig()">放弃改动</button>
            <button class="primary sm" :disabled="!form || saving" @click="saveConfig()">
              {{ saving ? '保存中…' : '保存' }}
            </button>
          </template>

          <Placeholder v-if="!form" text="正在获取 /API/ai/settings…" />
          <template v-else>
            <div class="grid cols-3">
              <label class="field">
                侧车空闲退出（秒，5-86400）
                <input type="number" min="5" max="86400" v-model.number="form.idle" @input="markDirty()" />
              </label>
              <label class="field">
                批次超时（秒，30-86400）
                <input type="number" min="30" max="86400" v-model.number="form.job" @input="markDirty()" />
              </label>
              <label class="field">
                批大小（1-512）
                <input type="number" min="1" max="512" v-model.number="form.batch" @input="markDirty()" />
              </label>
              <label class="field">
                重试上限（1-20）
                <input type="number" min="1" max="20" v-model.number="form.attempts" @input="markDirty()" />
              </label>
              <label class="field">
                并发批次数（1-4）
                <input type="number" min="1" max="4" v-model.number="form.workers" @input="markDirty()" />
              </label>
              <label class="field">
                推理设备
                <select v-model="form.device" @change="markDirty()">
                  <option value="auto">自动（优先 DirectML）</option>
                  <option value="cpu">强制 CPU</option>
                </select>
              </label>
            </div>
            <div class="small muted" style="margin-top: 8px">
              保存在服务端配置文件里，改完立即生效、无需重启 Monarch。推理设备只影响速度与显存占用，不改变产物语义，因此不会触发重排。
            </div>
            <Placeholder v-if="configError" :error="'保存失败（服务端原样返回）: ' + configError" />
          </template>
        </Card>
      </template>
    </div>`,
};
