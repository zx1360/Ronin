// 帮助：访问方式、本机能力边界、与旧桌面端的差异。

import { state } from '../store.js';
import { Card } from '../ui.js';

export default {
  components: { Card },
  setup() {
    return { state, origin: window.location.origin };
  },
  template: `
    <div>
      <Card title="本机能力由后端代理">
        <div class="col small">
          <div>页面本身没有本机权限，下列操作经 <span class="mono">/API/ops/local/*</span> 交由 Monarch 在本机执行：</div>
          <table class="data">
            <thead><tr><th>能力</th><th>接口</th><th>说明</th></tr></thead>
            <tbody>
              <tr><td>引导信息</td><td class="mono">GET /bootstrap</td><td>密钥、偏好、路径、组件可用性</td></tr>
              <tr><td>偏好读写</td><td class="mono">PUT /settings</td><td>写 static/data/ops_web.json</td></tr>
              <tr><td>资源管理器定位</td><td class="mono">POST /reveal</td><td>按绝对路径或库内相对路径打开并选中</td></tr>
              <tr><td>Gallery 任务</td><td class="mono">GET/POST /tasks</td><td>启停内置 gallery CLI，查看状态与日志</td></tr>
            </tbody>
          </table>
        </div>
      </Card>

      <Card title="gallery CLI">
        <div class="col small">
          <div>产物即 <span class="mono">backend/gizmos/gallery.exe</span>；如需换位置，在 <span class="mono">backend/.env</span> 里设 <span class="mono">GALLERY_CLI</span>。</div>
          <div>任务由 Monarch 的任务引擎托管：同一时刻只允许一个 gallery 任务，中断会连同子进程一起结束。</div>
        </div>
      </Card>

      <Card title="数据文件位置">
        <div class="col small">
          <div>运维端偏好：<span class="mono">static/data/ops_web.json</span></div>
          <div>AI 运行时配置：<span class="mono">static/data/ai_config.json</span></div>
          <div>数据库：<span class="mono">{{ state.paths.dbFile }}</span></div>
          <div>媒体库：<span class="mono">{{ state.paths.galleryDir }}</span></div>
          <div class="muted">全部随应用目录一起迁移/备份，不写用户目录。(TODO:)</div>
        </div>
      </Card>
    </div>`,
};
