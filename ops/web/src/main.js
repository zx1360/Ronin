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
    // 同一套页面在 7274(HTTPS) 与 7275(HTTP) 上都能打开，显示以实际来源为准
    const scheme = window.location.protocol.replace(':', '');
    const address = computed(() => `127.0.0.1:${state.service.port || window.location.port || '?'}`);

    const onHashChange = () => {
      state.route = parseRoute();
    };

    onMounted(() => {
      window.addEventListener('hashchange', onHashChange);
      bootstrap();
      if (!window.location.hash) navigate('/dashboard');
    });
    onUnmounted(() => window.removeEventListener('hashchange', onHashChange));

    return { state, routes, current, scheme, address, bootstrap, navigate };
  },
  template: `
    <div class="shell" v-if="state.ready">
      <aside class="sidebar">
        <div class="brand">Northstar<small>Monarch 运维端</small></div>
        <nav class="nav">
          <a v-for="item in routes" :key="item.path" :href="'#' + item.path"
             :class="{ active: item.path === state.route }">{{ item.label }}</a>
        </nav>
      </aside>
      <div class="main">
        <header class="topbar">
          <h1>
            <strong>{{ current.label }}</strong>
          </h1>
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
        请确认 Monarch 正在运行, 并通过本机地址访问本页面: http://127.0.0.1:7275
      </div>
      <div class="boot" v-else>正在连接 Monarch…</div>
      <div class="content"><button class="primary" @click="bootstrap()">重试</button></div>
    </div>`,
};

createApp(App).mount('#app');
