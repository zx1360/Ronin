## 项目说明 (Torrid)

Flutter 目标平台仅为安卓移动端的应用，Ronin 三端架构的消费端。所有持久化数据通过 Monarch 后端 API 存取。

### 核心功能与后端依赖

| 功能页 | 路由 | 后端 API |
|--------|------|----------|
| 启动屏 | `/splash` | - |
| 首页 | `/home` | - |
| 积微(打卡) | `/booklet` | `user-data` sync `/API/user-data/*` |
| 随笔(笔记) | `/essay` | `user-data` sync `/API/user-data/*` |
| 对话(本地 AI) | `/chat`（二级页 `/chat/settings`、`/chat/review`、`/chat/review/presets`） | `POST /API/ai/chat`、`POST /API/ai/review`（NDJSON 流） |
| 阅读(RSS) | `/news` | 独立第三方接口 |
| 漫画 | 由 `/others` 页 `Navigator.push` 打开 | `/API/comic/*` |
| 画廊 / 相册(immich) / 智能相册 | 由 `/others` 页 `Navigator.push` 打开 | `/API/gallery/*`、`/API/ai/*` |
| 个人 | `/profile` | 本地存储 |

> 只有上表列出的顶层路由是 GoRouter 路由；`/others` 下的二级页用 `Navigator.push` 进入.

### 技术栈

- 状态管理：Riverpod + riverpod_generator
- 路由：GoRouter
- 网络请求：Dio（自签证书兼容）
- 本地存储：Hive + SharedPreferences + sqflite
- 媒体播放：chewie, video_player, photo_view
- 代码生成：json_serializable + build_runner + hive_generator
- 静态检查：`flutter analyze` 必须零告警；`analysis_options.yaml` 已排除 `*.g.dart`
- 全应用锁定竖屏（`main.dart`）；画廊内媒体的旋转由页面自身处理（`quarterTurns`）

### 与后端协同

- API 变更见 `../backend/references/generated/api/routes.md`（生成物，需在后端跑一次 `references/scripts/generate_refs.ps1`）。
- AI 能力未启用（服务端 `AI_ENABLED=false`）或 AI 表未初始化时，AI 接口返回 503；
  调用方一律"降级可用"而不是把错误抛到界面上：相册 AI 标签入口、智能相册的 AI 结果块
  在失败时整块隐藏，检索/人物页把 503 换成明确说明（`aiFriendlyError`，`features/others/ai/services/`）。
  能力的展示名由 `/API/ai/capabilities` 下发（端上不硬编码能力清单），失败时原样显示标识即可。
- 网络层：`lib/core/services/network/`、`lib/providers/api_client/`、`lib/providers/network_config/`。
- 服务器连接配置唯一真相源为 `providers/network_config/`（`NetworkConfigManager`，持久化于 SharedPreferences 的 `PC_HOST_LIST`/`PC_ACTIVE_INDEX`/`API_KEY`）；`providers/api_client/` 的 `ApiClientManager` 通过监听该状态派生 `ApiClient`.
- 统一异常：`ApiClient` 提供 `ApiException` 错误映射与幂等 GET 自动重试；fetcher 系列统一走 `ApiClient.mapError`，UI 不应直接处理底层协议异常。
- 自签证书：`assets/cert/`，通过 `CertTrust` 加载（仅信任加载的自签证书，`withTrustedRoots=false`，与桌面端一致）。
- **画廊/相册数据权威**：服务端权威 + 本地缓存 + 操作式写入。标签、标签关系、媒体标注（is_deleted/message/group_id/edit_params）全部经 `/API/gallery/*` 写服务端；本地 `gallery.db` 只是缓存（下载批次镜像、写操作回写），跨端不会互相覆盖。
  - 写入口：`services/gallery_api_service.dart`（类型化操作接口）。
  - 交互流畅性：`services/gallery_write_buffer.dart` + `providers/write_buffer_provider.dart` 提供「本地立即生效 → 后台合并推送 → 退避重试 → 最终失败回滚」，批量/低频操作走 `retryServerWrite`。
  - 批次处理游标：设置页「标记已处理」= 服务端 `sync_count + 1`（PATCH `/media` 的 `mark_processed`）+ 清理本地已处理记录与文件。
  - 标签树的分组/扁平化/搜索命中/祖先判断统一在 `models/tag_tree.dart`（`groupTagsByParent` /
    `flattenTagTree` / `matchedTagIds` / `isAncestorOf`），行尾紧凑图标按钮统一用
    `widgets/tag_icon_tap.dart`；immich 标签面板、标签列表页、快速打标签浮层共用同一份，不再各写一套。
  - 写路径**有意分两种**，不要为"统一"而合并：画廊页走 `services/gallery_write_buffer.dart`
    （本地立即生效 → 后台合并推送 → 失败回滚，可离线），相册页(immich)走 `retryServerWrite`
    在线直达服务端（该页始终在线）。筛选参数则已统一由 `GalleryApiService.queryMedia` 下发。
  - 画廊侧单条标注（备注 / 编辑参数 / 软删除 / 捆绑）统一走 `media_providers.dart` 的
    `MediaAssetList`（`setMessage` / `setEditParams` / `markDeleted` / `bundleMedia`
    共用私有 `_applyLocalAndQueue`）；**页面不要自己写 `updateMediaAsset + queuePatch`**
    （详情页/图片编辑页/视频剪辑页都曾各抄一遍，且抄漏内存态同步）。
  - 页面的状态与业务逻辑下沉到各自 `providers/`（如 `smart_album/providers/`）：页面只留渲染、
    导航与选择模式，请求编排、加载态、错误映射都在 provider 里。
  - 清空本地缓存（数据库 / 文件 / 全部）走 `providers/local_data_providers.dart` 的
    `GalleryLocalDataController`：清完复位游标并失效派生数据；设置页只负责二次确认。它**只清本机**
    （gallery.db 与下载的文件），不触碰服务端。
- mDNS 自动发现：`/profile` → 网络设置页点击“发现”可扫描局域网内的 Monarch 服务，发现的新地址会自动添加到配置列表。

### 对话页 (本地 AI)

- 会话与消息只存本机（Hive `chatConversations`，模型见 `features/chat/models/`）：一次会话整体读写，
  流式增量只更新内存，一轮结束（或失败）才落库。
- 请求经 `features/chat/services/chat_api_service.dart`（`POST /API/ai/chat`，逐行解析 NDJSON）；
  对话设置（模型/上下文/思考/温度/自定义卸载超时）存 SharedPreferences，随每次请求下发。
  可选模型不做端上硬编码：取 `/API/ai/capabilities` 的 `executor_candidates`（服务端实时从本机
  Ollama 取，含 `installed`/`vision`）；本地保存的模型已被删除时自动清空为"跟随后端"。
- 流式事件里 `notice` 用 SnackBar 提示、`aborted`（被另一个模型抢占）标为"已中断 + 继续"而不是
  错误；气泡文本不可选中（长按复制），避免文本选择器抢走上下拖动。
- 消息列表只有处于"贴底"状态才跟随流式输出，用户上滑翻阅历史时不强拉，并给出"回到最新"按钮。
- 图片附件：库内媒体只传 `media_id`（后端就地取预览图，手机端无需下载）；手机相册图片压到长边 1280
  后拷入 `img_storage/chat/`，以 base64 内联发送。删除会话会一并清理这些本地图片。
- "问问AI"入口统一走 `features/chat/chat_entry.dart`（藏品详情页 / 相册 / 智能相册的查看页）。
- 画廊快速打标签浮层（`widgets/tag_drag_overlay.dart`）随媒体旋转方向（`quarterTurns`）旋转；
  浮层内所有几何与命中判定都在其自身坐标系内完成（手指屏幕坐标经根节点 `globalToLocal` 换算），
  构建期只使用 [LayoutBuilder] 给出的换轴尺寸——直接读根节点 `size` 会触发 `hasSize` 断言。
- 相册页(immich)的 AI 标签筛选走 `widgets/immich_ai_tag_sheet.dart`（可搜索、按次数排序、
  点击切换），筛选栏只留入口与已选条件，避免几十个标签挤占横向空间。

### 近期回顾 (`/chat/review`)

- 统计与抽样全在**后端**（booklet/essay 数据只在那里），端上只选角色/语气预设与时间范围，
  再消费 NDJSON 流：`stats` 事件（本次依据的确定性统计，页面上可展开核对）→ `delta` 逐字正文。
- 沿用对话设置的模型/上下文/温度/卸载超时；**思考链固定关闭**（一次性写作，思考只拖慢首字且端上
  不展示），设置页已注明。
- 生成结果**只存本机**（Hive `reviewHistory`，见 `_HistoryDrawer`），可回看与删除，不上传；
  载入历史不会覆盖草稿以外的任何数据。
- 角色/语气预设以服务端 `<STATIC_DIR>/data/review_presets.json` 为权威：读取时先用 Hive 镜像
  （离线可用）再异步对齐，编辑保存时**整体推送**，成功后才刷新镜像；失败则两侧都保持原样。
- 流式解析复用 `features/chat/services/chat_api_service.dart` 的 `streamNdjsonEvents`
  （chat 与 review 共用），不要在服务层再抄一份逐行解析。

### 数据安全约定

- 同步（`/API/user-data/sync/*`）是**整体替换**语义：必须先完整解析校验、再清空写入本地 Box，任何一条数据非法都必须直接抛出而不破坏既有数据（参见 `essay_notifier_provider.dart` / `routine_service_provider.dart` 的 `syncData`）。
- 派生统计（标签计数、年度汇总）一律以本地实际数据重算，不信任持久化下来的计数：`refreshLabel` 会把计数为 0 的标签写回，`deleteZeroLabels` 只删除确实没有任何随笔引用的标签。
- Riverpod 派生 provider 返回列表/对象的副本；Box 流里的实例是共享的，就地排序或洗牌会污染其它消费者。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，防止异常。除非明确要求，不引入破坏性修改。
