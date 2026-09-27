# 漫画数据表（comix_*）

> 表与三个视图由内置的 `gizmos/comix`（Python）建表与维护，Monarch 只读写。
> 与其余表共用同一个 SQLite 文件；建表用 `python -m comix.cli init`。
>
> `/API/comic/*`（Android 端）走三个**视图**，`/API/comix/*`（ops 端）走底层表。
> 视图在 SQLite 里是只读的，**没有** INSTEAD OF 触发器：Go 侧的写操作
> （公开/已读/删除）直接作用于 `comix_comic`，因此 `comix_comic.id` 保持 INTEGER，
> Go 侧用 `CAST(id AS TEXT) = ?` 与视图暴露的 TEXT id 对齐。

## comix_comic

| 列 | 类型 |
| -- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT |
| title | TEXT NOT NULL |
| title_normalized | TEXT NOT NULL DEFAULT '' |
| site_id | INTEGER NOT NULL |
| site_comic_id | TEXT NOT NULL DEFAULT '' |
| detail_url | TEXT NOT NULL DEFAULT '' |
| author / status / cover_url | TEXT NOT NULL DEFAULT '' |
| total_chapters / max_chapter_no | INTEGER NOT NULL DEFAULT 0 |
| rel_dir | TEXT NOT NULL DEFAULT '' |
| is_public | INTEGER NOT NULL DEFAULT 1 |
| readed | INTEGER NOT NULL DEFAULT 0 |
| cover_image | TEXT NOT NULL DEFAULT '' |
| created_at / updated_at | TEXT NOT NULL |

`cover_image` 由爬虫维护；**Monarch 侧不再提供"替换封面"能力**。

## comix_site / comix_chapter / comix_image / comix_download_task / comix_comic_alias

见 `gizmos/comix/comix/db.py` 的 schema 常量（该文件是这几个表的真相源）。

## 桥接视图

| 视图 | 投影 |
| ---- | ---- |
| `comix_comic_books` | `id`(TEXT)、`title`、`cover_image`、`is_public`、`readed` |
| `comix_comic_chapters` | `id`(TEXT)、`comic_id`(TEXT)、`dir_name`、`chapter_index` |
| `comix_comic_images` | `id`(TEXT)、`chapter_id`(TEXT)、`image_path`、`sort_num`、`width`、`height` |

`dir_name` = `substr('000'||chapter_no, -3) || '_' || title`，与爬虫的目录命名一致。
