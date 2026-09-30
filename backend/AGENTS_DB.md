# 数据库索引

**SQLite 3.50（单文件）** — 表结构与触发器定义真源：`references/db/sqlite.sql`（幂等，可重复执行）。

| 项 | 值 |
|---|---|
| 文件 | `backend/data/monarch.db`（`.env` 的 `DB_FILE`；启动时按需创建并应用建表脚本） |
| 驱动 | `modernc.org/sqlite`（纯 Go，无 cgo；`CGO_ENABLED=0` 亦可构建） |
| 写入模型 | 单写者：写连接池固定 1 连接 + `BEGIN IMMEDIATE`；WAL + `busy_timeout=10s` + 退避重试 |
| 三方共用 | Monarch(Go) / gizmos(Go CLI) / comix(Python) 读写同一文件 |
| 回滚 | 迁移前的 PostgreSQL 原库原样保留；回滚即改回 `DB_*` 配置（见 `tools/migrate_pg_to_sqlite.py`） |

SQLite 无 schema 概念，表名扁平化；comix 侧统一加 `comic_` 前缀。

| 模块 | 表 | 说明 |
|------|----|------|
| 藏品 | `media_assets` / `tags` / `media_tag_links` | 见 `gallery.md`；标签 `full_path` 级联由 Go 维护 |
| 用户数据 | `essay_articles` / `essay_labels` / `essay_year_summaries` / `booklet_styles` / `booklet_records` | 见 `user_data.md` |
| AI | `media_ai` / `media_ai_tags` / `embeddings` / `faces` / `persons` / `jobs` / `duplicate_ignores` / `settings` | 见 `ai.md` |
| 漫画 | `comic_sites` / `comics` / `comic_chapters` / `comic_images` / `comic_download_tasks` / `comic_aliases` | 见 `comix.md` |

## 类型与取值约定

| PostgreSQL | SQLite | 约定 |
|---|---|---|
| `UUID` | `TEXT` | 36 字符小写规范形式 |
| `TIMESTAMPTZ` | `TEXT` | **本机本地时区**定宽毫秒 `YYYY-MM-DD HH:MM:SS.mmm`：字典序即时间序，`date()`/`strftime()` 可直接解析，且与原 PG 会话时区下的 `DATE()`/`EXTRACT()` 语义一致 |
| `DATE` | `TEXT` | `YYYY-MM-DD`；Go 侧解析为 **UTC 零点**（与 pgx 返回 DATE 的行为一致） |
| `BYTEA` | `BLOB` | |
| `JSONB` | `TEXT` | JSON 文本，读写整列 |
| `TEXT[]` / `UUID[]` / `REAL[]` | `TEXT` | JSON 数组文本 |
| `BOOLEAN` | `INTEGER` | 0/1 |
| `BIGSERIAL` / `SERIAL` | `INTEGER PRIMARY KEY AUTOINCREMENT` | 迁移时显式带入原 id |

## 触发器（替代原 PG 触发器/存储过程）

- `updated_at` 自动维护：每条业务表的 `AFTER UPDATE` 触发器，带
  `WHEN NEW.updated_at IS OLD.updated_at` 守卫——SQLite 无 `BEFORE UPDATE`，
  守卫同时保证「显式赋值不被覆盖」与「不触发自递归」。
  与 PG 的差异：原 `BEFORE UPDATE` 会无条件覆盖 `updated_at`，此处显式赋值优先。
- **标签 `full_path` 级联上移到 Go**（`gallery_repo.rebuildTagPaths`）：原 PG 的
  `tags_before_ins_upd` / `tags_after_upd` 两个触发器函数不再需要。标签树规模小
  （百级），写操作后整体重算并只更新变化的行，天然容忍历史遗留的错误路径。

## 索引要点

- `media_assets`：`(is_deleted, sync_count, captured_at)` 供 `/batch`；
  `(is_deleted, captured_at)` 供 `/media` 默认排序；
  `(is_deleted, id)` 是 AI「尚无产物」统计的覆盖索引（缺它该聚合从 0.3s 退化到 3s）。
- `embeddings` 主键 `(media_id, kind, model)`；`faces` 建 `media_id` / `person_id` 索引；
  `jobs` 建 `(capability, status, priority, id)` / `media_id` / `updated_at`。
- `comic_chapters.url`、`comic_images(chapter_id, sort_num)` 等唯一约束沿用原语义。

## 与 PostgreSQL 方案的性能比对

`python tools/bench_pg_vs_sqlite.py`（同一份生产数据、同一台机器，取多次最快值：
70k 媒体 / 124k 漫画图 / 280k AI 任务 / 71k 向量）：

| 场景 | PG | SQLite | 倍数 |
|---|---|---|---|
| gallery 总览聚合 | 159 ms | 37 ms | 0.23 |
| batch 分页（首页） | 0.3 ms | 0.1 ms | 0.26 |
| batch 尾页（OFFSET 70000） | 63 ms | 329 ms | 5.2 |
| 标签（含子孙）筛选媒体 | 0.5 ms | 0.0 ms | 0.08 |
| AI 任务列表（280k 行） | 0.2 ms | 0.0 ms | 0.19 |
| AI 任务队列统计 | 170 ms | 93 ms | 0.55 |
| AI 待处理统计（3 路 LEFT JOIN） | 226 ms | 337 ms | 1.50 |
| 模糊检索：关键词（pg_trgm vs LIKE 全扫） | 194 ms | 29 ms | 0.15 |
| 模糊检索：文件名 | 0.8 ms | 0.0 ms | 0.06 |
| AI 标签聚合（unnest vs 关系表） | 209 ms | 0.1 ms | ~0 |
| 载入全部向量（54MB） | 1225 ms | 414 ms | 0.34 |
| 载入全部人脸特征（58MB） | 1438 ms | 383 ms | 0.27 |
| comix 整本章节+图片（2807 行） | 11 ms | 4 ms | 0.38 |
| 批量插入 2000 条媒体（事务） | 118 ms | 178 ms | 1.51 |
| 批量更新 500 条媒体 | 8.8 ms | 34 ms | 3.9 |
| 批量入队 500 条任务 | 22 ms | 20 ms | 0.89 |

**不得不接受的取舍**（其余场景持平或更快）：

1. **深度 OFFSET 分页**比 PG 慢约 5 倍（尾页 329ms vs 63ms）。PG 的索引扫描 +
   可见性判断在跳过大量行时更便宜；SQLite 需逐行走索引。首页与常用页码无差异，
   70k 规模下绝对值可接受，未改为键集分页（会改动 API 语义）。
2. **批量 UPDATE 的 IN 列表**比 PG 的 `= ANY(array)` 慢约 4 倍（34ms vs 9ms）。
3. **失去 pg_trgm 索引**：模糊检索退化为 `LIKE '%kw%'` 全表扫描。实测在本数据集上
   反而更快（media_ai 表窄、行数 7 万），但**代价随文本量线性增长**，属于必须留意的
   隐性上限；若将来 OCR/描述体量大幅增长，再引入 FTS5(trigram) 虚拟表。
4. **AI 待处理统计**（3 路 LEFT JOIN）慢 1.5 倍，且该聚合由 `/API/ai/status` 每 30s
   后台刷新一次；已用 `(is_deleted, id)` 覆盖索引压到 0.3s。

原 PG 侧的 pg_trgm / 数组 / 触发器能力替代方式见上文「类型与取值约定」「触发器」。

## 迁移与校验

```powershell
python tools/migrate_pg_to_sqlite.py --check          # 探测源库
python tools/migrate_pg_to_sqlite.py                  # 导入并抽样校验
python tools/migrate_pg_to_sqlite.py --verify-only    # 只校验
python tools/bench_pg_vs_sqlite.py                    # 两方案耗时对比
```

迁移是只读源库 + 重建目标库，可重复执行；覆盖已有目标库需 `--force`
（旧库改名为 `.bak`；**迁移前必须停掉 Monarch**，否则文件被占用无法改名）。
校验覆盖全部表的行数与内容（小表全量、大表按主键随机抽样，默认 3000 行）。

## 验收

```powershell
go test ./...                                  # 含 internal/repository 数据层端到端验收（在库副本上跑全部写路径）
python tools/smoke_api.py                      # 对运行中的服务逐个接口冒烟（--write 追加写用例，仅测试库）
```
