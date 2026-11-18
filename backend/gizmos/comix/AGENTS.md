# comix

- CLI 参数与输出见[对接协议](docs/协议文档.md)。Monarch 注入 `MONARCH_DB_FILE` 和 `COMIC_STORAGE_ROOT`。独立运行读 `backend/.env`，本目录的 `.env` 只配置爬虫。
- `comix/cli.py` 管参数和 JSON，`scheduler.py` 编排，`db.py` 持久化。计划任务 `scripts/check_updates.py` 复用 scheduler。手动写命令与 Monarch 托管写任务错开。
- 多步写入用 `db.transaction()`，时间用 `db._NOW`。`insert_chapters` 处理章节占号和跨漫画重复 URL，下载取其返回的章节 ID。
- 复用 `util/common.py` 的原子下载和 `util/image_size.py` 的宽高解析。校验图片后提交 `.downloading` 目录，再用同一事务写索引和完成状态。失败清理临时目录，重试可复用已落盘的有效图片。
- 存储路径和 legacy 兼容见[漫画数据](../../references/db/comix.md)。下载维护 `cover_image`，`sync` 校正章节及封面。
