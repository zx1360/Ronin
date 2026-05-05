## 项目说明 (Northstar)

Flutter Windows 桌面运维应用，Monarch 服务器的图形化管理面板。

### 页面与功能

| 页面 | 路由 | 功能 |
|------|------|------|
| 仪表盘 | `/dashboard` | 调用 `/API/ops/overview` 展示运行状态 |
| 漫画管理 | `/comics` | 管理后端漫画资源 |
| 日志 | `/logs` | 查看任务实时输出 |
| 任务管理 | `/tasks` | 启停 Monarch、执行 Gallery/Comic CLI 任务 |
| 设置 | `/settings` | API 地址、API Key 等连接参数 |
| 帮助 | `/help` | 使用说明 |

### 任务类型

| 任务 | 模式 | 说明 |
|------|------|------|
| Monarch Local | `-mode local` | HTTP 开发模式 |
| Monarch HTTPS | (默认) | HTTPS 生产模式，`X-API-Key` 鉴权 |
| Gallery | `ingest`/`execute`/`refresh` | 媒体摄入/删除/刷新 |
| Comic Indexer | `refresh`/`full-reindex` | 增量/全量漫画索引 |

### 技术栈

Riverpod + GoRouter + SharedPreferences + `dart:io` HttpClient（自签证书信任）+ window_manager + system_tray。进程管理通过 `WindowsProcessManager`。

### 与后端协同

- 通过 `OpsApiClient` 调用 `/API/ops/overview`。
- 任务模板 (`default_task_templates.dart`) 需对照 `../backend/gizmos/` 的 CLI 参数。
- 自签证书：`assets/cert/server.crt`。
- 后端接口变更后查看 `../backend/references/api/routes.json`。

### 数据持久化

SharedPreferences，数据保存在程序所在目录（非系统盘），便于迁移和备份。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，做好异常防护。除非明确要求，不引入破坏性修改。