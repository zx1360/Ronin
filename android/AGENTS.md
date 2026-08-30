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
- 网络层：`lib/core/services/`、`lib/providers/api_client/`、`lib/providers/network_config/`。
- 服务器连接配置唯一真相源为 `providers/network_config/`（`NetworkConfigManager`，持久化于 SharedPreferences 的 `PC_HOST_LIST`/`PC_ACTIVE_INDEX`/`API_KEY`）；`providers/api_client/` 的 `ApiClientManager` 通过监听该状态派生 `ApiClient`，禁止再次直读 prefs 或手动双写地址/Key。
- 统一异常：`ApiClient` 提供 `ApiException` 错误映射与幂等 GET 自动重试；fetcher 系列统一走 `ApiClient.mapError`，UI 不应直接处理底层协议异常。
- 自签证书：`assets/cert/`，通过 `CertTrust` 加载（仅信任加载的自签证书，`withTrustedRoots=false`，与桌面端一致）。
- 画廊支持双向同步：`POST /API/gallery/push`（后端事务 + upsert 保证幂等）。
- mDNS 自动发现：设置页点击"发现"可自动扫描局域网内的 Monarch 服务，发现的新地址会自动添加到配置列表。
- 编辑参数 `edit_params`（图片裁切/视频剪辑）随 push 上传，由后端 `gallery execute` CLI 应用：
  - 图片：`type=image`，裁切坐标为**原始图片像素空间**（后端负责旋转后换算）；
  - 视频：`type=video`，起止时间一律为**秒**（`trim_start_sec`/`trim_end_sec`，0=到结尾）。
- **拖拽打标签**：gallery 主页底部"标签"按钮**点击**打开标签管理页（原行为），
  **向上拖动**激活 `widgets/tag_drag_overlay.dart` 浮层 —— 拖到标签行松手=添加/移除该标签、
  悬停父标签展开子级、接近面板边缘自动滚动、拖到右上角=取消。
- **视频播放**：画廊浏览的 `video_player_widget.dart` 为**自实现播放器**
  （直接基于 `video_player`，不依赖 chewie）：播放/暂停、后退/快进 10 秒、
  **可拖动进度条**（松手按实际松手位置精确 seek，修复了 chewie 内置进度条
  "快速拖动落点偏短（只能到 ~80%）"的问题）、时间显示、3 秒无操作自动隐藏。
- **视频剪辑页**（`video_trimmer_page.dart`）为**纯图片帧预览，无视频播放器**：
  时长/分辨率来自后端 `GET /API/gallery/:id/video-info`；拖动起始/结束滑块时
  经 `GET /API/gallery/:id/frame?sec=` 取该位置单帧 JPEG 实时预览帧画面
  （节流约 8 次/秒 + 序号防乱序）；保存参数由后端 CLI 应用。

### 硬性要求

- 参考 `../backend/references/` 契约文件。UI 简约美观，交互友好。
- 考虑边界情况，防止异常。除非明确要求，不引入破坏性修改。