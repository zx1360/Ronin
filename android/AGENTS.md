# Torrid

- 仅 Android。`lib/app/` 管主题和 GoRouter，`core/` 管共享设施，`features/` 按业务组织。`/others` 下用 `Navigator.push`。
- `appDatabaseProvider` 持有唯一业务库，简单设置走 `PrefsService`。Drift、Riverpod 和 DTO 由 `dart run build_runner build` 生成。SQLite 由构建钩子获取并校验，必要时给构建进程设置 `HTTPS_PROXY`。
- 随笔和积微先上传再拉增量。记录、删除标记和按主机隔离的游标同事务提交。随笔标签版本独立，草稿与图片存本机。隐藏标签子树默认隐藏且排除于 AI 回顾。
- 时迹按记录版本合并并校验备份修订号。计时锚点仅用于本机，启动时确认未结束的计时。
- 网络配置真源是 `providers/network_config/`，`ApiClientManager` 跟随派生客户端。错误用 `ApiClient.mapError`，Dart 和原生网络共用 `res/raw/server.crt`。根 ProviderScope 关闭自动重试，读请求随 provider 释放可取消。
- Gallery 的工作副本、预览和操作队列按图库 ID 隔离。用 `GalleryWriteBuffer` 同事务提交编辑和队列，确认后清理。在线相册写入走 `retryServerWrite`。标签树、视频分别复用 `tag_tree.dart`、`MediaVideoPlayer`。旋转在媒体视图内处理。
- 对话和回顾共用 NDJSON 解析，处理 `notice`、`aborted` 和 503。历史仅存本机，结束或失败时落库，删会话清附件。图库图片只传 `media_id`。回顾预设整体提交成功后更新本地镜像。
- 验收用 `pwsh -File verify.ps1 -Scope android`。
