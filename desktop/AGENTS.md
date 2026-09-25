## 项目说明 (Northstar)

Flutter Windows 桌面运维应用，Monarch 服务器的图形化管理面板。

### 页面与功能

| 页面 | 路由 | 功能 |
|------|------|------|
| 仪表盘 | `/dashboard` | 调用 `/API/ops/overview` 展示运行状态；服务启停后自动重取 |
| AI 媒体处理 | `/ai` | 调用 `/API/ai/*`：能力就绪状态与进度、模型/侧车进程启停、失败重试、暂停/继续处理、人物分组（改名/合并/删除/重聚类）、文本搜图（智能/文字/文件名）与以图搜图、pHash 近重复分组 |
| 漫画资源 | `/comix` | 网址下载（URL 直连）、漫画库（下载进度 + 公开/已读/封面/删除）、任务面板（生命周期/日志/中断）。 |
| 日志 | `/logs` | 查看任务实时输出 |
| 任务管理 | `/tasks` | 启停 Monarch、执行 Gallery CLI 任务 |
| 设置 | `/settings` | API 地址、API Key 等连接参数 |
| 帮助 | `/help` | 使用说明 |

### 任务类型

| 任务 | 模式 | 说明 |
|------|------|------|
| Monarch HTTPS | (默认) | HTTPS 生产模式，`X-API-Key` 鉴权 |
| Monarch Local | `-mode local` | HTTP 开发模式 |
| Gallery | `ingest`/`execute`/`refresh` | 媒体摄入/删除/刷新 |

### 技术栈

Riverpod + GoRouter + SharedPreferences + `dart:io` HttpClient（自签证书信任）+ window_manager + system_tray。进程管理通过 `WindowsProcessManager`。

### 与后端协同

- 通过 `OpsApiClient` 调用 `/API/ops/overview`（含服务端 `staticDir` 绝对路径，供替换封面读写文件）；漫画库数据统一走 `ComixApiClient` 的 `/API/comix/list`（一次返回下载进度 + 公开/已读/封面/章节数），管理字段更新仍用 `PUT /API/comic/comic-info/{id}`。非 2xx 响应统一抛出 `OpsApiException`/`ComixApiException`。
- AI 页面数据走 `AiApiClient`（`infrastructure/ai/`，`/API/ai/*`，异常为 `AiApiException`）。
  - AI 无需本地子进程管理：模型进程由 **Monarch 侧**按需拉起/空闲回收，桌面端只调 `POST /API/ai/process/:capability/start|stop`。
  - 结果缩略图直接 `Image.network(.../API/gallery/{id}/thumb)`：`CertTrust` 的全局 HttpOverrides 已负责自签证书与 API Key 注入。
  - 增量聚类（保留现有人物命名）是默认操作；"重新聚类"会清空分组，必须二次确认。
  - "暂停处理"= `POST /api/ai/cancel`（中断当前批次**并暂停认领新任务**），"继续处理" = `POST /api/ai/resume`；只中断不暂停没有意义（worker 会立刻认领下一批）。
- 两个 HTTP 客户端共用的 URL 规范化/请求头/URI 构建/错误解码在 `infrastructure/api_http_helper.dart`，新增客户端请复用它而不是复制一份。
- `X-API-Key` 只注入到"当前配置的 Monarch 主机"，不会随 `HttpOverrides` 泄漏给第三方站点（如漫画封面源站）。
- 任务模板 (`default_task_templates.dart`) 需对照 `../backend/gizmos/` 的 CLI 参数（`-mode`/`-gallery-root`/`-concurrency`/`-batch`/`-resize*`），任何 CLI 参数变更须同步模板。`-gallery-root` 现在是**必填**项。
- 自签证书：`assets/cert/server.crt`。
- 后端接口变更后查看 `../backend/references/api/routes.json`。
- **mDNS 自动发现**：设置页点击"发现服务"可自动扫描局域网内的 Monarch 服务，发现后自动替换当前地址。

### 轮询与请求生命周期

- 仪表盘：`autoRefreshSeconds` 定时轮询；配置变更、以及本应用启停子进程后自动重取（服务启动后按 2s 重试至拿到数据）。
- 漫画任务面板：轮询由 `ComixBoardNotifier` 自管，仅在"有运行中任务"或"刚提交未出现在列表中"时按 `ComixBoardNotifier.pollInterval`（默认 2s）刷新，全部落定或页面离开后立即停止。页面是否活跃由 `ShellPage` 依据 `navigationShell.currentIndex` 驱动（`StatefulShellRoute.indexedStack` 不会销毁离开的分支，因此不能依赖 `dispose`）。
- AI 页面：同样的"按需轮询"策略在 `AiBoardNotifier`（有排队/运行中任务或模型进程在跑时才轮询），可见性同样由 `ShellPage._syncComixPageActive` 统一分发。
- 配置与任务档案在 `main()` 中通过 `bootstrap()` 预载完成后再 `runApp`：provider 的 `build()` 只能同步读取持久化值，否则首个请求会带默认地址发出。

### 数据持久化

JSON 文件存放在程序所在目录的 `northstar_data/ops/`（非系统盘），便于迁移和备份；早期版本的 SharedPreferences 数据会在首次启动时自动迁移。写入失败会如实反馈到设置页，不再静默显示"已保存"。

### 界面响应性

Northstar 的 UI isolate 不做任何计算密集工作（无 `compute`/`Isolate`、无同步文件 IO），
AI 推理全部在 Monarch 及其子进程里。因此"跑 AI 任务时界面发卡"的成因是**跨进程 CPU 争抢**，
对策在服务端：Monarch 把 Python 侧车与自拉的 Ollama 降到 BelowNormal 优先级
（`backend/internal/service/ai/priority_windows.go`），前台交互始终优先拿到 CPU。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，做好异常防护。除非明确要求，不引入破坏性修改。
