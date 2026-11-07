// 应用入口：装配侧边导航、顶部状态栏与页面路由。

import { createApp, computed, onMounted, onUnmounted } from './vue.js';
import { state, bootstrap, navigate, parseRoute, canLeave } from './store.js';
import { Toasts, ConfirmHost } from './ui.js';
import DashboardPage from './pages/dashboard.js';
import AiPage from './pages/ai.js';
import ComixPage from './pages/comix.js';
import TasksPage from './pages/tasks.js';
import SettingsPage from './pages/settings.js';
import HelpPage from './pages/help.js';
import BookletPage from './pages/booklet.js';
import EssayPage from './pages/essay.js';

/** 导航项：顺序即侧边栏顺序。 */
export const routes = [
  { path: '/dashboard', group: '运行与维护', label: '工作台', description: '服务状态与常用操作入口', component: DashboardPage },
  { path: '/tasks', group: '运行与维护', label: '任务中心', description: '查看媒体与漫画任务的排队、结果和日志', component: TasksPage },
  { path: '/ai', group: '运行与维护', label: 'AI 与检索', description: '管理处理队列、模型与媒体检索', component: AiPage },
  { path: '/comix', group: '运行与维护', label: '漫画管理', description: '查找资源、下载章节和管理追更', component: ComixPage },
  { path: '/essay', group: '个人数据', label: '随笔', description: '在线写作与本机草稿，和手机共享正式随笔', component: EssayPage },
  { path: '/booklet', group: '个人数据', label: '积微 · 打卡', description: '每日打卡、历史记录与样式管理', component: BookletPage },
  { path: '/settings', group: '平台', label: '设置与连接', description: '界面偏好、服务路径和组件状态', component: SettingsPage },
  { path: '/help', group: '平台', label: '使用说明', description: '数据归属、同步方式与操作边界', component: HelpPage },
];

const App = {
  components: { Toasts, ConfirmHost },
  setup() {
    const current = computed(() => routes.find((item) => item.path === state.route) || routes[0]);
    const groups = [...new Set(routes.map((item) => item.group))].map((label) => ({ label, items: routes.filter((item) => item.group === label) }));

    let navigation;
    const onHashChange = async () => {
      const hash = window.location.hash, next = parseRoute();
      if (next === state.route) return;
      const allowed = await (navigation ??= Promise.resolve(canLeave()).finally(() => { navigation = null; }));
      if (window.location.hash !== hash) return;
      if (allowed) state.route = next;
      else window.history.replaceState(null, '', '#' + state.route);
    };

    onMounted(() => {
      window.addEventListener('hashchange', onHashChange);
      bootstrap();
      if (!window.location.hash) navigate('/dashboard');
    });
    onUnmounted(() => window.removeEventListener('hashchange', onHashChange));

    return { state, groups, current, bootstrap, navigate };
  },
  template: `
    <div class="shell" v-if="state.ready">
      <aside class="sidebar">
        <div class="brand">Northstar<small>个人数据与运维</small></div>
        <nav class="nav">
          <template v-for="group in groups" :key="group.label">
            <span class="nav-section">{{ group.label }}</span>
            <a v-for="item in group.items" :key="item.path" :href="'#' + item.path"
               :aria-current="item.path === current.path ? 'page' : undefined"
               :class="{ active: item.path === current.path }">{{ item.label }}</a>
          </template>
        </nav>
      </aside>
      <div class="main">
        <header class="topbar">
          <h1>
            <strong>{{ current.label }}</strong>
            <small class="muted">{{ current.description }}</small>
          </h1>
          <span class="grow"></span>
          <span class="badge">仅本机</span>
          <button class="ghost sm" :disabled="state.connecting" @click="bootstrap()">{{ state.connecting ? '连接中…' : '重新连接' }}</button>
        </header>
        <main class="content">
          <component :is="current.component" :key="current.path" />
        </main>
      </div>
      <Toasts />
      <ConfirmHost />
    </div>
    <div v-else>
      <div class="placeholder error" v-if="state.bootError">
        {{ state.bootError }}
        请确认 Monarch 正在运行, 并通过本机地址访问本页面: http://127.0.0.1:7275
      </div>
      <div class="boot" v-else>正在连接 Monarch…</div>
      <div class="content"><button class="primary" @click="bootstrap()">重试</button></div>
    </div>`,
};

createApp(App).mount('#app');
