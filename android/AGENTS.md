## 项目说明 (Torrid)

Flutter 目标平台仅为安卓移动端的应用，Ronin 三端架构的消费端。所有持久化数据通过 Monarch 后端 API 存取.

### 核心功能与后端依赖

| 功能页 | 路由 | 后端 API |
|--------|------|----------|
| 启动屏 | `/splash` | - |
| 首页 | `/home` | - |
| 积微(打卡) | `/booklet` | `user-data` sync |
| 随笔(笔记) | `/essay` | `user-data` sync |
| 图书馆(待办) | `/library` | 预留 |
| 阅读(RSS) | `/news` | 独立 |
| 漫画 | `/others/comic` | `/API/comic/*` |
| 画廊 | `/others/gallery` | `/API/gallery/*` |
| 相册(immich) | `/others/immich` | `/API/gallery/*`（在线管理） |
| 个人 | `/profile` | 本地存储 |

### 技术栈

- 状态管理：Riverpod + riverpod_generator
- 路由：GoRouter
- 网络请求：Dio（自签证书兼容）
- 本地存储：Hive + SharedPreferences + sqflite
- 媒体播放：chewie, video_player, audioplayers, photo_view
- 代码生成：json_serializable + build_runner + hive_generator
- 验收测试：`flutter test`（`test/` 下为关键纯逻辑用例，改动相关逻辑后请一并运行）

### 与后端协同

- API 变更见 `../backend/references/api/`（`routes.json`）.
- 网络层：`lib/core/services/`、`lib/providers/api_client/`、`lib/providers/network_config/`.
- 服务器连接配置唯一真相源为 `providers/network_config/`（`NetworkConfigManager`，持久化于 SharedPreferences 的 `PC_HOST_LIST`/`PC_ACTIVE_INDEX`/`API_KEY`）；`providers/api_client/` 的 `ApiClientManager` 通过监听该状态派生 `ApiClient`，禁止再次直读 prefs 或手动双写地址/Key.
- 统一异常：`ApiClient` 提供 `ApiException` 错误映射与幂等 GET 自动重试；fetcher 系列统一走 `ApiClient.mapError`，UI 不应直接处理底层协议异常.
- 自签证书：`assets/cert/`，通过 `CertTrust` 加载（仅信任加载的自签证书，`withTrustedRoots=false`，与桌面端一致）.
- **画廊/相册数据权威**：服务端权威 + 本地缓存 + 操作式写入。标签、标签关系、媒体标注（is_deleted/message/group_id/edit_params）全部经 `/API/gallery/*` 写服务端；本地 `gallery.db` 只是缓存（下载批次镜像、写操作回写），跨端（含 Immich）不会互相覆盖。
  - 写入口：`services/gallery_api_service.dart`（类型化操作接口）。
  - 交互流畅性：`services/gallery_write_buffer.dart` + `providers/write_buffer_provider.dart` 提供「本地立即生效 → 后台合并推送 → 退避重试 → 最终失败回滚」，批量/低频操作走 `retryServerWrite`。
  - 批次处理游标：设置页「标记已处理」= 服务端 `sync_count + 1`（PATCH `/media` 的 `mark_processed`）+ 清理本地已处理记录与文件。
- mDNS 自动发现：设置页点击"发现"可自动扫描局域网内的 Monarch 服务，发现的新地址会自动添加到配置列表.

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，防止异常。除非明确要求，不引入破坏性修改。