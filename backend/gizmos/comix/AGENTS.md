# comix

无状态漫画 CLI：`python -m comix.cli --json <command>`，由 Monarch 的任务引擎调用。
`cli → scheduler → db/adapters`；协议见 `docs/协议文档.md`，站点细节见 `comix/adapters/AGENTS.md`。

- 数据库/存储根读取 `backend/.env`；Go 注入 `MONARCH_DB_FILE` / `COMIC_STORAGE_ROOT`，本目录 `.env` 只存爬虫参数。
- 与 Monarch/gallery 共用 SQLite，建表真源 `backend/references/db/sqlite.sql`，`comix init` 读取同一份。
- 图片落盘 `{COMIC_STORAGE_ROOT}/{comic_id}/{chapter_id}/{三位页码}.扩展名`；DB 的 `rel_dir` 带 `comics/` 前缀，用 `config.storage_path` 解析。
- 名称目录与 `site_code=legacy` 的既有资源仍可读取，不参与追更。
- `--json` 的 stdout 仅结果 JSON，日志走 stderr；入口强制 UTF-8。退出码：0 成功、2 业务错误、1 意外异常。
- 多语句写入用 `db.transaction()`，批量操作按单元提交并支持失败回滚；同漫画并发写由 Go 调用方串行化。
- 宽高解析用 `util/image_size.py`，不引入 Pillow。下载与原子提交统一走 `util/common.py`。
- 子目录规则：`comix/AGENTS.md`、`util/AGENTS.md`、`scripts/AGENTS.md`。
