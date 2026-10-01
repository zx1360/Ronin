## 项目说明 (Northstar)

Monarch 的网页运维端：源码在 `ops/web/`，由后端内置 HTTP 服务托管（`/ops/`）。
没有桌面端、没有构建步骤。

### 访问方式

| 入口 | 地址 |
|------|------|
| 入口（两个端口接口一致，只有协议不同） | `http://127.0.0.1:7275/ops/`（本机浏览器用，无证书警告）<br>`https://127.0.0.1:7274/ops/`（自签证书，首次需信任一次） |

页面与其本机能力接口（`/API/ops/local/*`）都只接受回环地址，局域网访问一律 403；
API 密钥由服务端在引导接口里下发，不需要手填，也不写浏览器存储。

### 页面

| 页面 | 路由 | 功能 |
|------|------|------|
| 仪表盘 | `/dashboard` | `/API/ops/overview`：服务/数据库/存储用量与本机依赖，按偏好间隔轮询 |
| AI 媒体处理 | `/ai` | 概览（能力就绪、进度与待重排、模型/侧车进程启停、VLM 标注模型切换、重试失败项/补处理/全量重生成、暂停与继续、运行时配置）、任务队列、人物分组（改名/合并/删除/人工纠正/重聚类）、检索（智能/语义/文字/文件名 + 以图搜图 + 结构筛选）、近重复（pHash 分组、标记软删除/非重复）、已软删除清单与恢复 |
| 漫画资源 | `/comix` | 网址下载（站点列表 + 批量 URL）、漫画库（下载进度/公开/已读/封面/删除/追更检查/孤儿回收/章节查看）、任务面板（生命周期/日志/中断） |
| 任务管理 | `/tasks` | 内置 gallery CLI 任务：`ingest`/`execute`/`refresh` 参数与启停（同一时刻只允许一个） |
| 日志 | `/logs` | gallery 与 comix 任务的实时输出：合并列表、关键字过滤、自动滚动、复制 |
| 设置 | `/settings` | 界面偏好（写服务端）+ 路径/组件/依赖只读展示 |
| 帮助 | `/help` | 访问方式、本机能力边界、相比旧桌面端丢掉的能力 |

### 技术栈与目录

内置 Vue 3（`vendor/vue.esm-browser.prod.js`，含模板编译器的 ESM 浏览器构建）+ 原生 ES 模块。
**无构建步骤、无 npm**：改完刷新浏览器即生效；第三方库只能以单文件放进 `vendor/`。

- `index.html` 入口；`src/main.js` 侧边导航与 hash 路由
- `src/api.js` 请求层（同源 + `X-API-Key`）；`assetUrl()` 给 `<img>` 拼 `api_key` 查询参数
- `src/store.js` 全局状态与引导、`toast`、`confirmAction`；`src/ui.js` 共享组件与 `usePolling`；`src/utils.js` 格式化
- `src/pages/*.js` 页面；体量大的按 tab 拆到同名子目录（`pages/ai/`、`pages/comix/`）

### 大数据量页面约定

条数可能远超一屏（AI 任务队列、pHash 分组、已删除清单、检索结果）时**不要一次性全渲染**：
分页或「加载更多」+ 主区域滚动 + 表头吸顶优先，确有需要的固定高度用 `.scroll-panel`
（共用样式在 `assets/app.css`）。分组类数据（近重复）默认折叠，展开后才挂载缩略图。

### 与后端协同

- 启动时一次 `GET /API/ops/local/bootstrap`：API 密钥、界面偏好、服务端绝对路径、CLI 与依赖可用性。
- 页面做不到的本机操作一律走 `/API/ops/local/*`：偏好写 `<STATIC_DIR>/data/ops_web.json`、
  `POST /reveal` 资源管理器定位、`GET/POST /tasks` 托管 gallery CLI。
- 其余数据直接调 `/API/ai/*`、`/API/comix/*`、`/API/gallery/*`；gallery 任务列表在 `/API/ops/local/tasks`，
  comix 任务列表在 `/API/comix/tasks`（日志页合并展示）。
- 偏好字段名与 `ops_web.json` 一致（snake_case），不要另起一套命名：两套键会互相覆盖。
- 破坏性操作（软删除、全量重生成、重新聚类、删除漫画、中断任务）必须 `confirmAction` 二次确认，
  设置页可整体关闭。
- 后端接口变更后查看 `../backend/references/generated/api/routes.md`（生成物，需在后端跑一次
  `references/scripts/generate_refs.ps1`）。

### 轮询

只在「有进行中的任务/进程」时轮询，`usePolling` 会随组件卸载自动停止：
仪表盘按 `settings.auto_refresh_seconds`、AI 页按 `settings.ai_refresh_seconds`、任务与日志页固定 2 秒。

### 数据持久化

界面偏好由服务端持有（`static/data/ops_web.json`），页面只在内存中镜像，
**不写 localStorage / cookie / 用户目录**。

### 已明确丢弃的桌面端能力

系统托盘、窗口装饰与窗口尺寸记忆、启动 Monarch 自身（页面就是 Monarch 托管的）、
自定义可执行文件与参数预设、本地文件选择对话框。

### 硬性要求

- 界面简约美观、中文、术语沿用原桌面端；文案只讲用户需要知道的，不写实现细节。
- 无构建步骤：不引入 npm/打包器/外部 CDN。
- 考虑边界情况：接口失败、`ok:false` 业务错误、字段缺失、空列表都要有可读提示，不能白屏。
- 模板表达式里不用 `?.`/`??`（Vue 模板不支持），在 setup 里算好再暴露。
