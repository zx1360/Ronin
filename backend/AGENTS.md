## 项目说明 (Monarch)

Ronin 三端架构的"唯一真理"层，Go 语言开发。

### 模块

- **Monarch HTTP**（`cmd/` + `internal/`）：Gin 服务器，为 Torrid (Android) 与 Northstar (Ops 网页端) 提供 REST API，
  并直接托管网页运维端（`/ops/`，源码在 `ops/web/`）。
- **Gizmos CLI**（`gizmos/`，独立 Go module）：命令行批处理媒体库（`ingest`/`execute`/`refresh`），
  由服务端任务引擎托管生命周期（`/API/ops/local/tasks`，同一时刻只允许一个任务）。
- **comix 爬虫**（`gizmos/comix/`，Python，随本仓库维护）：以子进程方式调用
  （`python -m comix.cli --json <cmd>`，协议见 comix `docs/协议文档.md`），
  提供 `/API/comix/*` 接口并由服务端**任务引擎管理爬虫生命周期**（状态/日志/中断/孤儿回收）。
  comix 的表（`comic_*`）由 comix 项目自行建表与维护，本项目只读写。
- **子进程任务引擎**（`internal/service/taskengine/`）：通用的"启动进程 + 逐行日志 + 状态/退出码 +
  kill 进程树"引擎，comix（`service/comix/tasks.go`）与 gallery（`service/gallery/`）都建立在它之上；
  任务状态只在内存中，服务重启即清空（被托管的 CLI 均无状态或自带孤儿自愈）。
- **视频探测**（`internal/service/media_probe/`）：以 ffmpeg/ffprobe 取帧与探测时长，供画廊剪辑页使用。
- **AI 媒体处理层**（`internal/service/ai/` + `internal/repository/ai_repo/` + `handler/ai_handler/`）：
  按需拉起、空闲退出的本地 AI 能力。数据落在 AI 侧自有的 8 张表
  （`references/db/ai.md`，与其它模块以 `media_assets` 外键隔离，可整组删除），不修改其它表。
  - **输入图源分两档**（`derive.go`）：`phash`/`embed` 用 256 预览档（同一张图的哈希与向量
    才不会随入库时期漂移）；`face`/`ocr`/`vlm` 用长边 1024 的 AI 专用派生档
    （`GALLERY_DIR/AI/<年-月>/<基础名>_ai.jpg`，与既有的 6.9 万张同构）。派生档按需生成
    （优先生成自原图，退而用预览档）并缓存；生成失败退回 256 档而不是让任务失败。
    不新增档位，也不改动 `media_assets.preview_path` 的语义与用途。
  - **可追溯与自动重排**：每个能力有"输入档位 + 执行者"指纹（`input_sig`，如
    `ai1024|ollama:qwen3.5:4b`），`jobs` 与三张产物表都记录它。reconcile 发现某能力的
    指纹与现有产物不一致时自动重排（换 VLM 模型后旧标注会被重算），NULL 指纹的历史数据
    不会被自动重排（避免升级后一次性重排 28 万条），需要刷新时用"全量重生成"。
  - `phash`：纯 Go 感知哈希（对预览图算 DCT pHash），无外部进程。
  - `embed` / `face` / `ocr`：Python 侧车（`tools/ai/`）批量处理，一个能力一个进程，
    空闲 `ai_config.json` 的 `idle_timeout_seconds` 后自动退出释放内存，进程降为 BelowNormal
    优先级（`priority_windows.go`）。`device=auto` 时 `face`/`ocr` 走 DirectML，向量编码
    固定 CPU——换执行提供者会改变向量数值、使既有 `embeddings` 失效（`ronin_ai/providers.py`）。
  - `vlm`：调用本机 Ollama，用哪个模型由 `ai_config.json` 的 `vlm_model` 决定。请求必须带
    `think=false` 与显式 `num_ctx`（`OLLAMA_VLM_CTX`）：思考型模型会把 `num_predict`
    全用在推理上，JSON 输出为空。不传 `keep_alive`，沿用 Ollama 默认（无请求 5 分钟后
    卸载模型）；用户已运行的 Ollama 直接复用，未运行时才自拉 `ollama serve`（靠
    `OLLAMA_MODELS` 指向同一模型库，空闲 `OLLAMA_IDLE_TIMEOUT` 秒后回收）。
  - 模型可切换且**不写死**：候选实时来自本机 Ollama（`/api/tags`：名字 + `capabilities` 判视觉，
    旧版无 `capabilities` 时退回模型族启发式），由 `/API/ai/capabilities` 与 `/API/ai/status`
    的 `executor_candidates` 下发，消费端只渲染列表、不硬编码，因此 `ollama pull/rm` 增删模型后
    两端刷新即可用。选定结果存 `ai_config.json` 的 `vlm_model`（从未选过时自动挑一个带视觉能力的
    并落盘；选定模型后来被删掉**不自动改选**，只如实报未安装，避免一次 `ollama rm` 触发全库重排）；
    `chat`/`review` 的 `model` 与网页端的模型切换都只接受**本机已安装**的模型
    （`Engine.NormalizeModel` 校验并归一化大小写）。
    本地构建 VLM：`ollama create -f Modelfile` 里必须有**两条 FROM**（文本 GGUF + `mmproj`），
    否则丢失视觉能力。
  - 模型仲裁（`models.go`）：本地只有一块 GPU，同一时刻只跑一个模型。**前台对话抢占**
    后台标注（中断批次 + 卸载旧模型，任务退回队列不计失败），**后台标注等前台**结束
    （超时才接管），避免边聊天边被反复打断。
  - `chat`（`/API/ai/chat`）：同一模型承接的交互式对话，NDJSON 流式返回
    `notice`/`thinking`/`delta`/`done`/`aborted`/`error`。每轮显式下发 `keep_alive`
    （默认 `OLLAMA_KEEP_ALIVE`，客户端可覆盖，0 = 立即卸载）；客户端要求更长的驻留时间时，
    自拉服务的空闲回收阈值同步放宽。图片可用 `media_ids` 引用库内媒体（服务端就地取
    AI 档派生图）或内联 base64，不读写 AI 侧数据表。
  - 任务队列持久化在 `jobs`，支持失败重试、批次超时、暂停/继续与进度查询；
    入库自动触发由 reconcile 循环（`EnqueueMissing`）实现，幂等自愈。
  - 检索不需要 pgvector：向量 int8 量化存 `embeddings`，Go 侧内存精确扫描。
  - 向量模型必须是**多语种分词器**版本（默认 SigLIP 2）。
  - 未启用 AI 能力时（`AI_ENABLED=false`）不启动 worker，`/API/ai/status` 仍可用并如实
    回报 `enabled=false`，两端界面据此降级提示而不是报错。

### 技术栈

Go + Gin + **单文件 SQLite**（`modernc.org/sqlite` 纯 Go 驱动，无外部数据库服务）。
**同时监听两个端口，接口完全一致，只有协议不同**：`LOCAL_PORT`(7274) HTTPS（自签证书，供 Android 等
局域网消费端，mDNS 广播此端口）与 `LOCAL_HTTP_PORT`(7275) HTTP（供本机浏览器打开运维页面，免证书警告）。
`X-API-Key` 鉴权（含按 IP 的频率封禁；**本机回环地址永不封禁**，封禁日志里的本机记录也不再恢复；
`<img>` 这类无法带请求头的资源可用 `api_key` 查询参数）。
网页运维端在 `/ops/`（`http://127.0.0.1:7275/ops/` 或 `https://127.0.0.1:7274/ops/`），
与其本机能力接口一样不受密钥保护，改由仅回环可访问的 `LocalOnly` 中间件把守（与端口无关）。

### 快速启动

```bash
go run ./cmd                # 开发运行（HTTP + X-API-Key 鉴权）
go build ./cmd              # 产出 cmd.exe（替换旧 exe；避免 go run 触发防火墙确认）
cd gizmos && go build ./cmd/gallery   # 产出 gizmos/gallery.exe（网页端「任务管理」依赖它）
```

### 环境变量 (.env)

`.env` 只保留"连库（以及拉起侧车进程）之前就必须知道"的项：`LOCAL_PORT`(HTTPS),
`LOCAL_HTTP_PORT`(HTTP), `STATIC_DIR`, `GALLERY_DIR`, `DB_FILE`(默认 `data/monarch.db`),
`DB_SCHEMA_FILE`(默认 `references/db/sqlite.sql`), `API_KEY_SERVER`；
comix 集成：`COMIX_PYTHON`(默认 `python`) / `COMIX_ROOT`(默认 `gizmos/comix`)
/ `COMIC_STORAGE_ROOT`（漫画图片存储根）。
网页运维端：`OPS_WEB_DIR`（默认 `../ops/web`，源码目录，由 `/ops/` 托管）；
gallery CLI 位置固定为 `gizmos/gallery.exe`，需要时可加 `GALLERY_CLI` 覆盖。
另有一段 `DB_IP/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME`：**仅一次性迁移脚本使用**，
迁移确认无误后可删除（原 PostgreSQL 库保留作回滚）。

AI 的安装期项仍在 .env：`AI_ENABLED`（`false` = 完全不启用）、`AI_PYTHON`、`AI_SIDECAR_DIR`、
`AI_EMBED_MODEL`（换模型会使既有 `embeddings` 作废）、`OLLAMA_URL`、
`OLLAMA_MODELS`（**必须指向 Ollama 应用实际使用的模型目录**，否则自拉的 `ollama serve` 看不到任何模型）、
`OLLAMA_EXE`、`OLLAMA_VLM_CTX`、`OLLAMA_KEEP_ALIVE`。**模型名不在这里配置**（见上"模型可切换"）。
**运行时可调项已迁到 `<STATIC_DIR>/data/ai_config.json`**：`idle_timeout_seconds`、`job_timeout_seconds`、`batch_size`、`max_attempts`、
`workers`、`device`、`auto_capabilities`、`vlm_model`。首次启动时若配置文件不存在，会按 .env 同名项（`AI_IDLE_TIMEOUT` 等，作为种子值）生成它；
`config/store.go` 负责读写与取值范围校验。

### API 概览

| 路由组 | 关键端点 | 用途 |
|--------|---------|------|
| `/API/user-data` | `GET /sync/:module`, `POST /backup/:module`, `POST /check-images/:module` | 用户数据同步/备份（提交完整数据集，服务端事务内全量替换） |
| `/API/comic` | `/meta-info`, `/comic-info`, `/chapter-info`, `/download`, `/sync-readed` | 漫画浏览与离线下载（Android 端主用） |
| `/API/comix` | `/list`, `/chapters/:id`, `/tasks*`, `/download*`, `/update-check`, `/delete`, `/clean` | 漫画库查询（含下载进度与书库管理字段）+ 爬虫任务生命周期（Ops 端主用） |
| `/API/gallery` | `GET /batch`, `GET /overview`, `GET /:id/:type` | 媒体资产浏览、文件流、客户端本地缓存下载 |
| `/API/gallery` | `GET/POST /tags`, `PUT/DELETE /tags/:id` | 标签树增删改查（含 `is_favorite`, 服务端权威） |
| `/API/gallery` | `GET/PATCH /media`, `POST /media/tags`, `PUT /media/:id/tags` | 媒体查询、标注（软删除/备注/捆绑/编辑参数/处理游标）、标签关系增删与全量替换。`GET /media` 支持 `vlm_tags`（AI 标签，任一命中，只读）与 `only_deleted`（仅软删除项）；**不传 `vlm_tags` 时完全不触及 AI 侧数据表**，未初始化 AI 层的部署不受影响 |
| `/API/ops` | `GET /overview` | 系统概览（Ops 用；`service.staticDir` 为 static 绝对路径） |
| `/API/ops/local` | `GET /bootstrap`, `PUT /settings`, `POST /reveal`, `GET/POST /tasks`, `GET /tasks/:id`, `POST /tasks/:id/stop` | 网页运维端的**本机能力**：密钥与偏好/路径下发、界面偏好写 `<STATIC_DIR>/data/ops_web.json`（含 `ai_paused`：服务端启动时据此恢复队列的暂停状态，缺省即暂停）、资源管理器定位、内置 gallery CLI 任务生命周期。仅回环可访问（`LocalOnly`），且免 API Key |
| `/API/ai` | `GET /status`, `GET /capabilities`, `GET /jobs`, `GET /failures`, `POST /enqueue\|retry\|regenerate\|cancel\|resume`, `POST /process/:cap/start\|stop`, `POST /index/rebuild`, `GET/PUT /settings` | AI 运维：能力就绪状态与输入档位/执行者候选（`capabilities` 为端上唯一真源）、队列与进度（`status.media_total` 是进度分母，不含「尚无产物」）、失败项清单（含媒体路径/缩略图标记，供界面做软删除）、入队、重试失败项、单能力全量重生成（清产物后重排，破坏性）、暂停与继续、模型进程启停、运行时配置读写 |
| `/API/ai` | `GET /search`, `POST /search/image`, `GET /similar/:id`, `GET /media/:id`, `GET /duplicates`, `POST /duplicates/ignore\|unignore`, `GET /duplicates/ignored`, `GET /tags` | 检索与去重：文本搜图、以图搜图、组合筛选、近重复分组（`ignore` = 人工判定「非重复」，之后不再参与分组，可随时恢复）、AI 标签清单（含出现次数） |
| `/API/ai` | `POST /chat` | 交互式对话：NDJSON 流式（`notice`/`thinking`/`delta`/`done`/`aborted`/`error`），图片可用 `media_ids` 引用库内媒体或内联 base64；`model`/`num_ctx`/`think`/`temperature`/`keep_alive_seconds` 逐次可调 |
| `/API/ai` | `POST /review`, `GET/PUT /review/presets` | 近期回顾：后端从 booklet/essay 数据算**确定性统计**（+ 可选随机抽样素材）后交本地模型叙述，NDJSON 流（正文前先下发一条 `stats` 事件供端上展示"本次依据"）。统计口径见 `service/review/`：essay 按本地日历日、booklet 按日历日标记（UTC 零点）归日，两者混用会整体错一天。预设（角色/语气）存 `<STATIC_DIR>/data/review_presets.json`，服务端权威、端上只做镜像；生成结果不落库，由端上本地缓存 |
| `/API/ai` | `GET /persons`, `GET /persons/:id/faces`, `PATCH/DELETE /persons/:id`, `POST /persons/merge\|faces/assign\|recluster` | 人物分组：改名/删除/合并/人工纠正/重新聚类 |

`GET /API/ai/search` 的检索方式（`mode`）：`auto`（默认，有文本走语义并对关键词命中加权）、
`semantic`、`keyword`（只匹配 OCR/描述/AI 关键词）、`filename`（只匹配文件路径，可用扩展名过滤）。
结构筛选：`tag_ids`（人工标签）、`vlm_tags`（AI 标签，只读，与人工标签物理隔离）、
`person_ids`、`mime_type`、`from`/`to`。非法的 `tag_ids`/`person_ids` 返回 400 而不是 500。

### 验收

```bash
go build ./... && go vet ./... && go test ./...   # 在 backend/ 与 backend/gizmos/ 各执行一次
python tools/smoke_api.py                         # 服务运行中逐个接口冒烟（详情见 AGENTS_DB.md）
python tools/smoke_ops_web.py                    # 服务运行中逐页冒烟网页运维端（playwright）
```

`go test ./internal/repository` 是数据层端到端验收：把 `data/monarch.db` 复制到临时目录后
跑遍全部写路径（AI 产物、标签树级联、全量替换、comix 管理字段），不触碰真实数据。

### 跨项目契约

路由表与 CLI 参数快照是**生成物**（`references/generated/`，不入 git），真源永远是 Go 代码；
端上 DTO 仍手写，改接口后照快照里的处理函数去读响应结构再同步。修改 Go 路由或 CLI 参数后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\references\scripts\generate_refs.ps1
powershell -ExecutionPolicy Bypass -File .\references\scripts\generate_refs.ps1 -Check  # 只校验快照是否已过期
```

### 数据库

单文件 SQLite，表结构与索引见 `AGENTS_DB.md`，建表真源 `references/db/sqlite.sql`
（幂等，Monarch 启动时执行，comix 的 `init` 读同一份）。
迁移与回滚：`python tools/migrate_pg_to_sqlite.py`（只读源库、可重跑、含抽样校验；
原 PostgreSQL 库保留作回滚）；两方案性能比对：`python tools/bench_pg_vs_sqlite.py`。
AI 侧车依赖安装：`powershell -File tools/ai/install.ps1`（详见 `tools/ai/README.md`）。

### 硬性要求

- 考虑边界情况, 做好异常防护.
- 除非明确要求, 不对已有功能引入破坏性修改.
- 更新数据库记录时显式更新所有字段值.
- 涉及用户数据的写入必须走事务, 保证失败可回滚.
- 注意代码可维护性.
