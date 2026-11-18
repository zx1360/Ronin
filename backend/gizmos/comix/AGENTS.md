# comix

- CLI 入口 `python -m comix.cli --json <command>`。stdout 只输出结果 JSON，日志走 stderr，使用 UTF-8。退出码 0 成功、2 业务错误、1 意外异常。
- Monarch 注入 `MONARCH_DB_FILE` 和 `COMIC_STORAGE_ROOT`，独立运行从 `backend/.env` 解析，comix 自己的 `.env` 只配置爬虫。init 执行共享 `references/db/comix.sql` 并登记站点。
- 新图存 `{comic_id}/{chapter_id}/{三位页码}.扩展名`，库中路径带 `comics/` 前缀，用 `config.storage_path` 解析。legacy 名称目录仍可读，跳过追更。
- 手动写入命令与 Monarch 托管写任务错开。下载走 `util/common.py`，宽高由 `util/image_size.py` 解析。
