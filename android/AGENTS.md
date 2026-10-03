## 项目说明 (Torrid)

Flutter 目标平台仅为安卓移动端的应用，Ronin 三端架构的消费端。所有持久化数据通过 Monarch 后端 API 存取。

### 核心功能与后端依赖

| 功能页 | 路由 | 后端 API |
|--------|------|----------|
| 启动屏 / 首页 | `/splash`、`/home` | - |
| 积微(打卡) | `/booklet` | `/API/user-data/*` |
| 随笔(笔记) | `/essay` | `/API/user-data/*` |
| 对话(本地 AI) | `/chat`（二级页 `/chat/settings`、`/chat/review`、`/chat/review/presets`） | `POST /API/ai/chat`、`POST /API/ai/review`（NDJSON 流） |
| 阅读(RSS) | `/news` | 独立第三方接口 |
| 漫画 | 由 `/others` 页 `Navigator.push` 打开 | `/API/comic/*` |
| 画廊 / 相册(immich) / 智能相册 | 由 `/others` 页 `Navigator.push` 打开 | `/API/gallery/*`、`/API/ai/*` |
| 个人 | `/profile` | 本地存储 |

只有上表列出的顶层路由是 GoRouter 路由；`/others` 下的二级页用 `Navigator.push` 进入。

### 技术栈

- 状态管理：Riverpod + riverpod_generator；路由：GoRouter；网络：Dio（自签证书兼容）
- 本地存储：Hive + SharedPreferences + sqflite
- 媒体播放：chewie, video_player, photo_view
- 代码生成：json_serializable + build_runner + hive_generator
- 静态检查：`flutter analyze` 必须零告警；`analysis_options.yaml` 已排除 `*.g.dart`
- 全应用锁定竖屏（`main.dart`）；画廊内媒体的旋转由页面自身处理（`quarterTurns`）
- **新增 Hive 模型前先看 `../开发备忘.md` 的 typeId 占用表**：typeId 发布后不可复用，只能往后取号

### 网络与后端协同

- API 变更读生成物 `../backend/references/generated/api/routes.md`（先在后端跑
  `references/scripts/generate_refs.ps1`）；端上 DTO 手写，改接口后照快照的处理函数读响应结构。
- AI 未启用（服务端 `AI_ENABLED=false`）或 AI 表未初始化时接口返回 503，调用方一律**降级可用**
  而不是抛错到界面：相册 AI 标签入口、智能相册的 AI 结果块失败时整块隐藏；检索/人物页把 503
  换成明确说明（`aiFriendlyError`）。能力展示名由 `/API/ai/capabilities` 下发，端上不硬编码。
- 服务器连接配置的唯一真相源是 `providers/network_config/`（`NetworkConfigManager`，持久化在
  SharedPreferences 的 `PC_HOST_LIST`/`PC_ACTIVE_INDEX`/`API_KEY`）；`providers/api_client/` 的
  `ApiClientManager` 监听该状态派生 `ApiClient`，**不要手动推送**。
- 统一异常：`ApiClient` 提供 `ApiException` 映射与幂等 GET 自动重试；fetcher 系列统一走
  `ApiClient.mapError`，UI 不直接处理底层协议异常。
- 自签证书在 `assets/cert/`，经 `CertTrust` 加载（`withTrustedRoots=false`）。
- mDNS 自动发现：`/profile` → 网络设置页点"发现"扫描局域网 Monarch，新地址自动入列表。

### 画廊 / 相册的数据权威

**服务端权威 + 本地缓存 + 操作式写入**：标签、标签关系、媒体标注（is_deleted/message/group_id/
edit_params）全部经 `/API/gallery/*` 写服务端；本地 `gallery.db` 只是缓存（下载批次镜像、写操作
回写），跨端不会互相覆盖。

- 写入口：`services/gallery_api_service.dart`（类型化操作接口）。
- **写路径有意分两种，不要为"统一"而合并**：画廊页走 `services/gallery_write_buffer.dart`
  （本地立即生效 → 后台合并推送 → 退避重试 → 失败回滚，可离线）；相册页(immich)走
  `retryServerWrite` 在线直达服务端（该页始终在线）。筛选参数已统一由 `GalleryApiService.queryMedia` 下发。
- 画廊侧单条标注（备注 / 编辑参数 / 软删除 / 捆绑）统一走 `media_providers.dart` 的
  `MediaAssetList`（`setMessage`/`setEditParams`/`markDeleted`/`bundleMedia` 共用私有
  `_applyLocalAndQueue`）；**页面不要自己写 `updateMediaAsset + queuePatch`**（会漏内存态同步）。
- 标签树的分组/扁平化/搜索命中/祖先判断统一在 `models/tag_tree.dart`；行尾紧凑图标按钮统一用
  `widgets/tag_icon_tap.dart`；immich 标签面板、标签列表页、快速打标签浮层共用同一份。
- 批次处理游标：设置页「标记已处理」= 服务端 `sync_count + 1`（PATCH `/media` 的 `mark_processed`）
  + 清理本地已处理记录与文件。
- 页面的状态与业务逻辑下沉到各自 `providers/`：页面只留渲染、导航与选择模式。
- 清空本地缓存走 `providers/local_data_providers.dart` 的 `GalleryLocalDataController`（只清本机
  gallery.db 与下载的文件，不触碰服务端）；设置页只负责二次确认。

### 对话页 (本地 AI)

- 会话与消息只存本机（Hive `chatConversations`）：一次会话整体读写，流式增量只更新内存，
  一轮结束（或失败）才落库。
- 请求经 `features/chat/services/chat_api_service.dart`（逐行解析 NDJSON）；对话设置
  （模型/上下文/思考/温度/卸载超时）存 SharedPreferences 并随每次请求下发。
- 可选模型不做端上硬编码：取 `/API/ai/capabilities` 的 `executor_candidates`（含 `installed`/`vision`，
  拿不到就如实显示"无法获取模型清单"）；本地保存的模型已被删除时自动清空，改为跟随后端当前选定模型。
- 流式事件：`notice` 用 SnackBar 提示；`aborted`（被另一个模型抢占）标为"已中断 + 继续"而不是错误。
- 消息列表只在"贴底"时跟随流式输出，用户上滑翻阅历史时不强拉，并给出"回到最新"按钮；
  气泡文本不可选中（长按复制），避免文本选择器抢走上下拖动。
- 图片附件：库内媒体只传 `media_id`（后端就地取预览图）；手机相册图压到长边 1280 后拷入
  `img_storage/chat/` 以 base64 内联发送；删除会话会一并清理这些本地图片。
- "问问AI"入口统一走 `features/chat/chat_entry.dart`。
- 画廊快速打标签浮层（`widgets/tag_drag_overlay.dart`）随媒体旋转方向旋转；浮层内几何与命中
  判定全在自身坐标系内完成（手指屏幕坐标经根节点 `globalToLocal` 换算），构建期只用
  [LayoutBuilder] 给出的换轴尺寸——直接读根节点 `size` 会触发 `hasSize` 断言。
- 相册页(immich)的 AI 标签筛选走 `widgets/immich_ai_tag_sheet.dart`；筛选栏只留入口与已选条件。

### 近期回顾 (`/chat/review`)

- 统计与抽样全在**后端**（booklet/essay 数据只在那里），端上只选角色/语气预设与时间范围，
  再消费 NDJSON：`stats` 事件（确定性统计，页面可展开核对）→ `delta` 逐字正文。
- 沿用对话设置的模型/上下文/温度/卸载超时；**思考链固定关闭**（一次性写作，思考只拖慢首字）。
- 生成结果**只存本机**（Hive `reviewHistory`），可回看与删除，不上传；载入历史不覆盖草稿以外的数据。
- 角色/语气预设有服务端权威（`<STATIC_DIR>/data/review_presets.json`）：读取时先用 Hive 镜像
  （离线可用）再异步对齐；编辑保存**整体推送**，成功后才刷新镜像，失败则两侧保持原样。
- 流式解析复用 `chat_api_service.dart` 的 `streamNdjsonEvents`，不要在校验层再抄一份。

### 数据安全约定

- 同步（`/API/user-data/sync/*`）是**整体替换**语义：必须先完整解析校验、再清空写入本地 Box，
  任何一条非法都必须直接抛出而不破坏既有数据（见 `essay_notifier_provider.dart` /
  `routine_service_provider.dart` 的 `syncData`）。
- 派生统计（标签计数、年度汇总）一律以本地实际数据重算，不信任持久化下来的计数。
- Riverpod 派生 provider 返回列表/对象的副本；Box 流里的实例是共享的，就地排序或洗牌会污染其它消费者。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，防止异常。除非明确要求，不引入破坏性修改。
