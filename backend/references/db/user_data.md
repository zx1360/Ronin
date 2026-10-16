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
| updated_at | TEXT NOT NULL DEFAULT 本地时间文本（显式版本时间，毫秒） |

## essay_labels

| 列          | 类型                                                      |
| ----------- | --------------------------------------------------------- |
| id          | TEXT PRIMARY KEY (UUID)                                   |
| name        | TEXT NOT NULL                                             |
| essay_count | INTEGER NOT NULL DEFAULT 0                                |
| parent_id   | TEXT NULL（根级为空；整套标签写入前校验父级与环）          |
| created_at  | TEXT NOT NULL DEFAULT 本地时间文本                         |
| updated_at  | TEXT NOT NULL DEFAULT 本地时间文本（显式版本时间，毫秒） |

“隐藏”根标签及其子孙关联的随笔不参与 AI 回顾统计或抽样；Android 同时提交本机尚未同步的隐藏随笔 ID。草稿不进入这些表。同步与图片检查响应的 `essay_schema_version=2` 用于客户端兼容检查。

## essay_year_summaries

| 列              | 类型                                                      |
| --------------- | --------------------------------------------------------- |
| year            | INTEGER PRIMARY KEY                                       |
| essay_count     | INTEGER NOT NULL DEFAULT 0                                |
| word_count      | INTEGER NOT NULL DEFAULT 0                                |
| month_summaries | TEXT NOT NULL DEFAULT '[]'（JSON）                         |
| updated_at      | TEXT NOT NULL DEFAULT 本地时间文本（显式版本时间，毫秒） |

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
| updated_at           | TEXT NOT NULL DEFAULT 本地时间文本（显式版本时间，毫秒） |

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
| updated_at      | TEXT NOT NULL DEFAULT 本地时间文本（显式版本时间，毫秒） |

- 唯一约束：(style_id, date)

## 增量同步

- `GET /API/user-data/sync/:module?sync_version=2&after=<cursor>` 返回同一读快照中的变化行、`tombstones` 和新 `cursor`；省略或传 0 获取完整合并数据。
- `POST /API/user-data/sync/:module` 接受 `sync_version=2`、可选行集合与 `tombstones: [{collection,id,updated_at}]`；JSON 或 multipart 的 `jsonData` + `files` 均可。`backup` 上传入口对这两个模块也执行合并，偏好保持整体替换。
- 每条提交必须是完整行并带有效 `updated_at`；缺席的行不删除，较新版本获胜，同时间保留服务端行、删除优先。超前超过五分钟的时间戳拒绝，提醒校准设备时间。
- `user_data_changes(revision,module,collection,row_id,updated_at,deleted)` 为每行保存最新变化；`revision` 自增，避免离线旧时间戳写入被游标遗漏。删除标记不自动过期。游标失效时重新完整合并。
- 同样式、同日的多 ID 打卡按版本归一，落败 ID 生成 tombstone。删除样式为关联记录产生 tombstone，存在更新记录时拒绝删除；标签树和引用在事务内校验，失败全部回滚。
- 标签计数、年度汇总和打卡统计从合并后的实际数据重算；派生统计不提升业务行版本。图片使用不可变文件名，合并不清理孤儿文件。
- 升级后先用新版 Android 同步一次，再开始桌面编辑：旧 Hive 行首次上传时持久化更新时间。旧客户端读写会被拒绝，避免覆盖双端数据。桌面草稿仅存当前浏览器，不进入同步或 AI 回顾。
