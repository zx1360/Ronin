# AGENTS.md —— comix 漫画下载管理系统（总览）

自用漫画下载管理系统：多站协同爬取 + 单文件 SQLite 管理 + 增量追更，
通过无状态 CLI 被 Monarch（Go 服务器）与 Northstar（Flutter 桌面端）调用。

## 架构总览（3 层）

```
Flutter 桌面应用
   └─ Monarch Go HTTP 服务（子进程调用，JSON 协议）
        └─ python -m comix.cli --json <command>   ← 唯一入口（无状态，每次独立进程）
             └─ comix.scheduler（调度）
                  ├─ comix.adapters.*（四站爬虫适配器，站点特解）
                  └─ comix.db（标准库 sqlite3 数据访问）
                        └─ SQLite：backend/data/monarch.db（与 Monarch / gizmos 共用）
```

- 存储：图片落盘 `{COMIC_STORAGE_ROOT}/{comic_id}/{chapter_id}/{页码3位}.扩展名`，DB 只存相对路径
  （`rel_dir` = `comics/{comic_id}/{chapter_id}`，`comics/` 前缀与 /static 服务路径一致）。
- 表：`comic_*` 前缀（SQLite 无 schema），建表真源与 Monarch 共用
  `backend/references/db/sqlite.sql`；Monarch 启动时执行，`comix init` 读同一份。
- 旧资源：存储根下的名称目录（`{漫画名}/`）是 legacy 导入资源，站点 code=`legacy`，
  不参与更新检查。

## 关键事实（速查）

| 项 | 值 |
|---|---|
| 数据库 | SQLite `backend/data/monarch.db`（`backend/.env` 的 `DB_FILE`；Go 调用时注入 `MONARCH_DB_FILE`） |
| 存储根 | `backend/.env` 的 `COMIC_STORAGE_ROOT`（Go 调用时注入同名环境变量） |
| CLI 入口 | `python -m comix.cli --json <cmd>`（stdout 单行 JSON；进度日志走 stderr；UTF-8） |
| 退出码 | 0 成功 / 2 业务错误（未找到、多候选）/ 1 意外异常 |
| 下载并发 | 本项目 `.env` `COMIX_MAX_WORKERS`（默认 2） |
| 表 | comic_sites / comics / comic_chapters / comic_images / comic_download_tasks / comic_aliases |

## 重要约定（改动前必读）

1. **配置真源在 backend/.env**：数据库文件与存储根不在此处重复维护；本项目 `.env`
   只放爬虫专用参数（并发/超时）。运行期由 Monarch 注入环境变量，独立运行时
   `comix/config.py` 会回退加载 `backend/.env`。
2. **表结构不改在本项目**：`comix/db.py` 不自持建表 SQL，`init_db()` 执行
   `backend/references/db/sqlite.sql`（幂等）。改表必须改那一份。
3. **无状态**：scheduler/db 函数不持有会话状态；CLI 每次调用独立进程/独立连接；
   同漫画并发写由调用方（Go 服务）串行化。
4. **编码**：所有 CLI/脚本入口必须 `stream.reconfigure(encoding="utf-8")`（Windows GBK 坑）。
5. **JSON 纯净**：`--json` 模式 stdout 只输出结果 JSON；进度打印须走 stderr
   （下载进度由 `util.common.QUIET` 开关抑制）。
6. **SQLite 布尔**：列存 0/1，对外 JSON 需要 bool 的地方（如站点 `enabled`）在
   `db.py` 里显式转换，保持 CLI 契约不变。
7. **幂等/回退**：批量脚本（导入、补齐）每单元一个事务 + 失败回退；重复执行安全。
8. **宽高解析**用 `util/image_size.py`（纯 Python，禁引 Pillow）。

## 分支 AGENTS.md（按需查阅）

| 路径 | 内容 | 何时看 |
|---|---|---|
| `comix/AGENTS.md` | 核心层：db/scheduler/cli/models/config 职责与约定 | 改调度/数据访问/命令 |
| `comix/adapters/AGENTS.md` | 适配器接口、新增站点步骤、各站要点 | 改爬虫/加站点 |
| `scripts/AGENTS.md` | 运维脚本（导入/补齐/更新检查）职责与陷阱 | 跑脚本/改脚本 |
| `util/AGENTS.md` | 通用工具（common/image_size） | 复用工具函数 |
| `docs/协议文档.md` | Monarch 对接协议（命令/JSON 格式） | 动 Go/Flutter 侧 |

## 常用命令

```powershell
python -m comix.cli init                          # 建表 + 注册站点（幂等）
python -m comix.cli search "海贼王"                # 全站搜索候选
python -m comix.cli add "海贼王" --site xmanhua --pick 0   # 选择候选并增量下载
python -m comix.cli download <comic_id> --latest 5         # 增量下载最新 5 章
python -m comix.cli update-check --all --download          # 全量追更
python -m comix.cli delete <comic_id>                      # 删除（DB+文件）
python -m comix.cli clean                                  # 回收中断残留
python -m comix.cli sync --all                             # 按站点校正章节序号/补登记 + 修复封面
python -m comix.cli sync --all --force-covers               # 强制用站点封面刷新 cover_url
python scripts/import_legacy.py --execute                  # 导入旧资源（幂等可回退）
python scripts/backfill_images.py                          # 补齐图片记录
```
