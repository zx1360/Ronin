# 漫画数据

建表真源为 [comix.sql](comix.sql)，Monarch 与 `comix init` 共用。Python 登记并下载，Go 在 `comic_repo` 和 `comix_repo` 读书库及更新管理字段。

- `(site_id, site_comic_id)` 标识同站漫画，`title_normalized` 只用于跨站关联提示。章节 URL 全库唯一，章节按 `(comic_id, chapter_no)` 排序。
- 新图放在 `COMIC_STORAGE_ROOT/{comic_id}/{chapter_id}/{页码}.{扩展名}`，页码三位补齐。`rel_dir` 带 `comics/` 前缀，`config.storage_path` 映射到存储根。Android 的 `image_path` 由 `rel_dir` 与 `file_name` 拼接。
- `comic_images` 按 `sort_num` 排序，每章只保留最新任务行。`cover_image` 显式维护，空封面可从最早已下载章节的首图补齐。
- `site_code=legacy` 和名称目录继续可读，存储路径沿用库内记录，追更跳过 legacy。
