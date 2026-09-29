# Ronin 三端重构复盘：代码增长归因与分批执行方案（待审阅）

- 范围：`9d6a0f7^..95cf2a1`（5 个提交）
- 方法：`git diff --numstat -M`（全量聚合）+ `git ls-tree -r -l` 逐文件字节/行数 + `git grep -c -e '^'` 复核；本次**未改动任何文件**
- 口径说明：
  - `git diff --shortstat -- <path>` 会因路径过滤破坏重命名配对（`android/`→`frontend/`），使 frontend 虚高到 57,892；本文一律用 `--numstat -M` 全量聚合，302 处重命名中 189 处是纯改名（零虚增）。
  - 行数用 `git grep -c -e '^'`（非空行口径，可对任意 revision 复现）；与含空行的口径差 <2%，不影响结论。

---

## 一、先对齐：项目现状（我的理解，供校准）

| 端 | 目录 | 技术栈 | 职责 |
|---|---|---|---|
| 服务端 Monarch | `backend/`（Go + Gin） | modernc.org/sqlite 纯 Go、CGO_ENABLED=0 可用 | **唯一真理层**：媒体库、标签树、用户数据同步、AI 编排、漫画爬虫编排 |
| 运维端 | `ops/`（16 文件 / 3,930 行） | 纯静态 HTML + CSS + ES 模块，**零构建、零框架** | 仅回环可用；自身无本机权限，一切经 `/API/ops/*`、`/API/settings` |
| 消费端 | `frontend/`（Flutter，≈55.2k 行 lib） | Riverpod + GoRouter + Dio + Hive/sqflite/SharedPreferences | **当前是 Android 单平台**（平台分支 0 处、无 `windows/`） |

关键设计约定（已核实）：

- **数据**：单文件 SQLite（`DB_PATH`）；唯一真相源 `backend/internal/service/db/schema.sql`（`schema.go:12` `//go:embed`）；无触发器，`updated_at` 与 `gallery_tags.full_path` 级联由 Go 维护；写池固定 1 连接 + WAL（单写者），读池独立；`comix_*` 表共用同一文件。
- **外部进程**：`internal/service/proctask`（**仅 363 行**）统一管理 comix 爬虫与 gallery CLI（内存任务表 + 日志 + 进程树中断），由 Spec 参数化 —— comix 整包迁入的**耦合成本很低**，这是本轮少有的好消息。
- **AI 层**：`phash`(纯 Go) / `embed` / `face` / `ocr`（Python 侧车 `tools/ai/ronin_ai`，按需拉起、空闲退出）/ `vlm`（本机 Ollama）；输入档位只有 `preview256` / `ai1024`；`ai_results` 记录 `input_tier`+`executor`，reconcile 自动重排；队列持久化在 `ai_jobs`；单卡 GPU 由 `models.go` 仲裁。全部 86 条路由中 **31 条是 `/API/ai/*`（36%）**。
- **配置分层**：`.env` 只留 `DB_PATH/LOCAL_PORT/LOCAL_DEBUG_PORT/API_KEY_SERVER`，其余入 `app_settings`，`/API/settings` 的 `schema` 驱动 UI。
- **契约**：`cmd/route_export` 从 gin 路由表 + `internal/contract` 生成 `references/api/*` 与两端客户端。

---

## 二、五个提交在做什么

| 提交 | 主题 | 文件数 | +/- |
|---|---|---|---|
| `9d6a0f7` | 智能相册功能复刻，AI 引入 | 60 | +11,294 / -8 |
| `ea6d8b7` | 三段优化，移除 immich 反代 | 51 | +1,499 / -908 |
| `ef23c76` | GPU 硬件加速 | 19 | +176 / -119 |
| `b5b4219` | qwen 图文对话（两种版本）+ 页面优化 | 63 | +5,857 / -381 |
| `95cf2a1` | **三端重大重构**（SQLite / comix 迁入 / ops 转网页 / 目录改名） | 586 | +34,609 / -21,933 |
| **合计（`-M` 聚合）** | | **+40,373 / -21,573**；134 新增、113 删除、285 重命名 | |

**`95cf2a1` 独占全部新增的 86%，其中 backend 增量的 92.3% 也在它身上。**

体积变化：

| 区域 | 重构前 | 现状 | 变化 |
|---|---|---|---|
| `backend/`（文本行） | 18,657 | 37,637 | **+101.7%**（Go 15,538→23,290、Python 1,015→5,631） |
| `backend/references/` | 444 | 6,354 | ×14（几乎全是生成物） |
| `frontend/`（原 `android/`） | 49,286 | 58,127 | +13,627 / -2,087（净 +19.7%） |
| `ops/`（原 `desktop/`） | 13,285 行 Flutter | 3,930 行原生 JS | **−9,355 行 / −70%，本轮唯一的"优质减法"** |

---

## 三、增长归因：40,373 行新增里，约 36% 不是手写产品代码

### 3.1 生成物入库：约 8,900 行（22%）

| 文件 | 行数 | 是否被消费 |
|---|---|---|
| `backend/references/api/contract.json` | **5,116** | ❌ 生成器写完**从不回读**（用的是内存里的 `client.Doc`，`route_export/main.go:78`） |
| `frontend/.../generated/api_contract.dart` | **2,840**（65 类型 + 86 条 ApiPath） | ⚠️ 只有 `ApiPath` 被真正消费（27 文件 import） |
| `references/api/routes.json` + `routes.md` | ≈444 | ❌ 无人读 |
| `ops/js/generated/endpoints.js` | ≈240（8.5 KB） | ✅ `ops/js/api.js:24` import |

`95cf2a1` 里 `backend/references/api` 单项 **+5,215 / -10**，是全部新增的 13%；`frontend/lib/core` 新增 3,144 行中 **2,840 行（90%）就是那个生成文件**。

### 3.2 迁入 / 一次性资产：约 6,200 行（15%）

| 项 | 行数 | 说明 |
|---|---|---|
| `backend/gizmos/comix/` | **4,955**（27 个 Python 文件，9d6a0f7 时仓库内为 0） | 自带 `db.py` 899、`scheduler.py` 787、4 个 `adapters/`、多份 AGENTS.md、`docs/` 3 篇、`scripts/import_from_pg.py` |
| `backend/cmd/migrate_pg/` | **1,147** 行（`main.go` 单函数 1,147 行）+ 独立 go.mod/go.sum | 一次性迁移工具（仍依赖 pgx）；磁盘上另有未跟踪的 19 MB exe |

### 3.3 真正的新功能：AI 能力层 + 前端对话/回顾 ≈ 14,000 行（35%）

| 位置 | 行数 |
|---|---|
| `internal/service/ai/`（18 文件） | 4,996 |
| `internal/repository/ai_repo/`（5 文件） | 1,784 |
| `internal/handler/ai_handler/`（3 文件） | 1,207（其中 `ai_handler.go` 896 行 **38 个函数**） |
| `internal/service/review/` + `proctask/` | 903 |
| `backend/tools/ai/ronin_ai/` + `install.ps1` | ≈1,230 |
| `frontend/.../features/chat/` | 2,487（**新**） |
| `frontend/.../features/review/` | 1,558（**新**） |
| `ops/js/views/ai.js` | 1,189（单文件） |

新增行归因（backend）：AI 三层（`service/ai` +1,531、`ai_repo` +956、`ai_handler` +542）= **3,029 行，占 Go 新增的 39%**；comix +4,955、`contract.json` +5,115、`migrate_pg` +1,252、`internal/contract` +1,145。

### 3.4 结论

> **增长第一原因 = "AI 能力层"这条横跨 Go 服务 / Python 侧车 / Ollama / 两端 UI 的新链路（≈14k 行、35%）。**
> 第二才是 `95cf2a1` 的重构本身，而它一半体积来自**生成物 8.9k + 外部项目与一次性工具 6.2k**，不是手写代码。
> 唯一的减法是 ops：3,930 行零框架 JS 替掉 13,285 行 Flutter 桌面端。

---

## 四、复杂度上升的根因（按影响排序）

### R1 AI 层的"同一事实登记 4~5 遍"+ 双协议并行（最大）

**登记重复**：加一个 AI 能力要同时改 5 处，且其中两处是**同一信息的两份手写字面量**：

| 位置 | 内容 |
|---|---|
| `internal/model/ai.go:19` | `AllCapabilities` 常量 |
| `internal/settings/settings.go:55` | `CapabilityNames = {"phash","embed","face","ocr","vlm"}` ← **未引用上面的常量** |
| `internal/service/ai/spec.go:14-27` | `capabilityLabels` + `buildinImplementations` + `Executor` switch |
| `internal/service/ai/spec.go:51-54` | `executorSettingKeys`（能力→配置键**再次**重复） |
| `internal/contract/contract.go:64-77` | 契约侧的第四份登记 |

**双协议并行**：`service/ai/ollama.go`（655 行）里同时有 `Generate`（`POST /api/generate`，`format=json`，后台标注）与 `Chat`（`POST /api/chat`，NDJSON，前端对话）两套请求体/事件/错误处理，外加第三份同样的 `Unload` 样板；`chat_handler.go`(226) 自带另一套常量与校验。二者共享同一 GPU 与仲裁器，却不共享任何代码。

**"两种版本"的真实代价**：`b5b4219` 一次 +1,464 行，只为让标准版与无审查备选版两个 VLM 模型在单卡上共存（`spec.go:106-122` + `models.go` 242 + `models_test.go` 202 = 444 行）。

一个 AI 需求要同时改：`model/ai.go`、`service/ai/spec.go`、`settings.go:55`、handler、router、`contract/contract.go`，再重新生成契约 —— **这是本轮复杂度上升的主因**。

### R2 契约 codegen 自建，产出大半没人用

- 自建代码：`internal/contract/` **1,145 行**（contract/document/endpoints/naming/schema/dart/js）+ `cmd/route_export` 75 + `generate_refs.ps1` 116。
- 产出 65 个类型，实测只有 **17 个**在生成文件之外被按名引用，其中 `MediaAsset`(33 文件) `Tag`(21) `MediaTagLink`(6) `BatchData`(3) 存在**同名手写模型**（`others/gallery/models/media_asset.dart:9`、`tag.dart:9` …），业务代码用的是手写那套；`MediaQueryResponse`/`MediaPatchRequest`/`TagCreateRequest`/`MediaTagsBatchRequest`/`MediaTagsRequest` **零引用**。→ **约 48/65（74%）的生成类型是死重量**，同时前端还留着 **43 个手写 models 文件**。
- `contract.json` 内部还重复存了一份 86 条路由（`document.go:30-35`）。**同一条路由事实被写进 6 份产物**：`routes.json`、`routes.md`、`contract.json.routes`、`contract.json.endpoints`、`api_contract.dart`、`endpoints.js`。
- 需求"契约由生成而非手工同步"**只在端点这一半兑现**。

### R3 `frontend/lib/features/others/` 仍是前端主体（119 文件 / ≈23.8k 行 = 43.1%）

| 子应用 | 文件 / 行数 |
|---|---|
| `others/gallery` | 62 / 13,221（55.5%） |
| `others/comic` | 37 / 5,739 |
| `others/immich` | 10 / 3,388 |
| `others/smart_album` | 3 / 729 |
| `others/{ai,widgets,shared,pages}` + 直属 | 7 / ≈762 |

- 前端最大的 20 个文件里 **13 个（65%）在 others/**：`tag_drag_overlay.dart` 1,026、`medias_browser_page.dart` 853、`setting_page.dart` 843、`immich_ops_sheet.dart` 849、`label_list_page.dart` 773、`comic_read_scroll.dart` 792、`gallery_database_service.dart` 722、`download_task_provider.dart` 756…
- others 净增只有 +1,450 行，背后却是 **+4,498 / -1,836 的反复重写**（单文件净减榜几乎全是 others）。
- 命名两套并存：漫画用 `provider/`（11 文件 2,185 行），其余用 `providers/`（29 文件 3,619 行）。

### R4 同一样东西三份实现：网格 / 标签树 / 写路径 / 分页（需求未收口）

| 重复项 | 证据 |
|---|---|
| **网格单元 3 份** | `proportional_cell` ↔ `waterfall_cell` 共享 104 行（相似度 86%）；`grid_tile` 与二者 76% / 74% |
| **标签树 UI 4 份** | `label_list_page`(773) ↔ `immich_tag_tree`(497) 共享 108 行；`_initExpanded` 就有 4 份；`immich_ai_tag_sheet`、`immich_ops_sheet` 再各接一遍 |
| **服务端写路径 3 条** | `tag_providers.dart:165-180` 与 `media_providers.dart:290-307` 各自实现「baseline→db.setTagsForMedia→invalidate→queueTags→bumpModifiedCount」；`immich_providers.dart:284-298` 直接 `retryServerWrite(batchMediaTags)` **绕过缓冲、无回滚**；`gallery_sync_service.dart:349` 再直连 `patchMedia` |
| **分页模型 2 套** | `mediaPageSize` 只被 `gallery_api_service.dart:113` 与 `immich_providers.dart:143` 使用；分页状态只在 immich（`hasMore:125`/`loadMore:166`）；gallery 走下载批次镜像、comic 走本地文件系统 |
| **其它** | 全库 51 对超阈值相似文件；12 个纯 export barrel；5 个文件直接 `Dio()` 绕开 `ApiClient`；provider 文件 79 个 |

### R5 页面没有变薄（"状态与业务逻辑下沉"半做，且反向）

`setState` 仍有 **175 处 / 40 个文件**（`comic_read_scroll` 19、`video_player_widget` 10、`immich_ops_sheet` 9、`tag_drag_overlay` 9、`booklet_overview` 8）。
`pages/` 占比 23.1%→19.5%，但**绝对行数 10,656→10,761（反增 105）**；`widgets/` 25.1→25.2%、`providers/` 21.5→21.8% 基本没动。
状态方案本身是统一的（Riverpod：`@riverpod` 110 处、无 Bloc/GetX），但残留 `StateNotifierProvider` 2 处、`ValueNotifier` 2 处。
另有 **58/304（19%）是 `.g.dart` 生成文件**（booklet 35%、providers 57%）。

### R6 需求与文档已经不一致（会误导后续）

`frontend/AGENTS.md` 明确写"**只出 Android 一个平台**、代码里不存在平台分支"，与需求"扩为 Android + Windows 桌面端、按平台分支或替换"**完全相反**。
更准确的说法不是"没做"，而是：**架构选择把 Windows 端整体作废了** —— 原 `desktop/`（13,285 行）被删除，运维能力改由 `ops/` 网页承担；因此"Windows 持久化不落系统盘 / 不用 shared_preferences / json 存程序目录"这三条在 frontend 语境下已不适用（唯一痕迹是被删代码里残留的 SharedPreferences 双写兜底）。
**但需求写在 frontend 名下，这一点必须由你确认意图**（见 Wave 0 / D1）。若仍要 Windows 版，`Hive + SharedPreferences + sqflite + getExternalStorageDirectory` 这套（AGENTS.md 第 39-46 行表格）全部要动，还有 `public_storage_service.dart:20` 硬编码的 `/storage/emulated/0/Pictures/torrid`。

---

## 五、需求完成度审计

### backend（8 条）：全部落地

| # | 需求 | 状态 | 证据 |
|---|---|---|---|
| 1 | 迁 SQLite | ✅ | `schema.sql` + `AGENTS_DB.md`（写池单连接 + WAL + `db.Tx` 分段提交）；触发器/数组/BLOB 有替代 |
| 2 | 一次性迁移、原库保留、抽样校验 | ✅ | `cmd/migrate_pg -verify-sample`；独立 module，主服务不依赖 PG 驱动 |
| 3 | comix 迁入 `gizmos`、PG→SQLite | ✅ | 4,955 行；`import_from_pg.py` |
| 4 | AI 输入分档 | ✅ | `tier.go`、`<GALLERY_DIR>/AI/` |
| 5 | 溯源 + 自动重排 + 候选后端下发 | ✅ | `ai_results.input_tier/executor`、`EnqueueStale`、`/API/ai/capabilities` |
| 6 | 配置分层 + schema 驱动 UI | ✅ | `internal/settings`、`/API/settings` |
| 7 | ops 本机能力接口、仅回环 | ✅ | `/API/ops/*` 全套 |
| 8 | 未启用 AI 完整降级 | ✅ | capabilities 如实报因、入队 409、检索退化关键词、review 仍回统计 |

### frontend（6 条）

| # | 需求 | 状态 | 证据 |
|---|---|---|---|
| 1 | Android + Windows 双端、平台分支 | ⛔ **被架构作废** | 无 `frontend/windows/`；`Platform.isWindows`/`kIsWeb`/`defaultTargetPlatform` 全 **0** 处；pubspec 无 window_manager/system_tray/file_picker |
| 2 | 两步走（先可跑，再宽屏） | ⛔ 同上 | 同上 |
| 3 | Windows 持久化规则 | ⛔ 同上 | 同上（`desktop/` 已删） |
| 4 | user_data 按 `updated_at` 增量合并 + 墓碑 | ✅ | `test/user_data_sync_test.dart` 369 行 + `user_data_sync.dart` 219 行 |
| 5 | 结构治理（others、下沉、合并、契约生成） | ⚠️ **约 1/3** | ✅ `tag_tree.dart` 113 行被 5 处引用、`gallery_api_service` 类型化写、写缓冲；❌ others 43% 未动、网格 3 份、标签树 UI 4 份、写路径 3 条、分页 2 套、页面反增 105 行 |
| 6 | 近期回顾 | ✅ | `internal/service/review`(539) + `features/review`(1,558) |

### ops（6 条）+ 全局（4 条）

| # | 需求 | 状态 |
|---|---|---|
| ops 1–6 | 网页应用 / 本机能力经后端 / gallery CLI 生命周期 / 删"替换封面" / 偏好后端 json / 显式丢弃托盘等 | ✅ 全部落地（`ops/AGENTS.md` 有"刻意去掉"清单） |
| 全局 1–2 | 先减法、可读性优先、绝不过度设计 | ⚠️ ops 做到了；`references/` 与契约生成是反向案例 |
| 全局 3 | android→frontend、desktop→ops 改名 | ✅ |
| 全局 4 | 重审 copilot-instructions 与各 AGENTS.md | ⚠️ backend/ops 已更新；frontend 的"单平台"表述与需求目标冲突；契约产物清单即将过期 |

---

## 六、关于 `references/api` 生成物与 `generate_refs.ps1`（直接回答你的三个问题）

**Q1：被 git 追踪是否不合适？** 要分开看：

| 产物 | 是否被消费 | 追踪是否合适 |
|---|---|---|
| `frontend/lib/core/api/generated/api_contract.dart`（83 KB） | ✅ 27 个 Dart 文件 import（`ApiPath` 常量 + `xxxPath()`） | **必须追踪**（无它无法编译） |
| `ops/js/generated/endpoints.js`（8.5 KB） | ✅ `ops/js/api.js:24` import（ops 唯一 HTTP 出口） | **必须追踪**（无构建步骤） |
| `references/api/contract.json`（5,116 行） | ❌ 生成器写完从不回读 | 可留（唯一机器可读快照），但**必须去时间戳** |
| `references/api/routes.json` | ❌ 无人读，是 `contract.json` 的子集 | **不合适**：同一数据存两遍 |
| `references/api/routes.md` | ❌ 无人读 | **不合适**：再渲染一遍 |
| `references/db/schema.sql` | ❌ 无人读（真正生效的是 `internal/service/db/schema.sql`，`//go:embed`） | **不合适**：550 行副本 |
| `references/cli/*.md` | ❌ 纯人看 | 可留（CLI 契约唯一文档），但含 `GeneratedAt` 与机器绝对路径 `D:\products\Ronin\backend` |
| `references/db/{gallery,user_data,ai,comix}.md` | ❌ 纯人看 | ✅ **手写文档**，保留 |

**Q2：`generate_refs.ps1` 是否已"过时"、产物没作用？**
**没有过时。** 它一步生成的两端客户端文件是**真正被编译/运行消费**的（删 `api_contract.dart` → 27 个 Dart 文件编译失败；删 `endpoints.js` → ops 全部接口不可用）。路径核对也无误：`generate_refs.ps1:99-100` 的写入位置与 `route_export/main.go:30-31` 的默认值指向同一处。
它真正的缺陷是**所有入库产物都带时间戳**（`generated_at` / `GeneratedAt` / `WorkingDir`），因此**跑一次脚本即使内容没变也会产生 diff**。实证：`routes.md` 在最近 9 个提交里每次都被重写，`cli/monarch-main.md` 8 次。这才是"产物看着没用却一直在涨"的真实原因 —— **同一份数据存了三遍还带时间戳**。

**Q3：删掉生成的那些 .md 文件吧？** 建议这样处置（净减 ≈1,000 行 + diff 噪音归零）：

1. **删** `references/api/routes.md` 与 `routes.json` —— 同时删掉 `route_export` 的 `-md`/`-json` flag、`writeMarkdown`/`writeJSON`/`routeSnapshot`（`main.go:20-23,26-27,63-71,122-134,157-172`）与 `generate_refs.ps1:96-97`。
2. **删** `references/db/schema.sql` 副本（并从 `generate_refs.ps1:102-104` 摘掉 `Copy-Item`）。
3. **去时间戳**：`contract.json` 不写 `generated_at`；`cli/*.md` 不写 `GeneratedAt`/`WorkingDir`。让"重新生成但内容未变"= 零 diff（`api_contract.dart` 与 `endpoints.js` 现在**已经**无时间戳，做得好，保持）。
4. **保留** `contract.json`（一份足够）+ 两端客户端产物 + `references/db/*.md`（手写）+ `references/cli/*.md`（按第 3 点去噪）。

> 删 `routes.json` 需同步改 3 处引用：`backend/AGENTS.md:109`、`frontend/AGENTS.md:53`、`.github/copilot-instructions.md:8`。

---

## 七、分批执行方案（工作包，供审阅）

原则：**先减法、再结构、后功能**；同波内目录不重叠，可并行分发；每包自带验收。仓库目前**没有 CI**（`.github` 只有 copilot-instructions.md），所有验收靠手动命令。

### Wave 0 — 先裁决（不写代码）

| 编号 | 需要你决定 | 影响 |
|---|---|---|
| D1 | frontend 的 **Windows 端**这一轮还做不做？（现状是"被架构作废"，但需求写在 frontend 名下） | 决定 WS-9 是否存在；不做就把 `frontend/AGENTS.md` 定位与需求一起改写 |
| D2 | 契约产物按第六节处置，还是更激进地**连 `contract.json` 也不追踪**？ | 决定 WS-1 范围 |
| D3 | 生成的**模型类型**：只生成端点（删掉 ≈48 个死类型，省 ≈2,000 行 Dart + 简化 1,145 行 Go），还是把 43 个手写模型迁到生成模型？ | 决定 WS-2 是"缩小"还是"迁移" |
| D4 | `migrate_pg`(1,147 行 + 独立 module + 19 MB 未跟踪 exe) 与 comix 的 `import_from_pg.py` / `docs/验收步骤.md` 是**留在主干**还是移出归档？ | 决定 WS-3 范围 |

### Wave 1 — 优质减法（低风险，4 路并行）

| 包 | 目标 | 范围 | 验收 |
|---|---|---|---|
| **WS-1** 生成物瘦身 | 删冗余产物、消除时间戳噪音 | 第六节 1–3 步；3 处文档引用 | 连跑两次 `generate_refs.ps1`，第二次 `git status` 为空 |
| **WS-2** 契约收敛（按 D3） | 让契约子系统只做被消费的事 | `internal/contract/*`(1,145)、`api_contract.dart`(2,840) | 无业务文件引用被删类型；`flutter analyze` 零告警；生成物行数显著下降 |
| **WS-3** 一次性/外部资产归位（按 D4） | 主干只留活代码 | `cmd/migrate_pg/`、`comix/scripts/import_from_pg.py`、`comix/docs/`、comix 多份重复 AGENTS.md | 主 module 构建不受影响；归档处有 README 说明"何时才需要" |
| **WS-4** 后端死代码/平台核查 | 确认没有残余依赖 | `internal/service/immich_client/`（immich 反代已移除，它是否还需要）、`go.mod` 依赖、`comix` 的 PG 残留 | `go mod why` 每个可疑依赖有结论；无引用包被删 |

### Wave 2 — 结构治理（4 路并行，目录不重叠）

| 包 | 目标 | 范围 | 验收 |
|---|---|---|---|
| **WS-5** `others/` 拆分与下沉 | 解散 119 文件 / 23.8k 行的杂物间 | `others/{gallery,comic,immich,smart_album,ai}` → `features/gallery`、`features/comic`、`features/immich`…；统一 `provider/` 与 `providers/` 命名；**pages 里的 setState(175 处/40 文件) 下沉到 providers** | others 残留 < 1,000 行；`flutter analyze` 零告警；页面行为不变 |
| **WS-6** 重复实现合并 | 网格 3→1（省 ≈350 行）、标签树 UI 4→1、写路径 3→1、分页 2→1 | `proportional_cell`/`waterfall_cell`/`grid_tile`；`label_list_page`/`immich_tag_tree`/`immich_ai_tag_sheet`；三条写路径（含 immich 绕过缓冲无回滚那处）；`mediaPageSize` 分页抽象 | 单一实现 + 单测；`flutter test` 通过；全库相似文件对数显著下降 |
| **WS-7** ops JS 拆分 | 页面文件回到可读规模 | `views/ai.js`(1,189) 拆为能力卡片/队列/对话等模块，复用 `dom.js`/`tasks.js` | 无单文件 > 400 行；`http://127.0.0.1:<LOCAL_DEBUG_PORT>/ops/` 手动冒烟各页 |
| **WS-8** backend AI 层收敛 | 消除"同一事实登记 4~5 遍"与双协议样板 | 单一能力注册表（替代 `model/ai.go:19` + `settings.go:55` + `spec.go:14-27,51-54` + `contract.go:64-77`）；`ollama.go` 三种 HTTP 往返抽公共层；`ai_handler.go`(896/38 函数) 拆分 | `go build && go vet && go test` 全绿；`/API/ai/*` 对外零变化；**"加一个能力只需改 1 处"** 作为验收标准 |

### Wave 3 — 功能与收尾

| 包 | 目标 | 依赖 | 验收 |
|---|---|---|---|
| **WS-9** frontend Windows 端（若 D1=做） | 先"可编译可运行功能不缺失"，再统一断点宽屏 | D1 | ① Windows 出包可跑（媒体播放/本地库/缓存/相册/权限按平台分支或替换）；② 持久化不落系统盘、轻量数据用程序目录 json、去 shared_preferences；③ 再做宽屏断点（不逐页两套） |
| **WS-10** 文档重审 | copilot-instructions + 4 个 AGENTS.md 精简准确 | 全部 | 描述与代码一致；无过时/冗余（契约产物清单、frontend 平台表述） |
| **WS-11** 验收 | 三端构建与回归 | 全部 | `backend/` 与 `backend/gizmos/` 各跑 `go build ./... && go vet ./... && go test ./...`；`frontend/` `flutter analyze`（零告警）+ `flutter test`；ops 回环冒烟；契约重生成零 diff |

### 依赖与节奏

```
Wave 0（你裁决 D1–D4）
   ├─ Wave 1：WS-1 / WS-2 / WS-3 / WS-4      （互不重叠，4 路并行）
   ├─ Wave 2：WS-5 → WS-6（同区，建议串行）；WS-7 / WS-8 可与之并行
   └─ Wave 3：WS-9（依赖 D1）→ WS-10 → WS-11
```

**风险提示**

- **WS-5 是最大的一次性改动**（22.5k 行搬家）。现有 5 个测试文件只是底线，建议先补 2–3 个关键路径 widget 测试再搬。
- **WS-2 若选 D3 的"迁移手写模型"**，风险远高于"只生成端点"：会碰 Hive typeId 与字段下标不可重排的硬约束（`开发备忘.md:42`）—— **建议选"只生成端点"**。
- **WS-9 风险最高**：一次碰 Hive / SharedPreferences / sqflite 三套持久化，建议单独开一轮、不与其它包并跑。
- **所有验证需要写权限沙箱**：当前只读模式下 `go build` 连 `GOCACHE` 都建不了（实测 `Access is denied`），`flutter analyze` 同理。

---

## 八、一句话总结

真正的增长是 **AI 能力层（≈14k 行、跨三端）** 加上一批**"不是代码的代码"（生成物 8.9k、外部项目 4.9k、一次性工具 1.1k）**；复杂度上升的主因是 **AI 能力登记散在 5 处 + 同一模型跑两套协议**、**自建契约生成却只消费了一半产出（同一条路由存 6 份）**、以及 **frontend 的 `others/`、网格、标签树、写路径、分页始终没被合并**；而需求里最重的 frontend 双端改造**已被架构作废**（这点需要你确认）。建议先做 Wave 1 的减法（≈1,000 行冗余产物 + diff 噪音归零，零功能风险），再动 Wave 2 的结构，最后才谈 Windows 端。
