<script>
import { ref, watch } from 'vue';
import { useApi } from '../../api.js';
import { toast } from '../../store.js';
import Card from '../../components/Card.vue';
import Placeholder from '../../components/Placeholder.vue';
import { num } from './shared.js';

export default {
  components: { Card, Placeholder },
  props: { runtime: { type: Object, default: null } },
  emits: ['saved'],
  setup(props, { emit }) {
    const api = useApi();
    const saving = ref(false);
    const configError = ref('');
    const form = ref(null);
    const dirty = ref(false);

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
        emit('saved');
      } catch (err) {
        if (api.signal.aborted) return;
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

    return { saving, configError, form, dirty, markDirty, saveConfig, resetConfig };
  },
};
</script>

<template>
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
