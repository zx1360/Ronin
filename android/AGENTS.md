# Torrid

- `lib/app/` 管主题和 GoRouter，`core/` 管共享设施，`features/` 按业务组织。`/others` 下用 `Navigator.push`。
- `appDatabaseProvider` 持有唯一业务库，简单设置走 `PrefsService`。改 Drift、Riverpod 或 DTO 生成输入时用 `dart run build_runner build`。SQLite 原生库由构建钩子校验，下载受阻时可给构建进程设置 `HTTPS_PROXY`。
- 随笔、积微先上传再拉增量，记录、删除标记和按主机隔离的游标同事务提交。隐藏标签子树默认隐藏并排除于 AI 回顾。时迹计时锚点仅存本机，启动时确认未结束的计时。
- `providers/network_config/` 是连接配置真源，`ApiClientManager` 跟随派生客户端。错误用 `ApiClient.mapError`。Dart 和原生网络共用 `res/raw/server.crt`。根 ProviderScope 关闭自动重试，读请求随 provider 释放可取消。
- `GalleryWriteBuffer` 同事务提交本地编辑和队列，确认后清理。在线相册写入走 `retryServerWrite`。标签树和视频复用 `tag_tree.dart`、`MediaVideoPlayer`，旋转在媒体视图内处理。
- 对话和回顾共用 NDJSON 解析。结束或失败时落历史，删会话时清附件，图库图片只传 `media_id`。回顾预设以服务端写入结果更新本地镜像。
