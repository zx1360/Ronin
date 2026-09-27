# 数据库索引

**SQLite 单文件**（`DB_PATH`，默认 `backend/data/monarch.db`）。
表结构以 `internal/service/db/schema.sql` 为唯一真相源，`references/db/schema.sql` 是它的生成副本。

| 模块 | 表前缀 | 明细文件 | 内容 |
|------|--------|----------|------|
| 藏品 | `gallery_` | `references/db/gallery.md` | media_assets, tags, media_tag_links |
| 用户数据 | `user_data_` | `references/db/user_data.md` | essay_*, booklet_*（含 `deleted_at` 墓碑） |
| AI 处理 | `ai_` | `references/db/ai.md` | media, results, embeddings, faces, persons, jobs, duplicate_ignores, reviews |
| 漫画 | `comix_` | `references/db/comix.md` | 由 `gizmos/comix` 建表与维护，与其余表共用同一文件 |
| 运行时配置 | `app_settings` | `internal/settings/settings.go` | 键值表，由 UI 经 `/API/settings` 读写 |

## 约定

- 时间列一律 TEXT，格式 `2006-01-02T15:04:05.000Z`（UTC、毫秒、定宽，字典序即时序）；
  仅日期的列用 `YYYY-MM-DD`。**不要依赖 SQLite 的类型亲和性做转换**。
- 布尔用 INTEGER 0/1；数组用 JSON 文本（按元素检索走 `json_each`）；UUID 存 TEXT；二进制存 BLOB。
- **没有触发器**：`updated_at` 与 `gallery_tags.full_path`（含子孙级联）都由 Go 侧维护，
  因此每次 UPDATE 都必须显式写入 `updated_at`。
- 单写者：写池固定 1 条连接（`db.W()`）+ WAL，写事务在进程内天然串行；
  读池独立（`db.R()`），WAL 下读不阻塞写。批量写入用 `db.Tx` 分段提交。
- `PRAGMA foreign_keys=ON` 随每条连接下发，级联删除依赖它。

## 迁移与回滚

```powershell
cd backend/cmd/migrate_pg
$env:PGPASSWORD='...'; go run . -verify-sample 200   # 源库只读；逐表比对行数 + 抽样逐列校验
```

- 迁移工具是**独立 Go module**（`cmd/migrate_pg/go.mod`）：主服务因此不依赖任何 PostgreSQL 驱动，
  运行它必须在本目录内执行（`go run .`），不能从 `backend/` 用 `go run ./cmd/migrate_pg`。

- 原 PostgreSQL 库**原样保留**，迁移工具绝不写入源库；回滚 = 删除 SQLite 文件后重启服务。
- 目标文件已存在时必须显式 `-force`（会删除重建），避免误覆盖。
- 迁移会把 `.env` 中的旧配置项播种进 `app_settings`，并按"迁移前的实际情况"登记
  `ai_results` 溯源（统一 `preview256`），因此 face/ocr/vlm 会因档位升级自动重排一次。
- `comix_*` 表另行执行 `python -m comix.cli init` 与 `gizmos/comix/scripts/import_from_pg.py`。
