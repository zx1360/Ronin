## 项目说明 (Northstar)

Flutter Windows 桌面运维应用，Monarch 服务器的图形化管理面板。

### 页面与功能

| 页面 | 路由 | 功能 |
|------|------|------|
| 仪表盘 | `/dashboard` | 调用 `/API/ops/overview` 展示运行状态；服务启停后自动重取 |
| 漫画资源 | `/comix` | 网址下载（URL 直连）、漫画库（下载进度 + 公开/已读/封面/删除）、任务面板（生命周期/日志/中断）。 |
| 日志 | `/logs` | 查看任务实时输出 |
| 任务管理 | `/tasks` | 启停 Monarch、执行 Gallery/Comic CLI 任务 |
| 设置 | `/settings` | API 地址、API Key 等连接参数 |
| 帮助 | `/help` | 使用说明 |

### 任务类型

| 任务 | 模式 | 说明 |
|------|------|------|
| Monarch HTTPS | (默认) | HTTPS 生产模式，`X-API-Key` 鉴权 |
| Monarch Local | `-mode local` | HTTP 开发模式 |
| Gallery | `ingest`/`execute`/`refresh` | 媒体摄入/删除/刷新 |
| Comic Indexer | `refresh`/`full-reindex` | 增量/全量漫画索引 |

### 技术栈

Riverpod + GoRouter + SharedPreferences + `dart:io` HttpClient（自签证书信任）+ window_manager + system_tray。进程管理通过 `WindowsProcessManager`。

### 与后端协同

- 通过 `OpsApiClient` 调用 `/API/ops/overview`（含服务端 `staticDir` 绝对路径，供替换封面读写文件）；漫画库数据统一走 `ComixApiClient` 的 `/API/comix/list`（一次返回下载进度 + 公开/已读/封面/章节数），管理字段更新仍用 `PUT /API/comic/comic-info/{id}`。非 2xx 响应统一抛出 `OpsApiException`/`ComixApiException`。
- 任务模板 (`default_task_templates.dart`) 需对照 `../backend/gizmos/` 的 CLI 参数（`-mode`/`-gallery-root`/`-concurrency`/`-batch`/`-resize*`/`-root`），任何 CLI 参数变更须同步模板。
- 自签证书：`assets/cert/server.crt`。
- 后端接口变更后查看 `../backend/references/api/routes.json`。
- **mDNS 自动发现**：设置页点击"发现服务"可自动扫描局域网内的 Monarch 服务，发现后自动替换当前地址。

### 轮询与请求生命周期

- 仪表盘：`autoRefreshSeconds` 定时轮询；配置变更、以及本应用启停子进程后自动重取（服务启动后按 2s 重试至拿到数据）。
- 漫画任务面板：轮询由 `ComixBoardNotifier` 自管，仅在"有运行中任务"或"刚提交未出现在列表中"时按 `ComixBoardNotifier.pollInterval`（默认 2s）刷新，全部落定或页面离开后立即停止；
- 配置与任务档案在 `main()` 中通过 `bootstrap()` 预载完成后再 `runApp`：provider 的 `build()` 只能同步读取持久化值，否则首个请求会带默认地址发出。

### 数据持久化

SharedPreferences，数据保存在程序所在目录（非系统盘），便于迁移和备份。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，做好异常防护。除非明确要求，不引入破坏性修改。