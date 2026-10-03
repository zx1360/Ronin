# 数据库索引

**SQLite 3.50（单文件）** — 表结构与触发器定义真源：`references/db/sqlite.sql`（幂等，可重复执行）。

| 项 | 值 |
|---|---|
| 文件 | `backend/data/monarch.db`（`.env` 的 `DB_FILE`；启动时按需创建并应用建表脚本） |
| 驱动 | `modernc.org/sqlite`（纯 Go，无 cgo；`CGO_ENABLED=0` 亦可构建） |
| 写入模型 | 单写者：写连接池固定 1 连接 + `BEGIN IMMEDIATE`；WAL + `busy_timeout=10s` + 退避重试 |
| 三方共用 | Monarch(Go) / gizmos(Go CLI) / comix(Python) 读写同一文件 |

SQLite 无 schema 概念，表名扁平化；comix 侧统一加 `comic_` 前缀。

| 模块 | 表 | 说明 |
|------|----|------|
| 藏品 | `media_assets` / `tags` / `media_tag_links` | 见 `gallery.md`；标签 `full_path` 级联由 Go 维护 |
| 用户数据 | `essay_articles` / `essay_labels` / `essay_year_summaries` / `booklet_styles` / `booklet_records` | 见 `user_data.md` |
| AI | `media_ai` / `media_ai_tags` / `embeddings` / `faces` / `persons` / `jobs` / `duplicate_ignores` / `settings` | 见 `ai.md`。`jobs` 与 `media_ai`/`embeddings`/`faces` 各有 `input_sig` 列（输入档位 + 执行者指纹，用于追溯与自动重排） |
| 漫画 | `comic_sites` / `comics` / `comic_chapters` / `comic_images` / `comic_download_tasks` / `comic_aliases` | 见 `comix.md` |

## 取值约定

| 存储类型 | 约定 |
|---|---|
| `TEXT`（时间戳） | **本机本地时区**定宽毫秒 `YYYY-MM-DD HH:MM:SS.mmm`：字典序即时间序，`date()`/`strftime()` 可直接解析 |
| `TEXT`（日期） | `YYYY-MM-DD`；Go 侧解析为 **UTC 零点**（上游用 `.UTC().Format("2006-01-02")` 还原日历日） |
| `TEXT`（UUID） | 36 字符小写规范形式 |
| `TEXT`（JSONB / 数组） | JSON 文本，读写整列 |
| `BLOB` | 向量与人脸特征（小端 float32 拼接） |
| `INTEGER` | 布尔 0/1；主键 `INTEGER PRIMARY KEY AUTOINCREMENT` |

## 自动维护约定

- `updated_at`：每条业务表的 `AFTER UPDATE` 触发器，带 `WHEN NEW.updated_at IS OLD.updated_at`
  守卫——SQLite 无 `BEFORE UPDATE`，守卫同时保证「显式赋值不被覆盖」与「不触发自递归」。
- 标签 `full_path` 级联在 Go（`gallery_repo.rebuildTagPaths`）而非触发器：标签树只有百级，
  写操作后整体重算并只更新变化的行，天然容忍历史遗留的错误路径。
- 新增列不能靠 `sqlite.sql` 的 `CREATE TABLE IF NOT EXISTS` 补上，统一在
  `internal/service/db/migrate.go` 的 `addedColumns` 里声明（先查 `pragma_table_info` 再
  `ALTER TABLE ADD COLUMN`），同时更新 `sqlite.sql` 让全新库直接建好；Monarch 启动时执行。
  当前新增列：`jobs.input_sig`、`media_ai.{phash,ocr,caption}_input_sig`、
  `embeddings.input_sig`、`faces.input_sig`。

## 索引要点

- `media_assets`：`(is_deleted, sync_count, captured_at)` 供 `/batch`；
  `(is_deleted, captured_at)` 供 `/media` 默认排序；
  `(is_deleted, id)` 是 AI「尚无产物」统计的覆盖索引（缺它该聚合从 0.3s 退化到 3s）。
- `embeddings` 主键 `(media_id, kind, model)`；`faces` 建 `media_id` / `person_id` 索引；
  `jobs` 建 `(capability, status, priority, id)` / `media_id` / `updated_at`
  （后两个 + `input_sig` 支撑"指纹不匹配则重排"的扫描）。
- `comic_chapters.url`、`comic_images(chapter_id, sort_num)` 等唯一约束沿用原语义。

## 性能注意（70k 媒体 / 124k 漫画图 / 280k AI 任务 / 71k 向量实测）

- **深度 OFFSET 分页**：尾页（OFFSET 70000）约 330ms，是首页的千倍量级；常用页码无差异，
  绝对值可接受，未改键集分页（会改动 API 语义）。
- **模糊检索退化为 `LIKE '%kw%'` 全表扫描**（无 pg_trgm/FTS 索引）：`media_ai` 表窄、
  7 万行实测 29ms 反而更快，但**代价随文本量线性增长**，是必须留意的隐性上限；
  OCR/描述体量大幅增长时再引入 FTS5(trigram) 虚拟表。
- **批量 UPDATE 的 IN 列表**（500 条约 34ms）比 `= ANY(array)` 慢，批量写优先用事务。
- AI 待处理统计是 3 路 LEFT JOIN，由 `/API/ai/status` 每 30s 刷新一次，靠上述覆盖索引压到 0.3s。

## 验收

```powershell
go test ./...          # 含 internal/repository 数据层端到端验收
```

`internal/repository` 的验收会把数据库复制到临时目录后在副本上跑遍全部写路径（AI 产物、
标签树级联、事务性全量替换、comix 管理字段），**绝不触碰真实数据**。缺省取
`backend/data/monarch.db`，可用 `MONARCH_DB_SRC` 指定其它库。
