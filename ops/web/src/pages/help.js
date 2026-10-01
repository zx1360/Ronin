// 帮助：访问方式、本机能力边界、与旧桌面端的差异。

import { state } from '../store.js';
import { Card } from '../ui.js';

export default {
  components: { Card },
  setup() {
    return { state };
  },
  template: `
    <div>
      <h1 class="page-title">帮助</h1>

      <Card title="访问方式">
        <div class="col">
          <div>
            运维页面由 Monarch 自己托管，地址就是当前页面：
            <span class="mono">{{ state.service.isLocalMode ? 'http://127.0.0.1:7275/ops/' : 'https://127.0.0.1:7274/ops/' }}</span>
          </div>
          <div class="small muted">
            生产模式使用自签证书，浏览器首次访问需手动信任一次；页面与它的本机能力接口都只接受本机回环地址，
            局域网客户端打不开（这些操作本来就只在本机才有意义）。
          </div>
          <div class="small muted">
            API 密钥由服务端在引导接口里下发（<span class="mono">/API/ops/local/bootstrap</span>），
            不需要手工填写，也不写入浏览器存储。
          </div>
        </div>
      </Card>

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

      <Card title="相比旧桌面端丢掉的能力">
        <ul class="small" style="margin: 0; padding-left: 18px; line-height: 1.9">
          <li><b>启动 Monarch 自身</b>：页面就是 Monarch 托管的，服务没跑起来时页面也打不开，因此不再有这一项。</li>
          <li><b>系统托盘 / 窗口装饰 / 窗口尺寸记忆</b>：浏览器页面没有这些概念，改用浏览器标签页与书签。</li>
          <li><b>自定义可执行文件与参数预设</b>：运维端只托管项目内置的 gallery CLI，可执行文件与媒体库根目录都由
            <span class="mono">backend/.env</span> 决定，页面不再让用户填写任意路径。</li>
          <li><b>本地文件选择对话框</b>：浏览器无法读取服务端文件系统，需要定位文件时改用「打开所在目录」。</li>
        </ul>
      </Card>

      <Card title="gallery CLI">
        <div class="col small">
          <div>构建（在 <span class="mono">backend/gizmos</span> 下执行）：</div>
          <div class="mono">go build ./cmd/gallery</div>
          <div>产物即 <span class="mono">backend/gizmos/gallery.exe</span>；如需换位置，在 <span class="mono">backend/.env</span> 里设 <span class="mono">GALLERY_CLI</span>。</div>
          <div>任务由 Monarch 的任务引擎托管：同一时刻只允许一个 gallery 任务，中断会连同子进程一起结束。</div>
        </div>
      </Card>

      <Card title="数据放在哪">
        <div class="col small">
          <div>界面偏好：<span class="mono">static/data/ops_web.json</span></div>
          <div>AI 运行时配置：<span class="mono">static/data/ai_config.json</span></div>
          <div>数据库：<span class="mono">{{ state.paths.dbFile }}</span></div>
          <div>媒体库：<span class="mono">{{ state.paths.galleryDir }}</span></div>
          <div class="muted">全部随应用目录一起迁移/备份，不写用户目录。</div>
        </div>
      </Card>
    </div>`,
};
