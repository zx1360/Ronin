// 设置：界面偏好（写回服务端 static/data/ops_web.json）与服务端信息只读展示。

import { ref, computed, onMounted } from '../vue.js';
import { state, saveSettings, toast } from '../store.js';
import { Card, Badge } from '../ui.js';

export default {
  components: { Card, Badge },
  setup() {
    // 字段名与服务端 JSON（ops_web.json）保持一致，避免两套命名互相覆盖
    const form = ref({
      auto_refresh_seconds: 10,
      ai_refresh_seconds: 3,
      log_line_limit: 800,
      confirm_destructive: true,
    });
    const saving = ref(false);
    const showKey = ref(false);

    onMounted(() => Object.assign(form.value, state.settings));

    const save = async () => {
      saving.value = true;
      try {
        await saveSettings({ ...form.value });
        toast('偏好已保存到服务端', 'success');
      } catch (err) {
        toast(`保存失败: ${err.message}`, 'error');
      } finally {
        saving.value = false;
      }
    };

    const maskedKey = computed(() => {
      const key = state.apiKey || '';
      if (!key) return '（服务端未启用鉴权）';
      if (showKey.value) return key;
      return `${key.slice(0, 6)}${'*'.repeat(Math.max(4, key.length - 10))}${key.slice(-4)}`;
    });

    const origin = window.location.origin;

    return { state, form, saving, showKey, maskedKey, origin, save };
  },
  template: `
    <div>
      <h1 class="page-title">设置</h1>

      <Card title="界面偏好">
        <template #actions>
          <button class="primary sm" :disabled="saving" @click="save()">{{ saving ? '保存中…' : '保存' }}</button>
        </template>
        <div class="grid cols-2">
          <label class="field">
            仪表盘刷新间隔（秒，5-3600）
            <input type="number" min="5" max="3600" v-model.number="form.auto_refresh_seconds" />
          </label>
          <label class="field">
            AI 页轮询间隔（秒，2-60）
            <input type="number" min="2" max="60" v-model.number="form.ai_refresh_seconds" />
          </label>
          <label class="field">
            日志页保留行数（100-5000）
            <input type="number" min="100" max="5000" v-model.number="form.log_line_limit" />
          </label>
          <label class="field">
            破坏性操作二次确认
            <span class="row" style="gap: 6px">
              <input type="checkbox" v-model="form.confirm_destructive" />
              <span class="small muted">关闭后中断任务、全量重生成等操作立即执行</span>
            </span>
          </label>
        </div>
        <div class="small muted" style="margin-top: 10px">
          偏好由 Monarch 持有：<span class="mono">{{ state.settingsPath }}</span>
        </div>
      </Card>

      <Card title="连接">
        <div class="grid cols-2">
          <div class="col">
            <div class="small muted">服务地址（同源，页面由该服务托管）</div>
            <div class="mono">{{ origin }}</div>
            <div class="small muted">API 密钥（服务端下发，仅本机可见）</div>
            <div class="row">
              <span class="mono">{{ maskedKey }}</span>
              <button class="ghost sm" @click="showKey = !showKey">{{ showKey ? '隐藏' : '显示' }}</button>
            </div>
          </div>
          <div class="col">
            <div class="small muted">运行模式</div>
            <div>
              <Badge kind="primary">X-API-Key 鉴权</Badge>
              <span class="muted"> 端口 {{ state.service.port }}</span>
            </div>
            <div class="small muted">本机能力接口仅回环可用：<span class="mono">/API/ops/local/*</span></div>
          </div>
        </div>
      </Card>

      <Card title="服务端路径">
        <table class="data">
          <tbody>
            <tr><th style="width: 180px">静态资源目录</th><td class="mono">{{ state.paths.staticDir }}</td></tr>
            <tr><th>媒体库根目录</th><td class="mono">{{ state.paths.galleryDir }}</td></tr>
            <tr><th>媒体文件目录</th><td class="mono">{{ state.paths.galleryMedia }}</td></tr>
            <tr><th>数据库文件</th><td class="mono">{{ state.paths.dbFile }}</td></tr>
            <tr><th>网页端目录</th><td class="mono">{{ state.paths.opsWebDir }}</td></tr>
          </tbody>
        </table>
      </Card>

      <Card title="本机组件">
        <table class="data">
          <thead><tr><th>组件</th><th>状态</th><th>说明</th></tr></thead>
          <tbody>
            <tr>
              <td>gallery CLI</td>
              <td><Badge :kind="state.cli.gallery.available ? 'success' : 'error'">
                {{ state.cli.gallery.available ? '就绪' : '不可用' }}</Badge></td>
              <td class="mono">{{ state.cli.gallery.available ? state.cli.gallery.path : state.cli.gallery.message }}</td>
            </tr>
            <tr>
              <td>comix 爬虫</td>
              <td><Badge :kind="state.cli.comix.available ? 'success' : 'error'">
                {{ state.cli.comix.available ? '就绪' : '不可用' }}</Badge></td>
              <td class="mono">{{ state.cli.comix.available ? state.cli.comix.root : state.cli.comix.message }}</td>
            </tr>
            <tr>
              <td>ffmpeg</td>
              <td><Badge :kind="state.deps.ffmpeg ? 'success' : 'warning'">
                {{ state.deps.ffmpeg ? '就绪' : '缺失' }}</Badge></td>
              <td class="small muted">视频处理与取帧（视频剪辑功能依赖）</td>
            </tr>
            <tr>
              <td>ffprobe</td>
              <td><Badge :kind="state.deps.ffprobe ? 'success' : 'warning'">
                {{ state.deps.ffprobe ? '就绪' : '缺失' }}</Badge></td>
              <td class="small muted">视频时长/分辨率探测</td>
            </tr>
          </tbody>
        </table>
      </Card>
    </div>`,
};
