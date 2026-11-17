# comix 核心

- `cli.py` 负责参数和 JSON，`scheduler.py` 编排，`db.py` 持久化。保留 `NotFound` 和 `CandidateChoiceRequired` 的退出码与候选契约。
- 多步写入用 `db.transaction()`，时间用 `db._NOW`。章节目录先提交，再同事务写图片索引和完成状态。重试可复用有效落盘图片。
- `update-check --download` 处理新章节和 pending，failed 只提示。`insert_chapters` 按站点顺序号登记，处理占号和跨漫画重复 URL，下载使用返回的章节 ID。
- 下载维护 `cover_image`，`sync` 校正章节及修复封面。
