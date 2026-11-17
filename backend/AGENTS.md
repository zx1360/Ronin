# Monarch

- 启动入口 `cmd/main.go`，路由在 `internal/router/`。handler 处理 HTTP，service 处理业务与进程，repository 处理 SQL。
- Gallery CLI 在 `gizmos/cmd/gallery/`，comix 指引在 [gizmos/comix](gizmos/comix/AGENTS.md)。长任务共用 `service/taskengine/`，Gallery 互斥，comix 写任务串行并与初始化、删除互斥。退出时回收进程树。
- 业务 API 与媒体使用 `X-API-Key`。`api_key` 查询参数仅供本机读取。Ops 由 `LocalOnly` 校验回环 TCP、Host 和浏览器同源。
- SQLite 读走 `db.Read`，写走 `db.Exec` 或 `db.Tx`。改 schema 先读 [数据库约定](AGENTS_DB.md)。运行配置和附件在 `DATA_DIR`，漫画图片从 `STATIC_DIR/comics` 提供。
- user-data v2 按行合并 `updated_at`，随笔标签另用 `labels_updated_at`。删除留 tombstone，游标按服务端 revision 推进。统计派生，合并保留附件。偏好和回顾预设整体替换。
- phash/embed 使用 256 预览图，face/ocr/vlm 优先 1024 派生图。embed 固定 CPU 和多语种分词器。`input_sig` 标记图源和执行者，reconcile 仅补缺失任务，已有产物由用户显式重生成。
- AI 禁用时不启动 worker。侧车、向量索引和自拉 Ollama 空闲回收。前台对话可抢占后台标注，中断批次退回队列。VLM 明确传 `think=false` 和 `num_ctx`，候选模型来自 Ollama，所选模型消失时保持选择。
- 验收入口见 [仓库约定](../docs/architecture/instructions.md)。启动前用 `go build ./cmd`，Gallery CLI 用 `go build -o gizmos/gallery.exe ./gizmos/cmd/gallery`。隔离验收时用独立构建输出和数据目录。
