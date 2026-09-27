# AGENTS.md —— comix 核心包（comix/）

Python 核心层，无状态设计。调用链：`cli.py` → `scheduler.py` → `db.py` / `adapters.*`。

## 模块职责

| 文件 | 职责 | 关键点 |
|---|---|---|
| `config.py` | 加载 `.env` + 解析共享库路径 | `DB_PATH`（与 Go 同一解析策略）、`COMIC_STORAGE_ROOT`（绝对路径）、`storage_path(rel_dir)`、并发/稳定性配置 |
| `timefmt.py` | 时间列格式 | `now_text()` / `format_time()` / `parse_text()`，与 Go `model.TimeFormat` 一致（UTC/毫秒/定宽） |
| `db.py` | stdlib `sqlite3` 数据访问 | 每函数独立 `connect()`（退出即关连接）；`SCHEMA_SQL`+`PATCH_COLUMNS`+`VIEWS` 幂等建库 |
| `models.py` | 轻量 dataclass | ComicInfo / ChapterInfo / ComicDetail（适配器与调度之间传递） |
| `scheduler.py` | 调度层 | search/add/download/update-check/delete/cleanup，全部返回可 JSON 序列化 dict |
| `cli.py` | 命令行入口 | argparse 子命令；`--json` 纯净输出；UTF-8 强制；退出码 0/1/2 |

## 约定（改动必读）

1. **表结构改动三处同步**（都在 `db.py` 内，根 AGENTS.md 约定 #1）：
   `SCHEMA_SQL`（新库）、`PATCH_COLUMNS`（老库幂等补列）、`VIEWS`（桥接视图定义）。
   视图是**只读**投影，没有 INSTEAD OF 触发器；Go 端写操作直接落到 `comix_comic`。
2. **db.py 连接与事务**：`connect()` 是唯一入口，逐连接设置
   `journal_mode=WAL` / `busy_timeout=15000` / `synchronous=NORMAL` / `foreign_keys=ON`
   （SQLite 默认关闭外键，所有 ON DELETE CASCADE 都依赖它），并设置
   `row_factory=sqlite3.Row`；它是 `@contextmanager`，退出时**提交并关闭**连接
   （`sqlite3.Connection.__exit__` 不关连接，直接 `with sqlite3.connect()` 会泄漏句柄）。
   多语句事务用 `with connect() as conn, transaction(conn):`（`BEGIN IMMEDIATE`）。
3. **写操作串行化**：SQLite 单写者，所有写函数都在 `_write_lock()`（模块级 RLock）内执行；
   下载线程池（`COMIX_MAX_WORKERS`）与主线程共用该锁，另外靠 `busy_timeout` 与 Go 服务竞争。
   **新增写函数必须套 `_write_lock()`**。
4. **返回值是纯 dict**：`sqlite3.Row` 不是 JSON 可序列化的，所有对外函数用
   `db._dict()/ _dicts()` 转换（同时把 `enabled`/`is_public`/`readed` 从 0/1 归一为 bool，
   保证 CLI JSON 与协议文档一致）。禁止返回 Row / 游标对象。
5. **时间**：写入一律 `now_text()`；`comix_comic.updated_at` 每次 UPDATE 都要带；
   读取的时间就是 TEXT，不要再格式化（JSON 里原样输出即可）。
6. **异常语义**：`NotFound`（业务未找到，退出码 2）、`CandidateChoiceRequired`
   （多候选未选择，附带 `candidates` 列表）——CLI 与 Go 服务都依赖此协议。
   唯一约束冲突是 `sqlite3.IntegrityError`。
7. **增量幂等三层**：DB `status=done` 跳过 → 磁盘目录有图跳过
   （`download_pages_atomic`）→ `.downloading` 临时目录原子提交。
8. **孤儿回收**：`download_comic` 开始前回收本漫画 running 任务与 `.downloading`
   残留（`db.recover_running_tasks` + `_cleanup_downloading_dirs`）；`clean` 全局。
9. **下载成功后回填图片记录**：`db.clear_images` + `scan_images` + `db.insert_images`
   （含宽高），供桥接视图 `comix_comic_images` 使用——新增下载路径必须保留此逻辑。
10. **update-check 跳过 legacy**：`site_code == "legacy"` 直接 continue。
    `--download` 的下载范围 = 本次新章节 ∪ 本地 `pending`（已登记未下载）章节，
    经 `chapter_ids` 精确指定并传 `sync_site=False`（该轮已拉过站点列表）；
    `failed` 不自动重试，仅在 message 中提示。report 的 `message` 必须包含
    `本地已下载 X/Y 章`——只报"已是最新"会把"登记了但一章都没下"的漫画
    伪装成已完成（真实数据 comic 126/131）。
11. **cover_image 必须显式维护**：视图 `comix_comic_books.cover_image` 是纯列
    （禁止在视图里写"取第一章第一图"的相关子查询——JOIN 放大后逐行执行，
    曾致 `GetAllComicInfos` 超时）。维护点：下载完成 `_ensure_cover_image`、
    导入时写入、`backfill_images.py` 封面补齐、`sync`（`repair_covers`）。
    **cover_url 由适配器 `get_chapters` 解析**（`BaseAdapter.extract_cover_url`，
    站点可覆盖 `cover_xpaths`），经 `db.set_cover_url` 落库；
    注意站点 logo/占位图在封面之前，选择器必须精确，否则会写入错误封面。
12. **chapter_no == 站点顺序号（不变量）**：`db.insert_chapters` 是唯一写入点，
    按站点序号升序处理，用本地占用表做"占位行让位"（新章节占号 → 旧行顺延），
    并会把位置变化的已有章节 renumber 回站点序号。**禁止退回
    `ON CONFLICT DO NOTHING` 式实现**：那会在站点插入新章节时静默保留错位序号，
    导致 `--latest N`/序号展示长期错误（真实事故：comic 2 番外篇被顶到 121）。
    跨漫画重复 URL（`comix_chapter.url` 全局唯一）只跳过该条并在返回值中给出
    `skipped_reason`（chapter_no 冲突同样如实上报，绝不静默丢章），不得让整批失败；
    `download_comic` 下载前会先调用 `_sync_chapters_from_site` 补登记站点新章节，
    避免"本地无此章 → 报告成功"的假象。
13. **封面/序号修复入口**：`sync --comic-id N|--all [--no-register] [--force-covers]`
    一次性校正（`scheduler.sync_comics` + `repair_covers`）；已在产品数据上验证。
14. **桥接视图 TEXT 表达式索引**：视图 id 系列列是 `CAST(... AS TEXT)` 表达式，
    Go 端连接/WHERE（text=text）靠 `SCHEMA_SQL` 里的表达式索引
    `idx_*_id_text`（如 `ON comix_chapter (CAST(comic_id AS TEXT))`）走索引，
    实测查询计划为 `SCAN ch USING INDEX idx_chapter_comic_id_text`。
    改视图列表达式时必须同步这些索引。

## db.py 表结构（扁平表名，与 Go 共用一个库文件）

- `comix_site`：站点（code 唯一：manhuayu/morui/nicemh/xmanhua/legacy）
- `comix_comic`：漫画（site_id+site_comic_id 唯一；is_public/readed/cover_image；
  `id INTEGER PRIMARY KEY AUTOINCREMENT`，id 即存储目录名，**永不复用**）
- `comix_chapter`：章节（comic_id+chapter_no 唯一；url 全局唯一；status pending/done/failed；
  也用 AUTOINCREMENT —— chapter_id 是磁盘目录名，复用会误命中旧目录）
- `comix_image`：图片记录（chapter_id+sort_num 唯一；file_name/width/height）
- `comix_download_task`：下载任务（chapter_id 唯一；status queued/running/done/failed；
  子表用 `INTEGER PRIMARY KEY`，随父行级联删除且不被外部引用）
- `comix_comic_alias`：跨站别名（同上）

桥接视图（由 `db.py` 的 `SCHEMA_SQL` 创建，只读）：`comix_comic_books` /
`comix_comic_chapters` / `comix_comic_images`。

## CLI 命令清单

init / sites / search / add / add-url / list / chapters / download /
update-check / delete / clean / sync。全部支持 `--json`；交互选择仅在非 `--json` 时出现。

`sync` 为维护类命令（幂等）：按站点章节列表补登记并重排 `chapter_no`，
并可修复/补齐封面（`--no-register` 只重排；`--force-covers` 覆盖已有 cover_url）。
