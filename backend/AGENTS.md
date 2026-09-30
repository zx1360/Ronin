## 项目说明 (Monarch)

Ronin 三端架构的"唯一真理"层，Go 语言开发。数据为**单文件 SQLite**，不依赖任何外部数据库服务。

### 模块

- **Monarch HTTP**（`cmd/` + `internal/`）：Gin 服务器。生产模式开两个监听：
  LAN 侧 HTTPS + `X-API-Key`（供 frontend 使用），回环侧 HTTP（ops 网页端与本机能力接口）。
- **Gizmos CLI**（`gizmos/`，独立 Go module）：命令行批处理媒体库（`ingest`/`execute`/`refresh`）。
- **comix 爬虫**（`gizmos/comix/`，已内置）：Python 项目，以子进程方式调用
  （`python -m comix.cli --json <cmd>`，协议见其 `docs/协议文档.md`），
  提供 `/API/comix/*` 接口。`comix_*` 表由它自己建表与维护，与其余表共用同一个 SQLite 文件。
- **外部命令任务引擎**（`internal/service/proctask/`）：comix 爬虫与 gallery CLI
  共用同一套生命周期管理（内存任务表 + 子进程输出入日志 + 进程树中断），
  差别只在"stdout 是 JSON 结果还是要展示的日志"，由 Spec 参数化。
- **视频探测**（`internal/service/media_probe/`）：以 ffmpeg/ffprobe 取帧与探测时长。
- **AI 媒体处理层**（`internal/service/ai/` + `internal/repository/ai_repo/` + `handler/ai_handler/`）：
  按需拉起、空闲退出的本地 AI 能力。
  - **能力登记**：`internal/model/capability.go` 是唯一权威（展示名 / 输入档位 / 优先级 /
    内置实现 / 可切换的配置键）；设置项候选项与默认值、`/API/ai/capabilities` 的下发内容、
    入队优先级都由它派生，新增能力只需改这一处。
  - `phash`：纯 Go 感知哈希，无外部进程；`embed` / `face` / `ocr`：Python 侧车（`tools/ai/`），
    一个能力一个进程，空闲 `ai.idle_timeout` 秒后退出并降为 BelowNormal 优先级。
    `ai.device=auto` 时 `face`/`ocr` 走 DirectML，向量编码固定 CPU——换执行提供者会改变向量数值。
  - `vlm`：调用本机 Ollama。请求必须带 `think=false` 与显式 `num_ctx`（思考型模型会把
    `num_predict` 全用在推理上，JSON 输出为空）。用户已运行的 Ollama 直接复用，未运行时才自拉。
  - **输入档位**：phash/embed 用 256 预览图（`preview256`）；face/ocr/vlm 用长边 1024 的
    AI 专用派生档（`ai1024`，按需生成并缓存在 `<GALLERY_DIR>/AI/`）。只有这两档。
  - **结果溯源与自动重排**：`ai_results` 记录每条 (媒体, 能力) 的 `input_tier` 与 `executor`；
    reconcile 循环比对期望规格，不符即自动重排（`EnqueueStale`）。改模型/换档位无需人工清库。
  - 检索不需要向量扩展：向量 int8 量化存 `ai_embeddings`，Go 侧内存精确扫描；
    文本模糊检索用 SQLite `LIKE`，数组检索用 `json_each`。
  - 任务队列持久化在 `ai_jobs`（写池单连接，认领天然串行，不需要 `SKIP LOCKED`），
    支持失败重试、批次超时、暂停/继续与进度查询。
  - 模型仲裁（`models.go`）：本机只有一块 GPU。前台对话抢占后台标注（中断批次 + 卸载旧模型，
    任务退回队列不计失败），后台标注等前台结束（超时才接管）。
  - `chat`（`/API/ai/chat`）：NDJSON 流式对话，事件 `notice`/`thinking`/`delta`/`done`/`aborted`/`error`；
    图片可用 `media_ids` 引用库内媒体或内联 base64。
  - `review`（`/API/ai/review`）：近期回顾。**统计由后端算出**（`internal/service/review`），
    模型只负责把给定事实写成叙述；结果按"统计指纹 + 预设 + 模型"缓存，语气/角色是可编辑预设。
    模型不可用时仍返回统计（完整降级）。

### 技术栈

Go + Gin + modernc.org/sqlite（纯 Go，CGO_ENABLED=0 可用）。支持 HTTP/HTTPS（自签证书），
`X-API-Key` 鉴权。启动时通过 mDNS (`_monarch._tcp`) 注册服务。

### 快速启动

```bash
go run ./cmd -mode local    # 开发模式 (HTTP, 无鉴权, 调试端口即主服务)
go run ./cmd                # 生产模式 (LAN HTTPS+鉴权；另开回环 HTTP 供 ops)
```

### 环境变量 (.env)

**只保留连库之前就必须知道的项**：`DB_PATH`、`LOCAL_PORT`、`LOCAL_DEBUG_PORT`、`API_KEY_SERVER`。
其余配置（目录、comix/AI/Ollama 参数）全部落在 `app_settings` 表，由 ops 网页端读写：

- 读取：`GET /API/settings` 返回 `{values, schema}`，`schema` 描述每个配置项的控件类型、
  取值范围与候选项——**消费端只渲染，不硬编码配置键**。
- 写入：`PUT /API/settings`（仅回环），校验后立即 `config.ApplySettings` 生效。

### API 概览

| 路由组 | 关键端点 | 用途 |
|--------|---------|------|
| `/API/user-data` | `GET /sync/:module`, `POST /backup/:module`, `POST /check-images/:module` | 用户数据同步/备份（**按 `updated_at` 逐行合并，删除用 `deleted_at` 墓碑**） |
| `/API/comic` | `/meta-info`, `/comic-info`, `/chapter-info`, `/download`, `/sync-readed` | 漫画浏览与离线下载（frontend 端主用） |
| `/API/comix` | `/list`, `/chapters/:id`, `/tasks*`, `/download*`, `/update-check`, `/delete`, `/clean` | 漫画库查询 + 爬虫任务生命周期（ops 端主用） |
| `/API/gallery` | `GET /batch`, `/overview`, `/:id/:type` | 媒体资产浏览、文件流、客户端本地缓存下载 |
| `/API/gallery` | `GET/POST /tags`, `PUT/DELETE /tags/:id` | 标签树增删改查（`full_path` 级联由 Go 维护，服务端权威） |
| `/API/gallery` | `GET/PATCH /media`, `POST /media/tags`, `PUT /media/:id/tags` | 媒体查询与标注（软删除/备注/捆绑/编辑参数/处理游标）。`vlm_tags` 为 AI 标签（只读，物理隔离）；**不传 `vlm_tags` 时完全不触及 `ai_` 表** |
| `/API/settings` | `GET`, `PUT` | 运行时配置读写（`schema` 驱动 UI，仅回环可写） |
| `/API/ops` | `GET /overview` | 系统概览：服务信息、**SQLite 文件路径与体积**、各存储目录用量、依赖探测 |
| `/API/ops` | `GET /capabilities`, `/dependencies`, `/fs`, `POST /reveal` | 本机能力：固定任务清单与参数范围、外部命令探测、目录选择、在文件管理器中定位 |
| `/API/ops` | `GET/PUT /preferences` | ops 页面轻量偏好（后端管理 json） |
| `/API/ops` | `GET/POST /gallery/tasks`, `GET /gallery/tasks/:id`, `POST /gallery/tasks/:id/stop` | 内置 gallery CLI 的任务生命周期（与 comix 共用 `proctask` 引擎） |
| `/API/ai` | `GET /status`, `/capabilities`, `/jobs`, `POST /enqueue\|retry\|cancel\|resume`, `POST /process/:cap/start\|stop`, `POST /index/rebuild` | 运维：能力就绪状态、队列与进度、入队/重试、暂停与继续、模型进程启停。`/capabilities` 下发每个能力的**输入档位、当前执行者与候选清单** |
| `/API/ai` | `GET /search`, `POST /search/image`, `GET /similar/:id`, `/media/:id`, `/duplicates*`, `/tags` | 检索与去重：文本搜图、以图搜图、组合筛选、近重复分组、AI 标签清单 |
| `/API/ai` | `POST /chat` | 交互式对话：NDJSON 流式 |
| `/API/ai` | `GET/PATCH/DELETE /persons*`, `POST /persons/merge\|faces/assign\|recluster` | 人物分组 |
| `/API/ai` | `GET/POST /review/presets`, `DELETE /review/presets/:id`, `POST /review` | 近期回顾：确定性统计 + 本地模型叙述 + 缓存 + 可编辑预设 |

`GET /API/ai/search` 的 `mode`：`auto`（默认）、`semantic`、`keyword`、`filename`。
结构筛选：`tag_ids`、`vlm_tags`（只读）、`person_ids`、`mime_type`、`from`/`to`。
非法的 `tag_ids`/`person_ids` 返回 400 而不是 500。

**未启用 AI 能力时**（`ai.enabled=false` 或缺模型/侧车）：`/API/ai/capabilities` 如实报告
不可用原因（含"服务可达但模型未安装"）；入队/重试/启动模型返回 409，不会拉起任何进程；
检索退化为关键词模式，只读接口照常可用；`/API/ai/review` 仍返回确定性统计；其余接口不受影响。

### 运维网页端 (ops)

构建期无产物：`ops/` 是纯静态 HTML/CSS/ES 模块，由后端挂在 `/ops`。
访问方式：启动 Monarch 后打开 `http://127.0.0.1:<LOCAL_DEBUG_PORT>/ops/`（生产模式同样提供该回环监听）。
页面本身与 `/API/ops/*`、`/API/settings` 都只对本机回环开放：页面不具备本机权限，
进程与任务生命周期、路径定位、配置读写一律经这些回环接口完成。

### 验收

```bash
go build ./... && go vet ./... && go test ./...   # 在 backend/ 与 backend/gizmos/ 各执行一次
```

### 跨项目契约

端点契约由 gin 路由表生成（**只生成端点，不生成模型** —— 业务模型各端手写）：

```powershell
powershell -ExecutionPolicy Bypass -File .\references\scripts\gen_contract.ps1
```
产物：`frontend/lib/core/api/generated/api_contract.dart`（`ApiPath` 常量与带参路径构造函数）、
`ops/js/generated/endpoints.js`。两份都被两端直接编译/运行消费，因此纳入版本控制。

### 数据库

见 `AGENTS_DB.md`（索引与约定）。表结构：`internal/service/db/schema.sql`。
PostgreSQL → SQLite 的一次性迁移已完成，工具归档在仓库外 `Ronin-archive/`。
AI 侧车依赖安装：`powershell -File tools/ai/install.ps1`。

### 硬性要求

- 考虑边界情况, 做好异常防护.
- 除非明确要求, 不对已有功能引入破坏性修改.
- 更新数据库记录时显式更新所有字段值（含 `updated_at`：没有触发器兜底）.
- 涉及用户数据的写入必须走事务, 保证失败可回滚.
- 注意代码可维护性.
