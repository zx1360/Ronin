## 项目说明 (Torrid)

Flutter 开发的安卓移动端应用，Ronin 三端架构的消费端。

### 应用定位

个人随身数字伴侣，集成漫画阅读、媒体浏览、RSS、打卡、笔记等功能。所有持久化数据通过 Monarch 后端 API 存取和同步。

### 核心功能与后端依赖

| 功能页 | 路由 | 说明 | 后端 API |
|--------|------|------|----------|
| 启动屏 | `/splash` | 启动过渡，连接校验 | - |
| 首页 | `/home` | 桌面，支持自定义背景 | - |
| 积微 | `/booklet` | 习惯打卡 | `user-data` sync |
| 随笔 | `/essay` | Markdown 笔记 | `user-data` sync |
| 图书馆 | `/library` | 待办事项 | 预留 |
| 阅读 | `/news` | RSS 新闻聚合 | 独立 |
| 其他-漫画 | `/others/comic` | 漫画在线/离线阅读 | `/API/comic/*` |
| 其他-画廊 | `/others/gallery` | 媒体浏览、标签筛选、图片/视频播放 | `/API/gallery/*` |
| 其他-车削 | `/others/lathe` | 辅助工具 | - |
| 个人 | `/profile` | 背景/座右铭/偏好设置 | 本地存储 |

### 技术栈

| 领域 | 依赖 |
|------|------|
| 状态管理 | Riverpod + riverpod_generator |
| 路由 | GoRouter |
| 网络请求 | Dio (自签证书兼容) |
| 本地存储 | Hive (键值) + SharedPreferences (配置) + sqflite (结构化) |
| 媒体播放 | chewie (视频), video_player, audioplayers (音频), photo_view (图片) |
| 推送 | flutter_local_notifications + 前台服务保活 |
| 代码生成 | json_serializable + build_runner + hive_generator |

### 与后端协同

- Monarch API 变更会在 `../backend/references/api/` 更新。
- 网络层 (`lib/core/services/` 和 `lib/providers/api_client/`) 需对照 `swagger.json` 和 `routes.json` 适配。
- 自签证书：`assets/cert/` 内置服务端证书，启动时通过 `CertTrust` 加载。
- 画廊支持双向同步：移动端可通过 `POST /API/gallery/push` 将标签/媒体关联推回后端。

### 硬性要求（AI 辅助开发备忘）

- 参考 `../backend/references/` 目录下的契约文件。
- UI 简约美观，交互友好。
- 考虑边界情况，防止异常。
- 除非明确要求，不引入破坏性修改。
- 注意代码可维护性。

### 关联项目

- 后端: `../backend/` (Monarch)
- 桌面运维端: `../desktop/` (Northstar)