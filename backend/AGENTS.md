## 项目说明 (Monarch)

Ronin 三端架构的"唯一真理"层，Go 语言开发。

### 模块

- **Monarch HTTP**：Gin 服务器，为 Torrid (Android) 和 Northstar (Desktop) 提供 REST API。
- **Gizmos CLI**（`gizmos/`）：独立 Go module，命令行批处理（漫画索引、媒体摄入/刷新/删除）。
- **comix 爬虫集成**（`internal/service/comix/` + `internal/handler/comix_handler/`）：以子进程方式调用
  外部 comix 项目（`python -m comix.cli --json <cmd>`，协议见 comix `docs/协议文档.md`），
  提供 `/API/comix/*` 接口并由服务端**任务引擎管理爬虫生命周期**（状态/日志/中断/孤儿回收）。

### comix 集成要点

- 职责边界：**Go 端负责全部查询与删除**（`sites`/`list`/`chapters` 直查 `comix.*` 表，单条 SQL
  聚合，毫秒级；删除为改名目录→DB 级联→移除，DB 失败自动回滚改名，支持 `keep_files`）。
  **Python 端只保留爬虫操作**（`search`/`add`/`add-url`/`download`/`update-check`/`clean`/`init`）。
- 配置：`.env` 的 `COMIX_PYTHON`（默认 `python`，LookPath 解析绝对路径）与 `COMIX_ROOT`
  （comix 项目根目录，必须含 `.env` 与 `util` 包）。未配置时 `/API/comix/config` 返回
  `available=false`，其余接口返回明确错误。
- 接口分两类：**同步直查库**（`config`/`sites`/`list`/`chapters`/`delete`）与**异步任务**
  （`search`/`add`/`add-url`/`download`/`update-check`/`clean`）。
  异步任务经 `POST /API/comix/tasks/:id/stop` 中断（`process.Kill` + `taskkill /T /F` 进程树），
  中断残留由 comix 的 `download` 自愈或 `clean` 全局回收。
- 响应遵循 comix 协议：业务错误（`ok=false`，如多候选带 `candidates`）返回 HTTP 200，
  仅传输/配置级故障返回 HTTP 500。
- 漫画文件存储在 comix `.env` 的 `COMIC_STORAGE_ROOT`（本环境为 `static/comics`，经 `/static/*`
  直接可访问）。Go 端删除通过读取 comix `.env` 解析存储根（`comix.StorageRoot`），不重复维护。
- `/API/ops/overview`：gallery Media/Deleted 用 `gallery.media_assets` 聚合（DB 毫秒级），
  static 等目录用量由后台 TTL 缓存遍历提供（`util_handler.StartDirUsageRefresher`，5 分钟刷新、
  启动预热），**不修改任何表结构**。

### 技术栈

Go + Gin + pgx + PostgreSQL 18.0。支持 HTTP/HTTPS（自签证书），`X-API-Key` 鉴权。Immich 反向代理（`/api/*` → `127.0.0.1:2283`）。启动时自动通过 mDNS (`_monarch._tcp`) 注册服务，供客户端自动发现。

### 快速启动

```bash
go run ./cmd -mode local    # 开发模式 (HTTP, 无鉴权)
go run ./cmd                # 生产模式 (HTTPS, X-API-Key 鉴权)
```

### 环境变量 (.env)

`LOCAL_PORT`, `LOCAL_DEBUG_PORT`, `STATIC_DIR`, `GALLERY_DIR`, `COMIC_DIR`, `DB_IP/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME`

### API 概览

| 路由组 | 关键端点 | 用途 |
|--------|---------|------|
| `/API/user-data` | `GET /sync/:module`, `POST /backup/:module` | 用户数据同步/备份 |
| `/API/comic` | `/meta-info`, `/comic-info`, `/chapter-info`, `/download` | 漫画浏览与离线下载 |
| `/API/gallery` | `/batch`, `/tags`, `/:id/:type`, `POST /push` | 媒体资产浏览、文件流、推送 |
| `/API/ops` | `GET /overview` | 系统概览（Desktop 用） |
| `/api/*` | 所有方法 | Immich 反向代理 |

### CLI 工具 (Gizmos)

详见 `references/cli/`。主要命令: Comic Indexer（`refresh`/`full-reindex`）、Gallery（`ingest`/`execute`/`refresh`）。

### 跨项目契约

修改 Go 接口或 CLI 后运行：
```powershell
powershell -ExecutionPolicy Bypass -File .\references\scripts\generate_refs.ps1
```
### 数据库

表定义及触发器见 `AGENTS_DB.md`（索引）和 `references/db/`（分模块明细）.

### 硬性要求

- 考虑边界情况, 做好异常防护.
- 除非明确要求, 不对已有功能引入破坏性修改.
- 更新数据库记录时显式更新所有字段值.
- 注意代码可维护性.