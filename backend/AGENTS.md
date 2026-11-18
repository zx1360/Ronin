# Monarch

- 入口 `cmd/main.go`，路由 `internal/router/`。handler 处理 HTTP，service 处理业务和进程，repository 处理 SQL。启动和构建命令见[仓库 README](../README.md#从源码运行)。
- Gallery 入口 `gizmos/cmd/gallery/`，漫画爬虫见 [comix 指引](gizmos/comix/AGENTS.md)。长任务共用 `service/taskengine/`。Gallery 互斥，comix 写任务串行并与初始化、删除互斥。退出回收进程树。
- 业务 API 与媒体用 `X-API-Key`，`api_key` 查询参数仅供本机读取。Ops 由 `LocalOnly` 校验回环 TCP、Host 和浏览器同源。配置和附件在 `DATA_DIR`，漫画图片从 `STATIC_DIR/comics` 提供。
- SQLite 规则见[数据库指引](AGENTS_DB.md)，同步和回顾接口见[跨端契约](data/contracts/README.md)。
- AI 禁用时不启动 worker。侧车、向量索引和自拉 Ollama 空闲回收。前台对话可抢占后台标注，中断批次退回队列。VLM 明确传 `think=false` 和 `num_ctx`，候选来自 Ollama，所选模型消失时保持选择。输入档位和产物语义见 [AI 数据](references/db/ai.md)。
- 回顾接口专项用 `pwsh -File backend/tools/smoke_review.ps1`，覆盖临时库和模拟模型。
