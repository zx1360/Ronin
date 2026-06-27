## 项目说明 (Torrid)

Flutter 目标平台仅为安卓移动端的应用，Ronin 三端架构的消费端。所有持久化数据通过 Monarch 后端 API 存取。

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
| 车削(工具) | `/others/lathe` | - |
| 个人 | `/profile` | 本地存储 |

### 技术栈

- 状态管理：Riverpod + riverpod_generator
- 路由：GoRouter
- 网络请求：Dio（自签证书兼容）
- 本地存储：Hive + SharedPreferences + sqflite
- 媒体播放：chewie, video_player, audioplayers, photo_view
- 代码生成：json_serializable + build_runner + hive_generator

### 与后端协同

- API 变更见 `../backend/references/api/`（`routes.json`）。
- 网络层：`lib/core/services/`、`lib/providers/api_client/`。
- 自签证书：`assets/cert/`，通过 `CertTrust` 加载。
- 画廊支持双向同步：`POST /API/gallery/push`。
- mDNS 自动发现：设置页点击"发现"可自动扫描局域网内的 Monarch 服务，发现的新地址会自动添加到配置列表。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，防止异常。除非明确要求，不引入破坏性修改。