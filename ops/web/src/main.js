// 应用入口：装配侧边导航、顶部状态栏与页面路由。

import { createApp, computed, onMounted, onUnmounted } from './vue.js';
import { state, bootstrap, navigate, parseRoute } from './store.js';
import { Toasts, ConfirmHost } from './ui.js';
import DashboardPage from './pages/dashboard.js';
import AiPage from './pages/ai.js';
import ComixPage from './pages/comix.js';
import TasksPage from './pages/tasks.js';
import LogsPage from './pages/logs.js';
import SettingsPage from './pages/settings.js';
import HelpPage from './pages/help.js';

/** 导航项：顺序即侧边栏顺序。 */
export const routes = [
  { path: '/dashboard', label: '仪表盘', component: DashboardPage },
  { path: '/ai', label: 'AI 媒体处理', component: AiPage },
  { path: '/comix', label: '漫画资源', component: ComixPage },
  { path: '/tasks', label: '任务管理', component: TasksPage },
  { path: '/logs', label: '日志', component: LogsPage },
  { path: '/settings', label: '设置', component: SettingsPage },
  { path: '/help', label: '帮助', component: HelpPage },
];

const App = {
  components: { Toasts, ConfirmHost },
  setup() {
    const current = computed(() => routes.find((item) => item.path === state.route) || routes[0]);
    const modeText = computed(() => (state.service.isLocalMode ? '本地 HTTP · 免鉴权' : 'HTTPS 生产'));
    const address = computed(() => `127.0.0.1:${state.service.port || '?'}`);

    const onHashChange = () => {
      state.route = parseRoute();
    };

    onMounted(() => {
      window.addEventListener('hashchange', onHashChange);
      bootstrap();
      if (!window.location.hash) navigate('/dashboard');
    });
    onUnmounted(() => window.removeEventListener('hashchange', onHashChange));

    return { state, routes, current, modeText, address, bootstrap, navigate };
  },
  template: `
    <div class="shell" v-if="state.ready">
      <aside class="sidebar">
        <div class="brand">Northstar<small>Monarch 运维端</small></div>
        <nav class="nav">
          <a v-for="item in routes" :key="item.path" :href="'#' + item.path"
             :class="{ active: item.path === state.route }">{{ item.label }}</a>
        </nav>
        <div class="sidebar-foot">
          <div>{{ modeText }}</div>
          <div>{{ address }}</div>
        </div>
      </aside>
      <div class="main">
        <header class="topbar">
          <strong>{{ current.label }}</strong>
          <span class="badge" :class="state.service.isLocalMode ? 'info' : 'primary'">
            {{ state.service.isLocalMode ? 'local' : 'https' }}
          </span>
          <span class="badge" :class="state.cli.gallery.available ? 'success' : 'error'">
            gallery CLI {{ state.cli.gallery.available ? '就绪' : '不可用' }}
          </span>
          <span class="grow"></span>
          <button class="ghost sm" @click="bootstrap()">重新连接</button>
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

请确认 Monarch 正在运行，且本页面通过本机地址访问（生产模式为 https://127.0.0.1:7274/ops/，本地模式为 http://127.0.0.1:7275/ops/）。
      </div>
      <div class="boot" v-else>正在连接 Monarch…</div>
      <div class="content"><button class="primary" @click="bootstrap()">重试</button></div>
    </div>`,
};

createApp(App).mount('#app');
