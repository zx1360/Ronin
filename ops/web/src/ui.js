// 共享 UI 组件与轮询工具。

import { onUnmounted } from './vue.js';
import { state, resolveDialog, confirmAction, setLeaveGuard } from './store.js';
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

/** 图片缩略图。 */
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

export function useLeaveGuard(dirty) {
  const clear = setLeaveGuard(() => !dirty() || confirmAction('当前有未保存的修改，离开将丢弃这些输入。继续吗？', { danger: true }));
  const warn = (event) => { if (dirty()) { event.preventDefault(); event.returnValue = ''; } };
  window.addEventListener('beforeunload', warn);
  onUnmounted(() => { clear(); window.removeEventListener('beforeunload', warn); });
}

// 显式刷新可在空闲时执行；执行中的多次刷新合并为下一轮。
export function usePolling(callback, { interval, enabled }) {
  const controller = new AbortController();
  let timer;
  let pending;
  let refresh = false;

  const run = async () => {
    while (!controller.signal.aborted && refresh) {
      refresh = false;
      try {
        await callback(controller.signal);
      } catch {
        // 请求错误由页面显示。
      }
    }
    pending = null;
    if (!controller.signal.aborted && !document.hidden && enabled()) {
      timer = setTimeout(() => {
        if (!document.hidden && enabled()) trigger();
      }, Math.max(1000, interval() * 1000));
    }
  };

  const trigger = () => {
    if (controller.signal.aborted) return;
    clearTimeout(timer);
    refresh = true;
    return pending ??= Promise.resolve().then(run);
  };

  const onVisibility = () => {
    clearTimeout(timer);
    if (!document.hidden && enabled() && !pending) trigger();
  };
  document.addEventListener('visibilitychange', onVisibility);
  onUnmounted(() => {
    document.removeEventListener('visibilitychange', onVisibility);
    controller.abort();
    clearTimeout(timer);
  });
  return { trigger };
}
