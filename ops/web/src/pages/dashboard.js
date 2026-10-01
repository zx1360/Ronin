// 仪表盘：服务状态、数据库可达性与各目录用量。
//
// 数据来自 /API/ops/overview（服务端按 TTL 缓存目录用量），按偏好里的间隔轮询。

import { ref, onMounted } from '../vue.js';
import { api } from '../api.js';
import { state } from '../store.js';
import { usePolling, Card, Placeholder, Badge } from '../ui.js';
import { formatBytes, formatTime } from '../utils.js';

const STORAGE_LABELS = {
  static: '静态资源（_static）',
  galleryRoot: '媒体库根目录',
  galleryMedia: '媒体文件（Media）',
  galleryThumbs: '缩略图（Thumbs）',
  galleryPreview: '预览图（Preview）',
  galleryDeleted: '已删除（Deleted）',
};

export default {
  components: { Card, Placeholder, Badge },
  setup() {
    const overview = ref(null);
    const error = ref('');
    const updatedAt = ref(null);
    const loading = ref(false);

    const load = async () => {
      loading.value = true;
      try {
        overview.value = await api.get('/API/ops/overview', { timeoutMs: 30000 });
        error.value = '';
        updatedAt.value = new Date().toISOString();
      } catch (err) {
        error.value = err.message;
      } finally {
        loading.value = false;
      }
    };

    const poller = usePolling(load, {
      interval: () => state.settings.auto_refresh_seconds || 10,
      enabled: () => true,
    });

    onMounted(() => poller.trigger());

    const storageRows = () => {
      const storage = overview.value?.storage || {};
      return Object.keys(STORAGE_LABELS)
        .filter((key) => storage[key])
        .map((key) => ({ key, label: STORAGE_LABELS[key], ...storage[key] }));
    };

    return { state, overview, error, updatedAt, loading, storageRows, formatBytes, formatTime, load };
  },
  template: `
    <div>
      <div class="row between">
        <h1 class="page-title">仪表盘</h1>
        <div class="row">
          <span class="muted small" v-if="updatedAt">更新于 {{ formatTime(updatedAt) }}</span>
          <button class="ghost sm" :disabled="loading" @click="load()">{{ loading ? '刷新中…' : '刷新' }}</button>
        </div>
      </div>

      <Placeholder v-if="error" :error="'获取 /API/ops/overview 失败: ' + error" />

      <template v-if="overview">
        <div class="grid cols-3">
          <Card title="服务">
            <div class="col">
              <div class="row">
                <Badge :kind="overview.service.isLocalMode ? 'info' : 'primary'">
                  {{ overview.service.isLocalMode ? 'HTTP · 本地模式' : 'HTTPS · 生产模式' }}
                </Badge>
                <span class="muted">端口 {{ overview.service.port }}</span>
              </div>
              <div class="mono muted">{{ overview.service.staticDir }}</div>
              <div class="small" style="color: var(--error)" v-if="overview.service.staticDirError">
                {{ overview.service.staticDirError }}
              </div>
            </div>
          </Card>

          <Card title="数据库">
            <div class="col">
              <Badge :kind="overview.database.reachable ? 'success' : 'error'">
                {{ overview.database.reachable ? '可连接' : '不可用' }}
              </Badge>
              <div class="mono muted">{{ state.paths.dbFile }}</div>
              <div class="small" style="color: var(--error)" v-if="overview.database.error">{{ overview.database.error }}</div>
            </div>
          </Card>

          <Card title="本机依赖">
            <div class="col">
              <div class="row">
                <Badge :kind="state.cli.gallery.available ? 'success' : 'error'">
                  gallery CLI {{ state.cli.gallery.available ? '就绪' : '不可用' }}
                </Badge>
                <Badge :kind="state.deps.ffmpeg ? 'success' : 'warning'">
                  ffmpeg {{ state.deps.ffmpeg ? '就绪' : '缺失' }}
                </Badge>
                <Badge :kind="state.deps.ffprobe ? 'success' : 'warning'">
                  ffprobe {{ state.deps.ffprobe ? '就绪' : '缺失' }}
                </Badge>
              </div>
              <div class="mono muted">{{ state.cli.gallery.path }}</div>
              <div class="small" style="color: var(--warning)" v-if="!state.cli.gallery.available">
                {{ state.cli.gallery.message }}
              </div>
            </div>
          </Card>
        </div>

        <Card title="存储用量">
          <table class="data">
            <thead>
              <tr><th>目录</th><th>状态</th><th>文件数</th><th>体积</th><th>路径</th></tr>
            </thead>
            <tbody>
              <tr v-for="row in storageRows()" :key="row.key">
                <td>{{ row.label }}</td>
                <td>
                  <Badge :kind="row.exists ? 'success' : 'error'">{{ row.exists ? '存在' : '不存在' }}</Badge>
                  <span class="small" style="color: var(--error)" v-if="row.error"> {{ row.error }}</span>
                </td>
                <td>{{ row.files }}</td>
                <td>{{ formatBytes(row.bytes) }}</td>
                <td class="mono muted">{{ row.path }}</td>
              </tr>
            </tbody>
          </table>
        </Card>
      </template>
    </div>`,
};
