## 项目说明 (Ronin 运维台)

Monarch 服务器的运维网页端。原是 Flutter Windows 桌面应用（Northstar），现为**无构建的静态页面**：
纯 HTML + CSS + ES 模块，由后端直接托管。`cd backend && go run ./cmd -mode local` 后
打开 `http://127.0.0.1:<LOCAL_DEBUG_PORT>/ops/`（生产模式同样另开回环 HTTP 提供该页面）。

### 约定

- 页面挂在 `/ops` 下：自有资源一律相对路径（`./app.css`、`./js/main.js`）；接口用绝对 `/API/...`
  （同源，回环请求被后端直接放行，无需 `X-API-Key`）。`/ops` 页面本身与 `/API/ops/*`、
  `/API/settings` 都只对本机回环开放。
- 页面**没有**本机权限：进程/任务生命周期、模型与侧车启停、路径定位（`POST /API/ops/reveal`）、
  目录选择（`GET /API/ops/fs`）、配置读写（`/API/settings`，仅回环）全部走 `/API/*` 回环接口。
- 任务种类、参数默认值（含某模式是否接受 resize 参数）、能力与模型候选及切换用的配置键、
  配置项（键/标签/控件/范围/候选项）一律由后端下发（`/API/ops/capabilities`、
  `/API/ai/capabilities` 的 `setting_key`、`/API/settings` 的 `schema`）——页面只渲染。
- 端点路径取自契约生成物 `js/generated/endpoints.js`（`cd backend && pwsh references/scripts/generate_refs.ps1`
  一次生成 routes/contract 与两端客户端文件，勿手改）；UI 偏好存后端 `/API/ops/preferences`，不用 localStorage。

### 刻意去掉

系统托盘、自绘窗口与窗口装饰、启动/停止 Monarch 自身、自定义任务档案与自选可执行文件、
漫画「替换封面」、桌面端的本地缓存与自签证书信任。

### 硬性要求

- 不引入构建步骤、包管理器、CDN 与框架；只用原生 DOM（`js/dom.js` 的 `el()` + 每视图 render 函数），
  任务面板的公共零件（状态徽章/日志面板/自动滚动开关）放 `js/tasks.js`。
- 文案全中文；宽屏左导航 + 内容区，深色紧凑。
- 请求失败如实展示服务端 `error`，不得静默假装成功；comix 的 `{ok:false}` 即使 HTTP 200 也算失败。
- 轮询按需：媒体库/漫画任务仅在"有运行中任务"或提交后宽限期内按 2s 轮询；AI 仅在队列或模型进程活跃时轮询。
