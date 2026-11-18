# 画廊数据

建表真源为 [sqlite.sql](sqlite.sql)，跨端编辑由 [Gallery CLI](../../gizmos/cmd/gallery/) 消费。

- `media_assets.hash` 是原件 SHA-256。`group_id` 指向主文件，删主文件时置空。批量同步显式推进 `sync_count`，用 `gallery_processed_requests` 去重，已有库可读 `last_processed_request`。
- `gallery execute` 应用未删除媒体的 `edit_params`，成功后清空。无操作编辑只清参数。
- 图片用 `type=image`、`rotation`、`crop_left/top/right/bottom`。裁切坐标属于 EXIF 校正后、用户旋转前的原图。旋转是逆时针 90° 的倍数。
- 视频用 `type=video`、`trim_start_sec`、`trim_end_sec`、`duration`，单位秒。结束秒数非正时剪到结尾，仍支持从 `trim_start_frame/trim_end_frame/fps` 换算。
- Go 校验同级名称和父子环并维护 `full_path`，删除标签级联清理子孙及关联。离线新建重试复用固定标签 ID。
- 含子孙标签的筛选先展开 ID 再查媒体，避免逐媒体执行递归查询。
