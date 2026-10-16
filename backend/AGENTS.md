# Monarch

Go + Gin + `modernc.org/sqlite`；启动入口 `cmd/main.go`，路由真源 `internal/router/`。
架构见 `../docs/architecture/monarch.md`；数据库索引见 `AGENTS_DB.md`，建表真源 `references/db/sqlite.sql`。

## 代码边界

- `handler` 负责 HTTP 校验/响应，`service` 负责业务与进程，`repository` 负责 SQL。
- `gizmos/` 是独立 Go module，处理媒体入库/编辑/刷新；`gizmos/comix/` 是 Python CLI，修改前读其 `AGENTS.md`。
- gallery/comix 长任务共用 `service/taskengine/`；gallery 同时只允许一个任务。任务状态在内存，退出须杀进程树。
- 通用 API 使用 `X-API-Key`，资源可用 `api_key` 查询参数。Ops 页面及本机接口由 `LocalOnly` 按 TCP 对端限制回环访问；回环地址不得封禁。

## 数据与配置

- SQLite 为共享单文件（WAL）；读用 `db.Read()`，写用 `db.Exec` / `db.Tx`，多步写入必须事务回滚。跨进程竞争由 busy timeout 与重试处理。
- 新增列同时更新 `sqlite.sql` 与 `internal/service/db/migrate.go`；不可依赖 `CREATE TABLE IF NOT EXISTS` 给旧表补列。
- 时间戳用本机时区定宽毫秒文本；日期是日历日。回顾统计中 essay 按本地日期，booklet 的 UTC 零点仅用于标记日历日，不得混用。
- `.env` 保存启动配置，字段以 `internal/config/config.go` 为准；AI 运行配置在 `<STATIC_DIR>/data/ai_config.json`，网页偏好在 `ops_web.json`，回顾预设在 `review_presets.json`。
- user-data 使用 sync_version=2：updated_at 逐行合并，删除保留 tombstone，游标按服务端 revision 推进；统计重算，图片不随合并清理。偏好与回顾预设仍整体替换；失败保持原数据。

## AI 不变量

- `phash/embed` 固定使用 256 预览图；`face/ocr/vlm` 使用按需生成的 1024 派生图，失败退回预览图，不改变 `preview_path` 语义。
- `input_sig` 记录图源档位与执行者；reconcile 只补无任务行，已有结果仅在用户显式重生成时刷新。
- embed 固定 CPU、多语种分词器；切换执行提供者/模型会影响既有向量。侧车、向量索引、自拉 Ollama 均须空闲回收。
- VLM 请求带 `think=false` 和显式 `num_ctx`；候选模型来自本机 Ollama，两端不得硬编码。已选模型被删除时不自动改选。
- 单 GPU 模型仲裁：前台对话可抢占后台标注，后台等待前台；中断批次退回队列，不计失败。
- `AI_ENABLED=false` 不启动 worker；AI 不可用时主服务仍可用。chat/review 返回 NDJSON，消费端须处理 503 与中断事件。

## 验收

在 `backend/` 和 `backend/gizmos/` 各运行 `go build ./...`、`go vet ./...`、`go test ./...`。
运行主服务用 `go build ./cmd` 后启动 `cmd.exe`，避免 `go run` 触发防火墙确认。
网页冒烟：`python tools/smoke_ops_web.py`（`OPS_SMOKE_BASE` 可指向隔离实例）。
AI 安装与依赖见 `tools/ai/README.md`。
