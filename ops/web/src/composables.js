import { onUnmounted } from 'vue';
import { confirmAction, setLeaveGuard } from './store.js';

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
