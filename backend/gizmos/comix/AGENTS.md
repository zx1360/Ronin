# AGENTS.md —— comix 漫画下载管理系统（总览）

自用漫画下载管理系统：多站协同爬取 + SQLite 管理 + 增量追更，
通过无状态 CLI 被既有 Go 服务器 / ops 网页端调用。

## 架构总览（3 层）

```
Flutter / ops 网页端
   └─ Go HTTP 服务（子进程调用，JSON 协议）
        └─ python -m comix.cli --json <command>   ← 唯一入口（无状态，每次独立进程）
             └─ comix.scheduler（调度）
                  ├─ comix.adapters.*（四站爬虫适配器，站点特解）
                  └─ comix.db（stdlib sqlite3 数据访问）
                        └─ SQLite 单文件：与 Go 后端共用同一文件（DB_PATH）
```

- 存储：图片落盘 `comics/{comic_id}/{chapter_id}/{页码3位}.扩展名`，DB 只存相对路径
  （相对存储根 `COMIC_STORAGE_ROOT`，Ronin 下为 `backend/static/comics`；由 Go 调用时该值来自 app_settings）。
- 桥接：`comix_comic_books / comix_comic_chapters / comix_comic_images` 三个**只读**视图
  投影旧表结构，Go 端查询原样使用；Go 的写操作直接落到基表 `comix_comic`。
- 旧资源：`comics/` 下名称目录（`{漫画名}/`）是 legacy 导入资源，站点 code=`legacy`，
  不参与更新检查。

## 关键事实（速查）

| 项 | 值 |
|---|---|
| 数据库 | 单文件 SQLite，与 Go 后端**共用**；路径取环境变量 `DB_PATH`（相对当前工作目录），默认 `backend/data/monarch.db` |
| 表名 | 扁平 `comix_*`（SQLite 无 schema）：`comix_site` / `comix_comic` / `comix_chapter` / `comix_image` / `comix_download_task` / `comix_comic_alias` |
| 时间列 | TEXT，格式 `2006-01-02T15:04:05.000Z`（UTC / 毫秒 / 定宽），统一走 `comix/timefmt.py` |
| 布尔列 | INTEGER 0/1（`enabled` / `is_public` / `readed`）；CLI JSON 归一为 true/false |
| 存储根 | `.env` 的 `COMIC_STORAGE_ROOT`（Ronin: `backend/static/comics`）。**Go 服务调用时会下发 `comic.storage_root`（app_settings）覆盖它**；只有手工直接跑 CLI 才用 `.env` |
| CLI 入口 | `python -m comix.cli --json <cmd>`（stdout 单行 JSON；进度日志走 stderr；UTF-8） |
| 退出码 | 0 成功 / 2 业务错误（未找到、多候选）/ 1 意外异常 |
| 下载并发 | `.env` `COMIX_MAX_WORKERS`（默认 2）；同上，Go 调用时下发 `comix.max_workers` |
| 写并发 | 进程内 `threading.Lock` 串行化所有写操作；`busy_timeout=15000` 兜底跨进程（Go 服务）竞争 |

## 重要约定（改动前必读）

1. **表结构改动只改 `comix/db.py` 一处**（新库与老库都不会漂移）：
   - `SCHEMA_SQL`：新库建表 + 索引 + 三个桥接视图；
   - `PATCH_COLUMNS`：老库幂等补列（`PRAGMA table_info` 守卫 + `ALTER TABLE ADD COLUMN`）；
   - `VIEWS`：桥接视图的期望定义，`init` 时自动对齐（SQLite 没有 `CREATE OR REPLACE VIEW`）。
   没有独立的迁移脚本。
2. **无状态 + 单写者**：scheduler/db 函数不持有会话状态，CLI 每次调用独立进程/独立连接；
   SQLite 同一时刻只允许一个写者，故所有写函数都在模块级 `threading.Lock` 内
   （`db._write_lock()`）执行，配合 `busy_timeout` 保证不把 `database is locked` 抛给 Go 调用方。
3. **编码**：所有 CLI/脚本入口必须 `stream.reconfigure(encoding="utf-8")`（Windows GBK 坑）。
4. **JSON 纯净**：`--json` 模式 stdout 只输出结果 JSON；进度打印须走 stderr
   （下载进度由 `util.common.QUIET` 开关抑制）。布尔列必须以 JSON true/false 输出，
   不能漂成 0/1（`db._dict()` 负责归一）。
5. **时间与布尔写入**：时间一律走 `comix.timefmt.now_text()`（禁止散落格式串，SQLite 没有 `now()`）；
   `comix_comic.updated_at` 必须在**每次** UPDATE 时显式写入（没有触发器兜底）；
   布尔列写 0/1（Python int/bool 均可）。
6. **幂等/回退**：批量脚本（导入、迁移）每单元一个事务（`db.transaction()`，`BEGIN IMMEDIATE`）
   + 失败回退；重复执行安全。
7. **宽高解析**用 `util/image_size.py`（纯 Python，禁引 Pillow）。

## 分支 AGENTS.md（按需查阅）

| 路径 | 内容 | 何时看 |
|---|---|---|
| `comix/AGENTS.md` | 核心层：db/scheduler/cli/models/config/timefmt 职责与约定 | 改调度/数据访问/命令 |
| `comix/adapters/AGENTS.md` | 适配器接口、新增站点步骤、各站要点 | 改爬虫/加站点 |
| `scripts/AGENTS.md` | 运维脚本（PG 一次性导入/旧资源导入/回填/更新检查）职责与陷阱 | 跑脚本/改脚本 |
| `util/AGENTS.md` | 通用工具（common/image_size） | 复用工具函数 |
| `docs/架构设计.md` | 表结构、桥接视图、Go 端对接与查询约定 | 改表/动 Go 侧 |

## 常用命令

```powershell
python -m comix.cli init                          # 建表 + 桥接视图 + 注册站点（幂等）
python -m comix.cli search "海贼王"                # 全站搜索候选
python -m comix.cli add "海贼王" --site xmanhua --pick 0   # 选择候选并增量下载
python -m comix.cli download <comic_id> --latest 5         # 增量下载最新 5 章
python -m comix.cli update-check --all --download          # 全量追更
python -m comix.cli delete <comic_id>                      # 删除（DB+文件）
python -m comix.cli clean                                  # 回收中断残留
python -m comix.cli sync --all                             # 按站点校正章节序号/补登记 + 修复封面
python -m comix.cli sync --all --force-covers               # 强制用站点封面刷新 cover_url
python scripts/import_from_pg.py                           # 一次性 PostgreSQL → SQLite 导入（PG 只读）
python scripts/import_legacy.py --execute                  # 导入旧资源（幂等可回退）
python scripts/backfill_images.py                          # 补齐图片记录
```
