# Torrid

仅面向 Android 的 Flutter 应用。架构见 `../docs/architecture/torrid.md`。
`lib/app/` 管路由/主题，`core/` 管通用设施，`features/` 按业务组织；顶层用 GoRouter，`/others` 下的功能页用 `Navigator.push`。

## 开发与存储

- Dart 3.12 / Flutter 3.44，Drift、Riverpod 与 DTO 统一使用 `dart run build_runner build` 生成。不手改 `*.g.dart`。
- SQLite 随应用打包，由 `sqlite3` 的构建钩子获取并校验。GitHub Release 需要代理时，给构建进程设置 `HTTPS_PROXY`。
- 验收：`flutter analyze` 零告警、`flutter test`。
- `appDatabaseProvider` 持有唯一业务库；表定义、查询与写入按业务组织。简单设置经 `PrefsService` 使用 SharedPreferencesWithCache。
- 随笔/打卡先上传再拉取增量，按 `updated_at` 合并；随笔关联标签单独用 `labels_updated_at`。每批数据、tombstone 和按主机隔离的游标同事务提交。统计从数据派生。
- 随笔草稿与图片仅存本机独立空间；编辑正式随笔时保留原文至保存成功。“隐藏”标签子树默认不展示，AI 回顾始终排除。

## 网络与媒体

- 连接配置唯一真源是 `providers/network_config/`，`ApiClientManager` 监听派生客户端，页面不手动推送。
- 网络错误统一走 `ApiClient.mapError`；证书由 `CertTrust` 加载，mDNS 发现 HTTPS 端口。
- Gallery 工作副本与操作队列绑定服务端图库 ID，预览文件也按图库隔离。`GalleryWriteBuffer` 同事务提交本地编辑与操作，服务端确认后清理。在线相册写入走 `retryServerWrite`。
- 标注经 `MediaAssetList` 提交操作，查询流更新界面。清本机缓存走 `GalleryLocalDataController`。
- 标签树复用 `models/tag_tree.dart`；AI 标签与人工标签隔离。AI 503 时入口/结果块降级，错误文案走 `aiFriendlyError`，模型与能力名来自服务端。
- 全应用竖屏，媒体旋转由页面处理；标签浮层的命中用 `globalToLocal`，构建尺寸用 `LayoutBuilder`，不可在布局前读取 RenderBox.size。

## 对话与回顾

- 共用 `chat_api_service.dart` 的 NDJSON 解析；`notice` 提示，`aborted` 显示可继续的中断状态。流式消息只在贴底时自动滚动，一轮结束/失败才落库。
- 会话与回顾历史仅存本机；手机图片压到长边 1280，删会话须清附件，库内媒体仅传 `media_id`。入口复用 `chat_entry.dart`。
- 回顾统计/抽样在后端，端上消费 `stats → delta`，固定关闭思考；预设以服务端为准，本地镜像支持离线，整体推送成功后才更新镜像。
