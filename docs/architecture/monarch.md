# Monarch 后端架构

## 1. 启动装配顺序

[cmd/main.go](../../backend/cmd/main.go) 是唯一启动入口，顺序体现了依赖关系：

1. `config.Load()` 读取 `.env` 和运行配置。
2. 创建并加载 `ai_config.json` 对应的 `ConfigStore`。
3. `db.Init()` 打开 SQLite，应用幂等 schema 和列迁移。
4. 创建并加载 `ops_web.json` 对应的 `OpsStore`，注入 Ops handler。
5. 创建 AI `Engine`，注入暂停状态存储并启动后台循环。
6. 启动 HTTP/HTTPS 双端口；信号或监听失败会取消请求，关闭监听与 mDNS，等待 AI、Gallery、comix 退出后关闭数据库。服务层返回错误，不结束进程。

这意味着 handler 不应自行创建数据库、配置或外部进程；这些资源由启动装配提供全局服务门面。

## 2. 请求层次

```text
Gin middleware
  ├─ CORS
  ├─ selectiveAuth()
  ├─ /static 与 /ops 静态托管
  └─ /API
      ├─ handler：HTTP 参数、状态码、响应 DTO
      ├─ service：任务、AI、媒体探测、review、外部进程
      ├─ repository：SQL、事务、领域查询
      └─ model：跨层数据结构
```

入口文件：

- [router.SetupRouter](../../backend/internal/router/router.go)：全部路由和 middleware。
- [http_server.StartServer](../../backend/internal/service/server/http_server.go)：双端口、证书、mDNS。
- [auth middleware](../../backend/internal/handler/util_handler/auth_middleware.go)：API key、回环豁免和失败封禁。

完整路由清单见 [routes.md](../../backend/references/generated/api/routes.md)。快照是导航工具，不是路由真源。

## 3. API 分区

| 路由组 | 主要消费者 | 责任 |
| --- | --- | --- |
| `/API/user-data` | Torrid + Northstar | 随笔、打卡增量合并、删除标记、图片检查 |
| `/API/comic` | Torrid | 阅读侧漫画列表、章节、图片和设备下载 |
| `/API/gallery` | Torrid + Northstar | 媒体查询、标签、标注、批次缓存和文件 |
| `/API/ai` | Torrid + Northstar | AI 状态、队列、检索、人物、聊天、近期回顾 |
| `/API/comix` | Northstar | Python 爬虫配置、库、下载和任务生命周期 |
| `/API/ops/overview` | Northstar | 系统状态概览 |
| `/API/ops/local` | Northstar（仅回环） | bootstrap、偏好、资源管理器、Gallery CLI 任务 |

### 鉴权模型

- 业务 API 和媒体使用 `X-API-Key`。未配置密钥时只接受本机同源请求。
- `/API/test` 免鉴权。Ops 页面和本机接口由 `LocalOnly` 校验 TCP 回环、Host 与浏览器来源，网页资源的 `api_key` 查询参数也受此限制。
- 非回环错误 API key 按 IP 计数并持久化封禁；回环地址永不封禁，避免 bootstrap/密钥轮换把本机锁死。

## 4. SQLite 设计

[db.Init](../../backend/internal/service/db/db.go) 建立两个连接池：

- 写连接池：最多一个连接，`_txlock=immediate`，WAL、foreign keys、busy timeout。
- 读连接池：可并发读取，WAL 下与写入互不阻塞。
- 写操作由 busy 重试包裹；跨进程写入还要考虑 comix/Gallery CLI。

数据域：

```mermaid
erDiagram
    media_assets ||--o{ media_tag_links : tagged
    tags ||--o{ media_tag_links : links
    media_assets ||--o{ jobs : processed_by
    media_assets ||--o| media_ai : has
    media_assets ||--o{ embeddings : encoded
    media_assets ||--o{ faces : detects
    persons ||--o{ faces : groups
    media_assets ||--o{ duplicate_ignores : excludes
    comics ||--o{ comic_chapters : contains
    comic_chapters ||--o{ comic_images : contains
```

- `media_assets/tags/media_tag_links`：Gallery 主数据；人工标签和 AI 标签物理隔离。
- `essay_* / booklet_*`：用户数据按 updated_at 合并；`user_data_changes` 保存每行最新 revision 和 tombstone。
- `media_ai / embeddings / faces / persons / jobs`：AI 产物与任务。
- `comic_*`：comix 自己维护，Monarch 通过 repository/handler 使用。

新增列不能只改 `CREATE TABLE IF NOT EXISTS`；同时更新 `sqlite.sql` 和
[migrate.go](../../backend/internal/service/db/migrate.go) 的 `addedColumns`。

## 5. 任务与外部进程

[taskengine.Manager](../../backend/internal/service/taskengine/engine.go) 是统一的子进程生命周期层：

- 异步启动、stdout/stderr 逐行日志、退出码和结构化结果。
- 共用资源通过 FIFO 门禁分配，区分排队与运行，取消排队无需等待前面的任务；初始化和删除不得插队。
- 任务状态只保留在内存，服务重启即清空。
- 终态立即裁剪历史；单任务日志限制 512 KiB，结构化输出限制 16 MiB，超限报告失败。
- `Stop` 中断单个任务；`Close` 拒绝新任务、杀进程树并等待任务退出。

两个消费者：

1. [Gallery service](../../backend/internal/service/gallery/cli.go)：`ingest`、`execute`、`refresh`。CLI 与 Monarch 共用 Go 模块和 SQLite 连接配置，每个图库同一时间只允许运行一个任务。入库先落盘并提交数据库，再清理 Raw。
   `refresh` 修复派生图并报告缺失的原件。确认原件永久缺失且已标记删除后，可在 Gallery CLI 的 `execute` 模式显式加 `-prune-missing` 清理记录。
2. [comix service](../../backend/internal/service/comix/tasks.go)：调用 `python -m comix.cli --json`；stdout 是单行 JSON，进度主要来自 stderr。

comix 本身是无状态 CLI；数据库/文件协议见 [comix AGENTS](../../backend/gizmos/comix/AGENTS.md)。

## 6. AI 引擎

[ai.Engine](../../backend/internal/service/ai/engine.go) 是后台 AI 门面：

```text
reconcile：托管入库结束触发，定期补扫手动入库 -> jobs 幂等入队
worker：入队唤醒，空队列退避 -> 事务认领 jobs -> 执行并保存产物
sidecar：embed / face / ocr Python 进程，空闲回收
ollama：VLM 进程/服务监管，按需使用
index：int8 向量加载到 Go 内存做精确扫描
cluster：人脸在线归并与批量重聚类
```

worker 使用退避定时器，暂停时只等待显式唤醒；全部侧车、Ollama 与索引共用一个轻量回收循环。回收不查询数据库或探测依赖，索引实际释放时才归还堆页。

### 关键不变量

- `phash/embed` 固定使用 preview 256；`face/ocr/vlm` 使用按需缓存的 AI 1024 图。
- `input_sig` 记录输入档位与执行者；差异由状态接口报告，已有结果仅在用户显式重生成时刷新。
- 本机只有一个 GPU，模型仲裁器保证同一时间只运行一个模型；前台聊天可抢占后台标注。
- `AI_ENABLED=false` 或 AI schema 缺失时，主服务仍启动；端上应将 AI 失败降级而不是白屏。
- `/API/ai/chat` 和 `/API/ai/review` 是 NDJSON 流；先有状态/通知类事件，再有增量内容。
- `/API/ai/progress` 仅读取队列与内存进程状态；`/status` 按需提供媒体统计与依赖诊断，`?refresh=true` 刷新探测缓存。聊天配置与候选通过 `/chat/info` 获取，不触发媒体诊断。

## 7. 修改后验证

```powershell
go build ./...
go vet ./...
go test ./...
pwsh -File .\references\scripts\generate_refs.ps1
pwsh -File .\references\scripts\generate_refs.ps1 -Check
```

如果改了路由或 CLI 参数，快照刷新是接口变更的一部分；客户端再按处理函数阅读实际响应结构。
