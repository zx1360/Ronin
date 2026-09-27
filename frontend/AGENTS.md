## 项目说明 (前端)

Flutter 应用，**仅面向 Android 移动端**（单平台，代码里不按平台分支），Ronin 三端架构的消费端。
所有持久化数据通过 Monarch 后端 API 存取。

### 核心功能与后端依赖

| 功能页 | 路由 | 后端 API |
|--------|------|----------|
| 启动屏 | `/splash` | - |
| 首页 | `/home` | - |
| 积微(打卡) | `/booklet` | `user-data` sync `/API/user-data/*` |
| 随笔(笔记) | `/essay` | `user-data` sync `/API/user-data/*` |
| 对话(本地 AI) + 近期回顾 | `/chat`（二级页 `/chat/settings`） | `POST /API/ai/chat`（NDJSON 流）、`/API/ai/review*` |
| 阅读(RSS) | `/news` | 独立第三方接口 |
| 漫画 | 由 `/others` 页 `Navigator.push` 打开 | `/API/comic/*` |
| 画廊 / 相册(immich) / 智能相册 | 由 `/others` 页 `Navigator.push` 打开 | `/API/gallery/*`、`/API/ai/*` |
| 个人 | `/profile` | 本地存储 |

> 只有上表列出的顶层路由是 GoRouter 路由；`/others` 下的二级页用 `Navigator.push` 进入.

### 技术栈

- 状态管理：Riverpod + riverpod_generator；路由：GoRouter；网络：Dio（自签证书兼容）
- 媒体播放：chewie + video_player + photo_view；本地存储：Hive + SharedPreferences + sqflite
- 代码生成：json_serializable + build_runner + hive_generator
- 静态检查：`flutter analyze` 必须零告警；`analysis_options.yaml` 已排除 `*.g.dart`
- 契约由生成：端点与模型来自 `lib/core/api/generated/api_contract.dart`（**勿手改**）；
  改了后端路由或模型就跑 `backend/references/scripts/generate_refs.ps1`

### 平台

只出 Android 一个平台：仓库里没有 `windows/` 等其它平台目录，依赖里也没有桌面端专有插件。
因此**代码里不存在平台分支**，凡是平台相关的地方都直接写 Android 的做法：

| 关注点 | 取值 |
|--------|------|
| 屏幕方向 | `main.dart` 锁定竖屏；画廊内媒体旋转由页面自身处理（`quarterTurns`） |
| 用户文件根目录 | `getExternalStorageDirectory()`（应用外部私有目录，`IoService`）——`img_storage/`、`comics/`、`preferences/` 与 gallery 媒体缓存树都在它下面 |
| 缓存目录 | `getTemporaryDirectory()` |
| 轻量键值 | `SharedPreferences`（`PrefsService`） |
| Hive 数据 | `Hive.initFlutter()`（应用私有目录） |
| gallery 本地库 | sqflite 默认库目录 |
| 相册导出 | `/storage/emulated/0/Pictures/torrid` + `MANAGE_EXTERNAL_STORAGE` 权限申请 |
| 图片选择 | image_picker 会真正执行 `maxWidth`/`maxHeight`/`imageQuality`，端上不做二次压缩 |
| 媒体分页 | 一页 60 条（`core/constants/paging.dart` 的 `mediaPageSize`，与服务端同一分页口径） |

布局同样只按手机一档写：网格列数、抽屉宽度、弹层与预览的最大宽度都在各页面直接给出固定值，
**不引入断点或宽屏分支**。

### 与后端协同

- API 变更见 `../backend/references/api/`（`routes.json`、`contract.json`）。
- **端点一律引用 `ApiPath`**（`lib/core/api/generated/api_contract.dart` 的生成常量与
  `xxxPath(...)` 辅助函数），不要在业务代码里手写 `/API/...` 字符串：路由改名时编译期就会报错。
  媒体文件流统一用 `ApiPath.galleryIdTypePath(id, 'thumb'|'preview'|'file')`。
- 网络层：`lib/core/services/network/`、`lib/providers/api_client/`、`lib/providers/network_config/`。
- 服务器连接配置唯一真相源为 `providers/network_config/`（`NetworkConfigManager`，持久化 `PC_HOST_LIST`/`PC_ACTIVE_INDEX`/`API_KEY`）；`ApiClientManager` 监听该状态派生 `ApiClient`.
- 统一异常：`ApiClient` 提供 `ApiException` 映射与幂等 GET 自动重试；fetcher 统一走 `ApiClient.mapError`，UI 不处理底层协议异常。
- 自签证书：`assets/cert/`，经 `CertTrust` 加载（`withTrustedRoots=false`）。
  ⚠️ `assets/` 未纳入版本控制：全新检出需先补回该证书，否则 `CertTrust.init()` 会失败。
- **画廊/相册数据权威**：服务端权威 + 本地缓存 + 操作式写入。标签、标签关系、媒体标注（is_deleted/message/group_id/edit_params）全部经 `/API/gallery/*` 写服务端；本地 `gallery.db` 只是缓存（下载批次镜像、写操作回写），跨端不会互相覆盖。
  - 写入口：`services/gallery_api_service.dart`（类型化操作接口）。
  - 交互流畅性：`services/gallery_write_buffer.dart` + `providers/write_buffer_provider.dart` 提供「本地立即生效 → 后台合并推送 → 退避重试 → 最终失败回滚」，批量/低频操作走 `retryServerWrite`。
  - 批次处理游标：设置页「标记已处理」= 服务端 `sync_count + 1`（PATCH `/media` 的 `mark_processed`）+ 清理本地已处理记录与文件。
- mDNS 自动发现：`/profile` → 网络设置页点击"发现"可扫描局域网内的 Monarch 服务，发现的新地址会自动添加到配置列表。

### 用户数据同步（essay / booklet）

**两端可写**，因此同步是**按 `updated_at` 的逐行增量合并**，不再整体替换：

- 拉取：逐行比较，仅当服务端行的 `updated_at` 严格更新才覆盖本地；本地缺失则插入；
  带 `deleted_at` 的行按删除处理；**服务端没下发的行不在本地删除**。
- 推送：上传全部本地行（含墓碑），由服务端按同一规则合并，返回 `applied`/`skipped`。
- 删除：本地删除写 `deleted_at` 并推进 `updated_at`，使删除能传播到另一端。
- 校验仍然是「先完整解析校验、再写入」：任何一条数据非法都必须直接抛出而不破坏既有数据。
- Hive 模型新增字段**只能追加到字段列表末尾**（Hive 按字段下标序列化，插入或重排会毁掉既有本地库）。

### 近期回顾（对话页）

统计由后端算出（`/API/ai/review` 的 `stats` 与 `facts`），本地模型只负责写叙述；
结果按「统计指纹 + 预设 + 模型」在后端缓存，语气与角色是可编辑预设（增删改都走后端）。
模型不可用时接口仍返回统计并给出 `notice`，页面必须如实展示，不得留白。

### 对话页 (本地 AI)

- 会话与消息只存本机（Hive `chatConversations`，模型见 `features/chat/models/`）：一次会话整体读写，
  流式增量只更新内存，一轮结束（或失败）才落库。
- 请求经 `features/chat/services/chat_api_service.dart`（`POST /API/ai/chat`，逐行解析 NDJSON）；
  对话设置（模型/上下文/思考/温度/自定义卸载超时）存本地键值，随每次请求下发。
  模型候选与当前执行者取自 `/API/ai/capabilities`，**不在端上硬编码模型名**。
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

### 数据安全约定

- 派生统计（标签计数、年度汇总）一律以本地实际数据重算，不信任持久化下来的计数：`refreshLabel` 会把计数为 0 的标签写回，`deleteZeroLabels` 只删除确实没有任何随笔引用的标签；墓碑行不参与统计。
- Riverpod 派生 provider 返回列表/对象的副本；Box 流里的实例是共享的，就地排序或洗牌会污染其它消费者。

### 复用约定

- 标签树一律用 `features/others/shared/tag_tree.dart` 的 `TagTreeIndex` 建索引；根级取
  `displayRoots`（真根 + 父级缺失的孤儿），**不要把孤儿丢掉**——否则父标签被删后子标签会从界面上消失。
- 漫画阅读页的图像拼接与选区裁剪在 `comic/services/reader_image_service.dart`（纯函数，有单测）。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，防止异常。除非明确要求，不引入破坏性修改。
