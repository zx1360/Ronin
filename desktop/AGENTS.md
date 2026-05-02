## 项目说明 (Northstar)

Flutter 开发的 Windows 桌面运维应用，Ronin 三端架构的管理控制端。

### 应用定位

Monarch 服务器的图形化管理面板。负责启动/停止/监控 HTTP 服务，触发 CLI 批处理任务（媒体摄入、漫画索引）。

### 页面与功能

| 页面 | 路由 | 功能 |
|------|------|------|
| 仪表盘 | `/dashboard` | 调用 `/API/ops/overview` 展示 Monarch 运行状态 |
| 任务管理 | `/tasks` | 管理 Monarch 服务启停，执行 Gallery / Comic CLI 任务 |
| 日志 | `/logs` | 查看各任务实时运行输出 |
| 设置 | `/settings` | 配置 API 地址、API Key 等连接参数 |
| 帮助 | `/help` | 使用说明 |

### 任务类型

| 任务 | 模式/预设 | 说明 |
|------|----------|------|
| Monarch Local | `-mode local` | HTTP 开发模式启动 |
| Monarch HTTPS | (默认) | HTTPS 生产模式启动，`X-API-Key` 鉴权 |
| Gallery | `ingest` / `execute` / `refresh` | 媒体文件摄入→缩略图→归档 / 执行客户端删除 / 刷新元数据 |
| Comic Indexer | `refresh` / `full-reindex` | 增量搜索漫画 / 全量重建索引 |

### 技术栈

| 领域 | 依赖 |
|------|------|
| 状态管理 | Riverpod + riverpod_generator |
| 路由 | GoRouter |
| 本地存储 | SharedPreferences |
| 桌面特性 | window_manager (窗口控制), system_tray (系统托盘) |
| 网络请求 | `dart:io` HttpClient + 自签证书信任 |
| 进程管理 | 通过 `WindowsProcessManager` 启动/停止外部可执行程序 |

### 与后端协同

- 通过 `OpsApiClient` 调用 Monarch 的 `/API/ops/overview` 获取服务状态。
- 任务模板 (`default_task_templates.dart`) 中的 CLI 参数需对照 `../backend/gizmos/` 的 `-h` 输出保持同步。
- 自签证书：`assets/cert/server.crt`，由 `OpsApiClient` 在 HTTPS 模式下加载并建立受限信任链。
- 后端接口变更后，查看 `../backend/references/api/routes.json` 确认 `/API/ops` 路由无破坏性变动。

### 数据持久化

使用 SharedPreferences，数据保存在程序所在目录（非系统盘），便于自用场景下迁移和备份。

### 硬性要求（AI 辅助开发备忘）

- 参考 `../backend/references/` 目录下的契约文件。
- UI 简约美观，交互友好。
- 考虑边界情况，做好异常防护。
- 除非明确要求，不引入破坏性修改。
- 注意代码可维护性。

### 关联项目

- 后端 API 服务器: `../backend/` (Monarch)
- 安卓移动端: `../android/` (Torrid)