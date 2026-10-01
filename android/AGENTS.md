# Torrid

仅面向 Android 的 Flutter 应用。架构见 `../docs/architecture/torrid.md`。
`lib/app/` 管路由/主题，`core/` 管通用设施，`features/` 按业务组织；顶层用 GoRouter，`/others` 下的功能页用 `Navigator.push`。

## 开发与存储

- Riverpod + generator；DTO/Hive adapter 使用 build_runner 生成，不手改 `*.g.dart`。改生成源后运行 `dart run build_runner build --delete-conflicting-outputs`。
- 验收：`flutter analyze` 零告警、`flutter test`。
- 新增 Hive 类型前查 `../开发备忘.md` 的 typeId 占用表；发布后的 typeId/字段编号不得复用。
- 同步是整体替换：先完整解析校验，再清空写入 Box；非法数据不得破坏已有内容。统计从实际数据重算，派生 provider 不得原地排序/修改共享 Box 对象。
- 随笔草稿与图片仅存本机独立空间；编辑正式随笔时保留原文至保存成功。“隐藏”标签子树默认不展示，AI 回顾始终排除。

## 网络与媒体

- 连接配置唯一真源是 `providers/network_config/`，`ApiClientManager` 监听派生客户端，页面不手动推送。
- 网络错误统一走 `ApiClient.mapError`；证书由 `CertTrust` 加载，mDNS 发现 HTTPS 端口。
- Gallery 的标签/标注权威在服务端，`gallery.db` 仅缓存。画廊走 `GalleryWriteBuffer` 乐观写入/重试/回滚，在线相册走 `retryServerWrite`；保留两种写入语义。
- 单条标注经 `MediaAssetList` 更新内存与排队；页面不可自行拼 `updateMediaAsset + queuePatch`。清本机缓存走 `GalleryLocalDataController`。
- 标签树复用 `models/tag_tree.dart`；AI 标签与人工标签隔离。AI 503 时入口/结果块降级，错误文案走 `aiFriendlyError`，模型与能力名来自服务端。
- 全应用竖屏，媒体旋转由页面处理；标签浮层的命中用 `globalToLocal`，构建尺寸用 `LayoutBuilder`，不可在布局前读取 RenderBox.size。

## 对话与回顾

- 共用 `chat_api_service.dart` 的 NDJSON 解析；`notice` 提示，`aborted` 显示可继续的中断状态。流式消息只在贴底时自动滚动，一轮结束/失败才落库。
- 会话与回顾历史仅存本机；手机图片压到长边 1280，删会话须清附件，库内媒体仅传 `media_id`。入口复用 `chat_entry.dart`。
- 回顾统计/抽样在后端，端上消费 `stats → delta`，固定关闭思考；预设以服务端为准，本地镜像支持离线，整体推送成功后才更新镜像。
