## 项目说明 (Torrid)

Flutter 目标平台仅为安卓移动端的应用，Ronin 三端架构的消费端。所有持久化数据通过 Monarch 后端 API 存取。

### 核心功能与后端依赖

| 功能页 | 路由 | 后端 API |
|--------|------|----------|
| 启动屏 | `/splash` | - |
| 首页 | `/home` | - |
| 积微(打卡) | `/booklet` | `user-data` sync `/API/user-data/*` |
| 随笔(笔记) | `/essay` | `user-data` sync `/API/user-data/*` |
| 图书馆(待办) | `/library` | - |
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

### 与后端协同

- API 变更见 `../backend/references/api/`（`routes.json`）。
- 网络层：`lib/core/services/network/`、`lib/providers/api_client/`、`lib/providers/network_config/`。
- 服务器连接配置唯一真相源为 `providers/network_config/`（`NetworkConfigManager`，持久化于 SharedPreferences 的 `PC_HOST_LIST`/`PC_ACTIVE_INDEX`/`API_KEY`）；`providers/api_client/` 的 `ApiClientManager` 通过监听该状态派生 `ApiClient`.
- 统一异常：`ApiClient` 提供 `ApiException` 错误映射与幂等 GET 自动重试；fetcher 系列统一走 `ApiClient.mapError`，UI 不应直接处理底层协议异常。
- 自签证书：`assets/cert/`，通过 `CertTrust` 加载（仅信任加载的自签证书，`withTrustedRoots=false`，与桌面端一致）。
- **画廊/相册数据权威**：服务端权威 + 本地缓存 + 操作式写入。标签、标签关系、媒体标注（is_deleted/message/group_id/edit_params）全部经 `/API/gallery/*` 写服务端；本地 `gallery.db` 只是缓存（下载批次镜像、写操作回写），跨端不会互相覆盖。
  - 写入口：`services/gallery_api_service.dart`（类型化操作接口）。
  - 交互流畅性：`services/gallery_write_buffer.dart` + `providers/write_buffer_provider.dart` 提供「本地立即生效 → 后台合并推送 → 退避重试 → 最终失败回滚」，批量/低频操作走 `retryServerWrite`。
  - 批次处理游标：设置页「标记已处理」= 服务端 `sync_count + 1`（PATCH `/media` 的 `mark_processed`）+ 清理本地已处理记录与文件。
- mDNS 自动发现：`/profile` → 网络设置页点击“发现”可扫描局域网内的 Monarch 服务，发现的新地址会自动添加到配置列表。

### 数据安全约定

- 同步（`/API/user-data/sync/*`）是**整体替换**语义：必须先完整解析校验、再清空写入本地 Box，任何一条数据非法都必须直接抛出而不破坏既有数据（参见 `essay_notifier_provider.dart` / `routine_service_provider.dart` 的 `syncData`）。
- 派生统计（标签计数、年度汇总）一律以本地实际数据重算，不信任持久化下来的计数：`refreshLabel` 会把计数为 0 的标签写回，`deleteZeroLabels` 只删除确实没有任何随笔引用的标签。
- Riverpod 派生 provider 返回列表/对象的副本；Box 流里的实例是共享的，就地排序或洗牌会污染其它消费者。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，防止异常。除非明确要求，不引入破坏性修改。
