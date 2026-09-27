# AGENTS.md —— 运维脚本（scripts/）

独立脚本，均可直接 `python scripts/xxx.py` 运行；批量操作遵循
"每单元一个事务 + 失败回退 + 幂等可重跑"。

## 脚本清单

| 脚本 | 职责 | 关键参数 |
|---|---|---|
| `check_updates.py` | 全量更新检查（计划任务追更） | `--download` 自动追更 / `--latest N` / `--json` |
| `import_from_pg.py` | **一次性**把 PostgreSQL `comix.*` 导入共享 SQLite 的 `comix_*` 表（PG 只读） | 环境变量 `PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE` |
| `import_legacy.py` | 导入旧资源 `comics_` → 存储根（移动+入库） | `--dry-run` / `--execute` / `--limit N` / `--json` |
| `backfill_images.py` | 为已下载但**缺图片记录**的章节补齐（含封面） | `--comic-id N` / `--json` |

> `backfill_images.py` 只处理 `status=done` 且 `comix_image` 无记录的章节
> （导入与下载回填已写记录的自动跳过，避免重扫 28 万文件）；
> 同时为 `cover_image` 为空的漫画补第一章第一图。
>
> `import_from_pg.py` 是**一次性**迁移工具：先在 PostgreSQL 侧开只读事务，
> 再逐表写入 SQLite（`ON CONFLICT (id) DO NOTHING`，可重复运行），
> 最后逐表比对行数，不一致即非零退出。回退 = 删掉 SQLite 库文件（PG 未被改动）。
> psycopg 不在运行时 `requirements.txt` 里，按需 `pip install "psycopg[binary]>=3.1"`。

## 关键约定与陷阱（踩过的坑）

1. **事务必须显式**：`sqlite3` 的隐式事务在 `isolation_level` 下自动开启，
   与 `BEGIN` 混用会报 "cannot start a transaction within a transaction"。
   `comix.db.connect()` 固定设 `isolation_level=None`（自动提交），
   需要事务时显式 `with db.connect() as conn, db.transaction(conn):`
   （`BEGIN IMMEDIATE`，直接取写锁，避免读事务升级为写的死锁）。
2. **写操作要走写锁**：批量脚本可能长时间持库，务必用
   `with db._write_lock(), db.transaction(conn):` 与爬虫主流程共用同一把进程内写锁，
   否则与下载线程池并发写会触发 `database is locked`。
3. **单条语句冲突不中止事务**：SQLite 违反唯一约束只回滚该语句，
   因此不需要 PostgreSQL 的 `SAVEPOINT`；但**不允许**用
   `INSERT OR IGNORE`/`DO NOTHING` 掩盖 `chapter_no` 冲突（见 `comix/AGENTS.md` #12）。
4. **文件移动需处理只读/占用**：用 `util.common.remove_dir_safely`（带重试与
   只读处理）；跨目录移动优先 `shutil.move`（同盘 rename），失败需回退。
5. **路径基准是存储根**：`rel_dir`（`comics/{comic_id}/{chapter_id}`）相对
   `COMIC_STORAGE_ROOT` 解析，统一用 `config.storage_path(rel_dir)`；
   旧资源目录 `comics_` 与存储根平级（`<COMIC_STORAGE_ROOT>/../comics_`）。
6. **导入幂等**：`import_legacy.py` 以 `site_comic_id=目录名` 唯一、chapter 以
   `(comic_id, chapter_no)` 唯一、image 以 `(chapter_id, sort_num)` 唯一实现
   幂等；中断后重跑自动补导入"已移动未登记"的目录（Phase 1 恢复）。
   `import_legacy.py` 自己负责幂等注册 legacy 站点。
7. **UTF-8 输出**：所有脚本入口 `stream.reconfigure(encoding="utf-8")`
   （Windows 控制台 GBK 遇特殊字符如 `～` 会崩）。

## 环境准备顺序（全新环境）

```powershell
pip install -r requirements.txt
python -m playwright install chromium        # 漫画鱼/奈斯需要
python -m comix.cli init                      # 建表 + 桥接视图 + 注册站点
python scripts/import_from_pg.py              # 如需从 PostgreSQL 迁移存量（PG 只读，可重跑）
python scripts/import_legacy.py --execute     # 如需导入旧资源 comics_（幂等可回退）
python scripts/backfill_images.py             # 补齐存量下载章节的图片记录
```

> CLI 由 Go 服务以 `cwd=backend/gizmos/comix` 拉起，库路径由 `DB_PATH` 给出；
> 手工运行脚本时若不带 `DB_PATH`，`config.py` 会按 `data/monarch.db` →
> `../../data/monarch.db` 的顺序探测同一个库文件。
