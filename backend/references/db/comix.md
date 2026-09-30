# 漫画数据表

> 由 comix 项目（`gizmos/comix/`）建表与维护，Monarch 只读写。
> 建表真源：`references/db/sqlite.sql`。原 PG 的 `comix` schema 与三个桥接视图
> （`comic_books` / `comic_chapters` / `comic_images`）已取消：SQLite 无 schema，
> 表名统一加 `comic_` 前缀；视图投影（`id::text` / `dir_name` / `image_path`）
> 改为 SQL 表达式与 Go 侧类型转换（comic_repo），不再建视图与 INSTEAD OF 触发器。

## comic_sites
| 列 | 类型 |
| -- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT |
| code | TEXT NOT NULL UNIQUE（manhuayu/morui/nicemh/xmanhua/legacy） |
| name | TEXT NOT NULL |
| base_url | TEXT NOT NULL DEFAULT '' |
| enabled | INTEGER NOT NULL DEFAULT 1 |
| created_at | TEXT NOT NULL DEFAULT 本地时间文本 |

## comics
| 列 | 类型 |
| -- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT（存储目录 `comics/{id}`） |
| title | TEXT NOT NULL |
| title_normalized | TEXT NOT NULL DEFAULT '' |
| site_id | INTEGER NOT NULL FK→comic_sites |
| site_comic_id | TEXT NOT NULL DEFAULT ''，与 site_id 联合唯一 |
| detail_url | TEXT NOT NULL |
| author / status / cover_url | TEXT NOT NULL DEFAULT '' |
| total_chapters / max_chapter_no | INTEGER NOT NULL DEFAULT 0 |
| rel_dir | TEXT NOT NULL DEFAULT ''（`comics/{id}`） |
| is_public | INTEGER NOT NULL DEFAULT 1 |
| readed | INTEGER NOT NULL DEFAULT 0 |
| cover_image | TEXT NOT NULL DEFAULT ''（显式维护，取第一章第一图） |
| created_at / updated_at | TEXT NOT NULL DEFAULT 本地时间文本 |

## comic_chapters
| 列 | 类型 |
| -- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT |
| comic_id | INTEGER NOT NULL FK→comics ON DELETE CASCADE |
| site_id | INTEGER NOT NULL FK→comic_sites |
| chapter_no | INTEGER NOT NULL（站内顺序号，1 起） |
| title | TEXT NOT NULL DEFAULT '' |
| url | TEXT NOT NULL UNIQUE（跨站去重键） |
| page_count | INTEGER NOT NULL DEFAULT 0 |
| rel_dir | TEXT NOT NULL DEFAULT ''（`comics/{comic_id}/{id}`） |
| status | TEXT NOT NULL DEFAULT 'pending'（pending/done/failed） |
| error | TEXT NOT NULL DEFAULT '' |
| created_at / updated_at | TEXT NOT NULL DEFAULT 本地时间文本 |

唯一约束：`(comic_id, chapter_no)`、`url`。

## comic_images
| 列 | 类型 |
| -- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT |
| chapter_id | INTEGER NOT NULL FK→comic_chapters ON DELETE CASCADE |
| sort_num | INTEGER NOT NULL |
| file_name | TEXT NOT NULL（001.jpg / 005.webp） |
| width / height | INTEGER NOT NULL DEFAULT 0 |

唯一约束：`(chapter_id, sort_num)`。Android 端的 `image_path` = `rel_dir || '/' || file_name`。

## comic_download_tasks
| 列 | 类型 |
| -- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT |
| comic_id / chapter_id | INTEGER NOT NULL FK（CASCADE） |
| status | TEXT NOT NULL DEFAULT 'queued' |
| image_count | INTEGER NOT NULL DEFAULT 0 |
| error | TEXT NOT NULL DEFAULT '' |
| started_at / finished_at | TEXT |

唯一约束：`(chapter_id)`（每章一条最新任务）。

## comic_aliases
| 列 | 类型 |
| -- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT |
| comic_id | INTEGER NOT NULL FK→comics ON DELETE CASCADE |
| name | TEXT NOT NULL，与 comic_id 联合唯一 |
