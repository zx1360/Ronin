# 用户数据表（随笔与打卡）

> 时间列统一 TEXT；日期列 `YYYY-MM-DD`；数组列 JSON 文本；`updated_at` 由 Go 侧显式写入。
>
> **两端可写**：`POST /API/user-data/backup/:module` 是**按行增量合并**，不是全量替换——
> 逐行按 `updated_at` 后写胜，载荷中缺失的行保持不动，删除用 `deleted_at` 墓碑表达
> （墓碑同样受 `updated_at` 规则约束，更晚的非墓碑写入可复活该行）。

| 表 | 合并键 |
| -- | ------ |
| `user_data_essay_articles` | `id` |
| `user_data_essay_labels` | `id` |
| `user_data_essay_year_summaries` | `year` |
| `user_data_booklet_styles` | `id` |
| `user_data_booklet_records` | `(style_id, date)`（业务主键，采用载荷中的 `id`） |

`GET /API/user-data/sync/:module` 会返回**含墓碑的全部行**，客户端据此删除本地副本。

## user_data_essay_articles

| 列         | 类型                                    |
| ---------- | --------------------------------------- |
| id         | TEXT PRIMARY KEY (UUID)                 |
| date       | TEXT NOT NULL                           |
| word_count | INTEGER NOT NULL DEFAULT 0              |
| content    | TEXT NOT NULL DEFAULT ''                |
| imgs       | TEXT NOT NULL DEFAULT '[]'（JSON 数组，图片文件名） |
| labels     | TEXT NOT NULL DEFAULT '[]'（JSON 数组，标签 UUID） |
| messages   | TEXT NOT NULL DEFAULT '[]'（JSON）      |
| mood       | TEXT                                    |
| deleted_at | TEXT（墓碑；NULL = 有效）                |
| created_at | TEXT NOT NULL                           |
| updated_at | TEXT NOT NULL                           |

## user_data_essay_labels

| 列          | 类型                       |
| ----------- | -------------------------- |
| id          | TEXT PRIMARY KEY (UUID)    |
| name        | TEXT NOT NULL              |
| essay_count | INTEGER NOT NULL DEFAULT 0 |
| deleted_at  | TEXT                       |
| created_at  | TEXT NOT NULL              |
| updated_at  | TEXT NOT NULL              |

## user_data_essay_year_summaries

| 列              | 类型                        |
| --------------- | --------------------------- |
| year            | INTEGER PRIMARY KEY         |
| essay_count     | INTEGER NOT NULL DEFAULT 0  |
| word_count      | INTEGER NOT NULL DEFAULT 0  |
| month_summaries | TEXT NOT NULL DEFAULT '[]'  |
| deleted_at      | TEXT                        |
| updated_at      | TEXT NOT NULL               |

## user_data_booklet_styles

| 列                   | 类型                        |
| -------------------- | --------------------------- |
| id                   | TEXT PRIMARY KEY (UUID)     |
| start_date           | TEXT NOT NULL（YYYY-MM-DD） |
| valid_check_in       | INTEGER NOT NULL DEFAULT 0  |
| fully_done           | INTEGER NOT NULL DEFAULT 0  |
| longest_streak       | INTEGER NOT NULL DEFAULT 0  |
| longest_fully_streak | INTEGER NOT NULL DEFAULT 0  |
| tasks                | TEXT NOT NULL DEFAULT '[]'  |
| deleted_at           | TEXT                        |
| created_at           | TEXT NOT NULL               |
| updated_at           | TEXT NOT NULL               |

## user_data_booklet_records

| 列              | 类型                                        |
| --------------- | ------------------------------------------- |
| id              | TEXT PRIMARY KEY (UUID)                     |
| style_id        | TEXT NOT NULL FK→user_data_booklet_styles ON DELETE CASCADE |
| date            | TEXT NOT NULL（YYYY-MM-DD）                 |
| message         | TEXT NOT NULL DEFAULT ''                    |
| task_completion | TEXT NOT NULL DEFAULT '{}'                  |
| mood            | TEXT                                        |
| deleted_at      | TEXT                                        |
| created_at      | TEXT NOT NULL                               |
| updated_at      | TEXT NOT NULL                               |

- 唯一约束 `(style_id, date)`：同一天同项目组只有一条；墓碑保留在同一行上，
  客户端重建时按此冲突键覆盖即可复活。
