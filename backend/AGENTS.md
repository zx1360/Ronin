## 项目说明 (Monarch)

Ronin 三端架构的"唯一真理"层，Go 语言开发。

### 模块

- **Monarch HTTP**（`cmd/` + `internal/`）：Gin 服务器，为 Torrid (Android) 和 Northstar (Desktop) 提供 REST API。
- **Gizmos CLI**（`gizmos/`，独立 Go module）：命令行批处理媒体库（`ingest`/`execute`/`refresh`）。
- **comix 爬虫集成**（`internal/service/comix/` + `internal/handler/comix_handler/`）：以子进程方式调用
  外部 comix 项目（`python -m comix.cli --json <cmd>`，协议见 comix `docs/协议文档.md`），
  提供 `/API/comix/*` 接口并由服务端**任务引擎管理爬虫生命周期**（状态/日志/中断/孤儿回收）。
  `comix` schema 的表由 comix 项目自行建表与维护，本项目只读写。
- **视频探测**（`internal/service/media_probe/`）：以 ffmpeg/ffprobe 取帧与探测时长，供画廊剪辑页使用。
- **AI 媒体处理层**（`internal/service/ai/` + `internal/repository/ai_repo/` + `handler/ai_handler/`）：
  按需拉起、空闲退出的本地 AI 能力。数据全部落在独立的 `ai` schema
  （`references/db/ai.sql`，回滚见 `ai_rollback.sql`），不修改其它 schema。
  - `phash`：纯 Go 感知哈希（对预览图算 DCT pHash），无外部进程。
  - `embed` / `face` / `ocr`：Python 侧车（`tools/ai/`）批量处理，一个能力一个进程，
    空闲 `AI_IDLE_TIMEOUT` 秒后自动退出释放内存，进程降为 BelowNormal 优先级
    （`priority_windows.go`）。`AI_DEVICE=auto` 时 `face`/`ocr` 走 DirectML，向量编码
    固定 CPU——换执行提供者会改变向量数值、使既有 `ai.embeddings` 失效
    （`ronin_ai/providers.py`）。
  - `vlm`：调用本机 Ollama（`OLLAMA_VLM_MODEL`，默认 `qwen3.5:4b`）。请求必须带
    `think=false` 与显式 `num_ctx`（`OLLAMA_VLM_CTX`）：思考型模型会把 `num_predict`
    全用在推理上，JSON 输出为空。不传 `keep_alive`，沿用 Ollama 默认（无请求 5 分钟后
    卸载模型）；用户已运行的 Ollama 直接复用，未运行时才自拉 `ollama serve`（靠
    `OLLAMA_MODELS` 指向同一模型库，空闲 `OLLAMA_IDLE_TIMEOUT` 秒后回收）。
  - 任务队列持久化在 `ai.jobs`，支持失败重试、批次超时、暂停/继续与进度查询；
    入库自动触发由 reconcile 循环（`EnqueueMissing`）实现，幂等自愈。
  - 检索不需要 pgvector：向量 int8 量化存 `ai.embeddings`，Go 侧内存精确扫描。
  - 向量模型必须是**多语种分词器**版本（默认 SigLIP 2）。

### 技术栈

Go + Gin + pgx + PostgreSQL 18.0。支持 HTTP/HTTPS（自签证书），`X-API-Key` 鉴权（含按 IP 的频率封禁）。启动时自动通过 mDNS (`_monarch._tcp`) 注册服务，供客户端自动发现。

### 快速启动

```bash
go run ./cmd -mode local    # 开发模式 (HTTP, 无鉴权)
go run ./cmd                # 生产模式 (HTTPS, X-API-Key 鉴权)
```

### 环境变量 (.env)

`LOCAL_PORT`, `LOCAL_DEBUG_PORT`, `STATIC_DIR`, `GALLERY_DIR`, `DB_IP/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME`,
`API_KEY_SERVER`；comix 集成可选 `COMIX_PYTHON`(默认 `python`) / `COMIX_ROOT`。
AI 处理层可选（缺省即可用）：`AI_ENABLED`, `AI_PYTHON`, `AI_SIDECAR_DIR`, `AI_IDLE_TIMEOUT`,
`AI_BATCH_SIZE`, `AI_JOB_TIMEOUT`, `AI_MAX_ATTEMPTS`, `AI_WORKERS`, `AI_EMBED_MODEL`, `AI_AUTO_CAPS`
(`none`/`off` = 关闭入库自动处理), `AI_DEVICE` (`cpu` = 侧车全部回退 CPU), `OLLAMA_URL`,
`OLLAMA_VLM_MODEL`, `OLLAMA_VLM_CTX`, `OLLAMA_MODELS`, `OLLAMA_EXE`, `OLLAMA_IDLE_TIMEOUT`
（自拉 ollama serve 的空闲回收秒数，默认 360，需大于模型的 keep_alive）。

### API 概览

| 路由组 | 关键端点 | 用途 |
|--------|---------|------|
| `/API/user-data` | `GET /sync/:module`, `POST /backup/:module`, `POST /check-images/:module` | 用户数据同步/备份（提交完整数据集，服务端事务内全量替换） |
| `/API/comic` | `/meta-info`, `/comic-info`, `/chapter-info`, `/download`, `/sync-readed` | 漫画浏览与离线下载（Android 端主用） |
| `/API/comix` | `/list`, `/chapters/:id`, `/tasks*`, `/download*`, `/update-check`, `/delete`, `/clean` | 漫画库查询（含下载进度与书库管理字段）+ 爬虫任务生命周期（Desktop 端主用） |
| `/API/gallery` | `GET /batch`, `GET /overview`, `GET /:id/:type` | 媒体资产浏览、文件流、客户端本地缓存下载 |
| `/API/gallery` | `GET/POST /tags`, `PUT/DELETE /tags/:id` | 标签树增删改查（含 `is_favorite`, 服务端权威） |
| `/API/gallery` | `GET/PATCH /media`, `POST /media/tags`, `PUT /media/:id/tags` | 媒体查询、标注（软删除/备注/捆绑/编辑参数/处理游标）、标签关系增删与全量替换。`GET /media` 支持 `vlm_tags`（AI 标签，任一命中，只读）——**不传该参数时完全不触及 `ai` schema**，未初始化 AI 层的部署不受影响 |
| `/API/ops` | `GET /overview` | 系统概览（Desktop 用；`service.staticDir` 为 static 绝对路径） |
| `/API/ai` | `GET /status`, `GET /jobs`, `POST /enqueue\|retry\|cancel\|resume`, `POST /process/:cap/start\|stop`, `POST /index/rebuild`, `GET/PUT /settings` | AI 运维：能力就绪状态、队列与进度、入队/重试、暂停与继续、模型进程启停、自动处理开关（`cancel` 会中断当前批次并暂停队列，`resume` 恢复） |
| `/API/ai` | `GET /search`, `POST /search/image`, `GET /similar/:id`, `GET /media/:id`, `GET /duplicates`, `GET /tags` | 检索：文本搜图、以图搜图、组合筛选、近重复分组、AI 标签清单（含出现次数） |
| `/API/ai` | `GET /persons`, `GET /persons/:id/faces`, `PATCH/DELETE /persons/:id`, `POST /persons/merge\|faces/assign\|recluster` | 人物分组：改名/删除/合并/人工纠正/重新聚类 |

`GET /API/ai/search` 的检索方式（`mode`）：`auto`（默认，有文本走语义并对关键词命中加权）、
`semantic`、`keyword`（只匹配 OCR/描述/AI 关键词）、`filename`（只匹配文件路径，可用扩展名过滤）。
结构筛选：`tag_ids`（人工标签）、`vlm_tags`（AI 标签，只读，与人工标签物理隔离）、
`person_ids`、`mime_type`、`from`/`to`。非法的 `tag_ids`/`person_ids` 返回 400 而不是 500。

### 验收

```bash
go build ./... && go vet ./... && go test ./...   # 在 backend/ 与 backend/gizmos/ 各执行一次
```

### 跨项目契约

修改 Go 接口、路由或 CLI 参数后运行（会同步 `references/api/` 与 `references/cli/`）：
```powershell
powershell -ExecutionPolicy Bypass -File .\references\scripts\generate_refs.ps1
```

### 数据库

表定义及触发器见 `references/db/init.sql`（gallery 与 user_data，幂等可重复执行）；
索引见 `AGENTS_DB.md`，分模块明细见 `references/db/`。
AI 层单独执行 `references/db/ai.sql`（只新增 `ai` schema，幂等）；
整体回滚执行 `references/db/ai_rollback.sql`（`DROP SCHEMA ai CASCADE`，不动其它数据）。
AI 侧车依赖安装：`powershell -File tools/ai/install.ps1`（详见 `tools/ai/README.md`）。

### 硬性要求

- 考虑边界情况, 做好异常防护.
- 除非明确要求, 不对已有功能引入破坏性修改.
- 更新数据库记录时显式更新所有字段值.
- 涉及用户数据的写入必须走事务, 保证失败可回滚.
- 注意代码可维护性.
