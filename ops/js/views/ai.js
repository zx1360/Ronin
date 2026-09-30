// ai.js —— AI 媒体处理视图入口：子标签路由 + 子视图分发。
//
// 具体面板按关注点拆到 ./ai/ 下；对外仍只导出 title 与 render(root, ctx)，
// main.js 等调用方无需改动。
//
// 所有 AI 调用都做降级：能力清单与状态由后端下发，未就绪时显示原因并禁用相关控件；
// 非 2xx 一律把服务端的 error 显示出来，绝不渲染空白页。

import { el, mount } from '../dom.js';
import { render as renderCaps } from './ai/caps.js';
import { render as renderAuto } from './ai/auto.js';
import { render as renderStatus } from './ai/status.js';
import { render as renderSearch } from './ai/search.js';
import { render as renderPersons } from './ai/persons.js';
import { render as renderDupes } from './ai/dupes.js';
import { render as renderReview } from './ai/review.js';

export const title = 'AI 媒体处理';

const SUBTABS = [
  { id: 'caps', label: '能力 / 概览' },
  { id: 'auto', label: '自动处理' },
  { id: 'status', label: '状态 / 队列' },
  { id: 'search', label: '检索' },
  { id: 'persons', label: '人物' },
  { id: 'dupes', label: '去重 / 已删除' },
  { id: 'review', label: '近期回顾' },
];

export async function render(root, ctx) {
  const active = SUBTABS.some((tab) => tab.id === ctx.sub) ? ctx.sub : 'caps';

  const tabHost = el('div', { class: 'tabs' }, SUBTABS.map((tab) => el('button', {
    class: `tab${tab.id === active ? ' active' : ''}`,
    text: tab.label,
    onclick: () => { location.hash = `#/ai/${tab.id}`; },
  })));
  const bodyHost = el('div', { class: 'view-body' });
  mount(root, tabHost, bodyHost);

  let dispose = null;
  if (active === 'caps') dispose = await renderCaps(bodyHost);
  else if (active === 'auto') dispose = await renderAuto(bodyHost);
  else if (active === 'status') dispose = await renderStatus(bodyHost);
  else if (active === 'search') dispose = await renderSearch(bodyHost);
  else if (active === 'persons') dispose = await renderPersons(bodyHost);
  else if (active === 'dupes') dispose = await renderDupes(bodyHost);
  else if (active === 'review') dispose = await renderReview(bodyHost);

  return () => {
    if (typeof dispose === 'function') dispose();
  };
}
