// tasks.js —— 任务面板的公共零件（gallery CLI 与 comix 爬虫共用）。
//
// 两个视图的任务表列不同（gallery 看运行模式与进程，comix 看结果与 stderr），
// 但状态徽章、日志面板缓存与自动滚动开关完全一样，这里只维护一份。

import { el, badge, logView } from './dom.js';
import { prefs, patchPrefs } from './prefs.js';

const STATUS_KIND = { running: 'info', finished: 'ok', failed: 'err', killed: 'warn' };
const STATUS_LABEL = { running: '运行中', finished: '已完成', failed: '失败', killed: '已中断' };

export function statusBadge(status) {
  return badge(STATUS_LABEL[status] || status || '未知', STATUS_KIND[status] || '');
}

/** 日志自动滚动开关；勾选状态存服务端偏好。 */
export function autoscrollToggle() {
  return el('input', {
    type: 'checkbox',
    checked: prefs().log_autoscroll,
    onchange: (event) => { void patchPrefs({ log_autoscroll: event.target.checked }); },
  });
}

/**
 * 每个展开的任务持有一个日志面板（保留滚动位置与"贴底"状态），
 * 任务被服务端裁剪后随之回收。
 */
export function createLogPanels() {
  const panels = new Map();
  return {
    update(taskId, logs) {
      let panel = panels.get(taskId);
      if (!panel) {
        panel = logView();
        panels.set(taskId, panel);
      }
      panel.update(logs, prefs().log_autoscroll);
      return panel;
    },
    prune(tasks) {
      for (const id of [...panels.keys()]) {
        if (!tasks.some((task) => task.id === id)) panels.delete(id);
      }
    },
    clear() {
      panels.clear();
    },
  };
}
