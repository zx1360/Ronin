# Monarch

Go + Gin + `modernc.org/sqlite`；启动入口 `cmd/main.go`，路由真源 `internal/router/`。
架构见 `../docs/architecture/monarch.md`；数据库索引见 `AGENTS_DB.md`，非漫画域建表真源 `references/db/sqlite.sql`，漫画域 `references/db/comix.sql`。

## 代码边界

- `handler` 负责 HTTP 校验/响应，`service` 负责业务与进程，`repository` 负责 SQL。
- Gallery CLI 与 Monarch 共用 Go 模块，入口在 `gizmos/cmd/gallery/`，独立按需运行。`gizmos/comix/` 是 Python CLI，修改前读其 `AGENTS.md`。
- gallery/comix 长任务共用 `service/taskengine/`；gallery 启动互斥，comix 写任务依次执行并与初始化/删除互斥。任务状态在内存，退出须杀进程树。
- 远程业务 API 和媒体需要 `X-API-Key`，`api_key` 查询参数仅用于本机读取。Ops 页面及本机接口由 `LocalOnly` 校验 TCP 回环、Host 和浏览器同源；回环地址不得封禁。

## 数据与配置

- SQLite 为共享单文件（WAL）；读用 `db.Read()`，写用 `db.Exec` / `db.Tx`，多步写入必须事务回滚。跨进程竞争由 busy timeout 与重试处理。
- Monarch/Gallery 共用 `db.Init` / `db.InitGallery` 的事务初始化和补列实现；comix init 仅执行共享 `comix.sql`，不升级其他域。漫画域目前无补列迁移；未来结构转换须提供双方共用的单一迁移入口。
- 新增列同时更新 `sqlite.sql` 与 `internal/service/db/migrate.go`；不可依赖 `CREATE TABLE IF NOT EXISTS` 给旧表补列。
- 时间戳用本机时区定宽毫秒文本；日期是日历日。回顾统计中 essay 按本地日期，booklet 的 UTC 零点仅用于标记日历日，不得混用。
- `.env` 保存启动配置。用户附件、偏好和运行配置存 `DATA_DIR`（默认 `backend/data/`）；漫画图片从 `STATIC_DIR/comics` 提供。
- user-data 使用 sync_version=2，按 `updated_at` 逐行合并；新版随笔关联标签单独用 `labels_updated_at`。删除保留 tombstone，游标按服务端 revision 推进；统计重算，图片不随合并清理。偏好与回顾预设仍整体替换；失败保持原数据。

## AI 不变量

- `phash/embed` 固定使用 256 预览图；`face/ocr/vlm` 使用按需生成的 1024 派生图，失败退回预览图，不改变 `preview_path` 语义。
- `input_sig` 记录图源档位与执行者；reconcile 只补无任务行，已有结果仅在用户显式重生成时刷新。
- embed 固定 CPU、多语种分词器；切换执行提供者/模型会影响既有向量。侧车、向量索引、自拉 Ollama 均须空闲回收。
- VLM 请求带 `think=false` 和显式 `num_ctx`；候选模型来自本机 Ollama，两端不得硬编码。已选模型被删除时不自动改选。
- 单 GPU 模型仲裁：前台对话可抢占后台标注，后台等待前台；中断批次退回队列，不计失败。
- `AI_ENABLED=false` 不启动 worker；AI 不可用时主服务仍可用。chat/review 返回 NDJSON，消费端须处理 503 与中断事件。

## 验收

在 `backend/` 运行 `go build ./...`、`go vet ./...`、`go test ./...`。
同步构建 `go build ./cmd` 和 `go build -o gizmos/gallery.exe ./gizmos/cmd/gallery`。运行主服务直接启动 `cmd.exe`。
网页冒烟：`python tools/smoke_ops_web.py --base http://127.0.0.1:<隔离端口>`。
AI 安装与依赖见 `tools/ai/README.md`。
