// 共享 UI 组件与轮询工具。

import { ref, onUnmounted } from './vue.js';
import { state, resolveDialog } from './store.js';
import { taskStatusKind, taskStatusText } from './utils.js';

/** 状态徽标。 */
export const Badge = {
  props: { kind: { type: String, default: '' }, text: { type: String, default: '' } },
  template: `<span class="badge" :class="kind"><slot>{{ text }}</slot></span>`,
};

/** 任务状态徽标。 */
export const TaskStatusBadge = {
  props: { status: { type: String, default: '' } },
  computed: {
    kind() {
      return taskStatusKind(this.status);
    },
    text() {
      return taskStatusText(this.status);
    },
  },
  template: `<span class="badge" :class="kind">{{ text }}</span>`,
};

/** 带标题的卡片容器。 */
export const Card = {
  props: { title: { type: String, default: '' } },
  template: `
    <section class="card">
      <div class="row between" v-if="title || $slots.actions">
        <h2 class="section-title" v-if="title">{{ title }}</h2>
        <div class="row" v-if="$slots.actions"><slot name="actions" /></div>
      </div>
      <slot />
    </section>`,
};

/** 加载中 / 错误 / 空态占位。 */
export const Placeholder = {
  props: { text: { type: String, default: '暂无数据' }, error: { type: String, default: '' } },
  template: `<div class="placeholder" :class="{ error: !!error }">{{ error || text }}</div>`,
};

/** 图片缩略图（自动附加 API 密钥查询参数）。 */
export const MediaTile = {
  props: {
    src: { type: String, required: true },
    caption: { type: String, default: '' },
    selected: { type: Boolean, default: false },
  },
  emits: ['click'],
  template: `
    <div class="media-tile" :class="{ selected }" @click="$emit('click')">
      <img :src="src" loading="lazy" alt="" />
      <div class="meta" v-if="caption">{{ caption }}</div>
    </div>`,
};

/** 通知宿主（挂在应用根部一次）。 */
export const Toasts = {
  template: `
    <div class="toast-host">
      <div v-for="item in state.toasts" :key="item.id" class="toast" :class="item.kind">{{ item.message }}</div>
    </div>`,
  setup() {
    return { state };
  },
};

/** 二次确认对话框宿主（挂在应用根部一次）。 */
export const ConfirmHost = {
  template: `
    <div class="modal-mask" v-if="state.dialog" @click.self="resolveDialog(false)">
      <div class="modal">
        <h3>{{ state.dialog.title }}</h3>
        <p style="white-space: pre-wrap; margin: 0 0 4px">{{ state.dialog.message }}</p>
        <div class="modal-actions">
          <button @click="resolveDialog(false)">取消</button>
          <button class="primary" :class="{ danger: state.dialog.danger }" @click="resolveDialog(true)">
            确认
          </button>
        </div>
      </div>
    </div>`,
  setup() {
    return { state, resolveDialog };
  },
};

/**
 * 按需轮询：只在 enabled 为真时定时执行，页面卸载自动停止。
 *
 * @param {() => Promise<any>} callback 每次轮询执行的动作
 * @param {{interval: () => number, enabled: () => boolean}} options
 *        interval 与 enabled 用函数读取，便于跟随偏好与页面状态变化。
 */
export function usePolling(callback, { interval, enabled }) {
  let timer = null;
  let busy = false;

  const stop = () => {
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }
  };

  const run = async () => {
    if (busy) return;
    busy = true;
    try {
      await callback();
    } catch {
      // 轮询失败由各页面在 callback 内提示，这里不重复打扰
    } finally {
      busy = false;
    }
    stop();
    if (enabled()) {
      timer = setTimeout(run, Math.max(1000, interval() * 1000));
    }
  };

  /** 立即执行一次，并按需续期。 */
  const trigger = () => {
    stop();
    return run();
  };

  onUnmounted(stop);
  return { trigger, stop };
}

/** 页面通用的异步加载状态包装。 */
export function useAsyncState() {
  const loading = ref(false);
  const error = ref('');

  const wrap = async (action) => {
    loading.value = true;
    try {
      const result = await action();
      error.value = '';
      return result;
    } catch (err) {
      error.value = err.message || String(err);
      return null;
    } finally {
      loading.value = false;
    }
  };

  return { loading, error, wrap };
}
