## 项目说明 (Northstar)

Flutter Windows 桌面运维应用，Monarch 服务器的图形化管理面板。

### 页面与功能

| 页面 | 路由 | 功能 |
|------|------|------|
| 仪表盘 | `/dashboard` | 调用 `/API/ops/overview` 展示运行状态 |
| 漫画管理 | `/comics` | 管理后端漫画资源 |
| 漫画爬虫 | `/comix` | comix 爬虫管理：URL 直连下载/追更/删除 + 任务生命周期面板 |
| 日志 | `/logs` | 查看任务实时输出 |
| 任务管理 | `/tasks` | 启停 Monarch、执行 Gallery/Comic CLI 任务 |
| 设置 | `/settings` | API 地址、API Key 等连接参数 |
| 帮助 | `/help` | 使用说明 |

### comix 爬虫页（`/comix`）

- 布局为 **4 个 Tab**（网址下载 / 漫画列表 / 任务面板 / 设置），各 Tab 独立滚动互不挤压。
- 通过本地 HTTP 向 Monarch `/API/comix/*` 发送指令（`ComixApiClient`，复用 OpsSettings 的
  apiBaseUrl/apiKey 与 CertTrust 自签证书信任）；**爬虫生命周期由 Go 端任务引擎管理**。
- **下载入口为「网址下载」Tab**：粘贴漫画详情页 URL（多行/多个并发），服务端自动识别站点
  （`POST /API/comix/download-url`），可选"仅下载最新 N 章"；提交结果显示每个 URL 的
  站点识别与任务状态。按名搜索候选下载功能已移除。
- 代码分层：`domain/comix/models/`（模型）、`infrastructure/comix/comix_api_client.dart`、
  `application/comix/providers/`（任务面板状态）、`ui/comix/`（页面/Tab/对话框）。
- **查询数据（站点/漫画列表/章节）由 Go 端直查库提供（毫秒级）**；下载/追更/清理为
  异步任务，页面每 2s 轮询任务状态与日志，运行中任务可一键中断；任务结束自动刷新漫画列表。
- **删除为同步调用**（Go 端直查库：DB 级联 + 文件删除，可 keep-files），大漫画删除时显示
  加载遮罩，结果含 `files_removed`/`leftover_path`。
- 任务结果经 `GET /API/comix/tasks/:id` 的 `result` 字段读取（`add-url` 下载结果嵌套于
  `data.download`，任务摘要已解包展示）；章节对话框带关键词过滤（大章节数漫画）。

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

- 通过 `OpsApiClient` 调用 `/API/ops/overview` 及漫画管理接口；非 2xx 响应统一抛出 `OpsApiException`（含状态码与服务端错误体），UI 不直接处理底层协议细节。
- 任务模板 (`default_task_templates.dart`) 需对照 `../backend/gizmos/` 的 CLI 参数（`-mode`/`-gallery-root`/`-concurrency`/`-batch`/`-resize*`/`-root`），任何 CLI 参数变更须同步模板。
- 自签证书：`assets/cert/server.crt`。
- 后端接口变更后查看 `../backend/references/api/routes.json`。
- **mDNS 自动发现**：设置页点击"发现服务"可自动扫描局域网内的 Monarch 服务，发现后自动替换当前地址。

### 数据持久化

SharedPreferences，数据保存在程序所在目录（非系统盘），便于迁移和备份。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，做好异常防护。除非明确要求，不引入破坏性修改。