# AGENTS.md —— comix 核心包（comix/）

Python 核心层，无状态设计。调用链：`cli.py` → `scheduler.py` → `db.py` / `adapters.*`。

## 模块职责

| 文件 | 职责 | 关键点 |
|---|---|---|
| `config.py` | 加载配置 | 数据库文件/存储根来自 backend/.env（或 Go 注入的环境变量）；本项目 .env 只放爬虫参数 |
| `db.py` | sqlite3 数据访问 | `connect()` 读、`transaction()` 写（BEGIN IMMEDIATE）；建表 SQL 不在此处 |
| `models.py` | 轻量 dataclass | ComicInfo / ChapterInfo / ComicDetail（适配器与调度之间传递） |
| `scheduler.py` | 调度层 | search/add/download/update-check/delete/cleanup，全部返回可 JSON 序列化 dict |
| `cli.py` | 命令行入口 | argparse 子命令；`--json` 纯净输出；UTF-8 强制；退出码 0/1/2 |

## 约定（改动必读）

1. **表结构真源是 `backend/references/db/sqlite.sql`**：`db.py` 不自持建表/迁移 SQL，
   `init_db()` 只是幂等执行那一份（Monarch 启动时执行同一份）。改表只改那一处。
2. **连接与事务**：`connect()` 是**只读用**上下文管理器（退出即关闭、不持有事务）；
   写入必须用 `transaction()`（`BEGIN IMMEDIATE` → 提交/回滚）。
   不要用裸 `conn.execute` 写多语句——单条写语句会立即自动提交，多语句会失去原子性。
3. **scheduler 返回纯 dict**：datetime 用 ISO 字符串（`cli._json_default` 兜底），
   禁止返回 ORM/游标对象。
4. **异常语义**：`NotFound`（业务未找到，退出码 2）、`CandidateChoiceRequired`
   （多候选未选择，附带 `candidates` 列表）——CLI 与 Go 服务都依赖此协议。
5. **增量幂等三层**：DB `status=done` 跳过 → 磁盘目录有图跳过
   （`download_pages_atomic`）→ `.downloading` 临时目录原子提交。
6. **孤儿回收**：`download_comic` 开始前回收本漫画 running 任务与 `.downloading`
   残留（`db.recover_running_tasks` + `_cleanup_downloading_dirs`）；`clean` 全局。
7. **下载成功后回填图片记录**：`db.replace_images`（内含 `scan_images` 的宽高解析），
   供 Go/Flutter 读取路径与宽高——新增下载路径必须保留此逻辑。
8. **update-check 跳过 legacy**：`site_code == "legacy"` 直接 continue。
   `--download` 的下载范围 = 本次新章节 ∪ 本地 `pending`（已登记未下载）章节，
   经 `chapter_ids` 精确指定并传 `sync_site=False`（该轮已拉过站点列表）；
   `failed` 不自动重试，仅在 message 中提示。report 的 `message` 必须包含
   `本地已下载 X/Y 章`——只报"已是最新"会把"登记了但一章都没下"的漫画
   伪装成已完成（真实数据 comic 126/131）。
9. **cover_image 必须显式维护**（`comics.cover_image` 是普通列，不是视图投影）。
   维护点：下载完成 `_ensure_cover_image`、legacy 导入时写入、`sync`（`repair_covers`）。
   **cover_url 由适配器 `get_chapters` 解析**（`BaseAdapter.extract_cover_url`，
   站点可覆盖 `cover_xpaths`），经 `db.set_cover_url` 落库；
   注意站点 logo/占位图在封面之前，选择器必须精确，否则会写入错误封面。
10. **chapter_no == 站点顺序号（不变量）**：`db.insert_chapters` 是唯一写入点，
    按站点序号升序处理，用本地占用表做"占位行让位"（新章节占号 → 旧行顺延），
    并会把位置变化的已有章节 renumber 回站点序号。**禁止退回
    `ON CONFLICT DO NOTHING` 式实现**：那会在站点插入新章节时静默保留错位序号，
    导致 `--latest N`/序号展示长期错误（真实事故：comic 2 番外篇被顶到 121）。
    跨漫画重复 URL（`comic_chapters.url` 全局唯一）只跳过该条并在返回值中给出
    `skipped_reason`，不得让整批失败；`download_comic` 下载前会先调用
    `_sync_chapters_from_site` 补登记站点新章节，避免"本地无此章 → 报告成功"的假象。
11. **封面/序号修复入口**：`sync --comic-id N|--all [--no-register] [--force-covers]`
    一次性校正（`scheduler.sync_comics` + `repair_covers`）；已在产品数据上验证。
12. **SQLite 取值**：布尔列存 0/1，需要 bool 的地方显式转换（站点 `enabled`）；
    时间列一律用 `db._NOW`（本地时间毫秒文本）写入，与 Go 侧 `dbutil` 格式一致。

## 表结构（当前）

- `comic_sites`：站点（code 唯一：manhuayu/morui/nicemh/xmanhua/legacy）
- `comics`：漫画（site_id+site_comic_id 唯一；管理列 is_public/readed/cover_image）
- `comic_chapters`：章节（comic_id+chapter_no 唯一；url 全局唯一；status pending/done/failed）
- `comic_images`：图片记录（chapter_id+sort_num 唯一；file_name/width/height）
- `comic_download_tasks`：下载任务（chapter_id 唯一；status queued/running/done/failed）
- `comic_aliases`：跨站别名

## CLI 命令清单

init / sites / search / add / add-url / list / chapters / download /
update-check / delete / clean / sync。全部支持 `--json`；交互选择仅在非 `--json` 时出现。

`sync` 为维护类命令（幂等）：按站点章节列表补登记并重排 `chapter_no`，
并可修复/补齐封面（`--no-register` 只重排；`--force-covers` 覆盖已有 cover_url）。
