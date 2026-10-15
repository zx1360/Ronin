# 用户数据表

> 建表真源：`references/db/sqlite.sql`。原 PG 的 `TEXT[]` / `JSONB` 列统一存 JSON 文本。

## essay_articles

| 列         | 类型                                                      |
| ---------- | --------------------------------------------------------- |
| id         | TEXT PRIMARY KEY (UUID)                                   |
| date       | TEXT NOT NULL（本地时间文本）                              |
| word_count | INTEGER NOT NULL DEFAULT 0                                |
| content    | TEXT NOT NULL DEFAULT ''                                  |
| title      | TEXT NOT NULL DEFAULT ''（可选标题；旧随笔为空）           |
| imgs       | TEXT NOT NULL DEFAULT '[]'（JSON 字符串数组）              |
| labels     | TEXT NOT NULL DEFAULT '[]'（JSON UUID 数组）               |
| messages   | TEXT NOT NULL DEFAULT '[]'（JSON）                         |
| mood       | TEXT                                                      |
| created_at | TEXT NOT NULL DEFAULT 本地时间文本                         |
| updated_at | TEXT NOT NULL DEFAULT 本地时间文本 (AFTER UPDATE 触发器维护) |

## essay_labels

| 列          | 类型                                                      |
| ----------- | --------------------------------------------------------- |
| id          | TEXT PRIMARY KEY (UUID)                                   |
| name        | TEXT NOT NULL                                             |
| essay_count | INTEGER NOT NULL DEFAULT 0                                |
| parent_id   | TEXT NULL（根级为空；整套标签写入前校验父级与环）          |
| created_at  | TEXT NOT NULL DEFAULT 本地时间文本                         |
| updated_at  | TEXT NOT NULL DEFAULT 本地时间文本 (AFTER UPDATE 触发器维护) |

“隐藏”根标签及其子孙关联的随笔不参与 AI 回顾统计或抽样；Android 同时提交本机尚未同步的隐藏随笔 ID。草稿不进入这些表。同步与图片检查响应的 `essay_schema_version=2` 用于客户端兼容检查。

## essay_year_summaries

| 列              | 类型                                                      |
| --------------- | --------------------------------------------------------- |
| year            | INTEGER PRIMARY KEY                                       |
| essay_count     | INTEGER NOT NULL DEFAULT 0                                |
| word_count      | INTEGER NOT NULL DEFAULT 0                                |
| month_summaries | TEXT NOT NULL DEFAULT '[]'（JSON）                         |
| updated_at      | TEXT NOT NULL DEFAULT 本地时间文本 (AFTER UPDATE 触发器维护) |

## booklet_styles

| 列                   | 类型                                                      |
| -------------------- | --------------------------------------------------------- |
| id                   | TEXT PRIMARY KEY (UUID)                                   |
| start_date           | TEXT NOT NULL（本地时间文本；写入前规整为 UTC 零点，语义=日历日期） |
| valid_check_in       | INTEGER NOT NULL DEFAULT 0                                |
| fully_done           | INTEGER NOT NULL DEFAULT 0                                |
| longest_streak       | INTEGER NOT NULL DEFAULT 0                                |
| longest_fully_streak | INTEGER NOT NULL DEFAULT 0                                |
| tasks                | TEXT NOT NULL DEFAULT '[]'（JSON）                         |
| created_at           | TEXT NOT NULL DEFAULT 本地时间文本                         |
| updated_at           | TEXT NOT NULL DEFAULT 本地时间文本 (AFTER UPDATE 触发器维护) |

## booklet_records

| 列              | 类型                                                      |
| --------------- | --------------------------------------------------------- |
| id              | TEXT PRIMARY KEY (UUID)                                   |
| style_id        | TEXT NOT NULL FK→booklet_styles (ON DELETE CASCADE)        |
| date            | TEXT NOT NULL（`YYYY-MM-DD`；Go 侧按 UTC 零点解析）        |
| message         | TEXT NOT NULL DEFAULT ''                                  |
| task_completion | TEXT NOT NULL DEFAULT '{}'（JSON）                         |
| mood            | TEXT                                                      |
| created_at      | TEXT NOT NULL DEFAULT 本地时间文本                         |
| updated_at      | TEXT NOT NULL DEFAULT 本地时间文本 (AFTER UPDATE 触发器维护) |

- 唯一约束：(style_id, date)
