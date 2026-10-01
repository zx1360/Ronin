# comix 核心

`cli.py` 管命令/JSON，`scheduler.py` 管业务编排，`db.py` 管 SQLite，`models.py` 为适配器数据类，`config.py` 管配置/路径。

- 多步写入必须 `db.transaction()`（BEGIN IMMEDIATE），单条语句可用 `connect()` 自动提交；建表 SQL 仅引用后端真源。
- scheduler 返回可 JSON 序列化 dict；保留 `NotFound` / `CandidateChoiceRequired` 的退出码与 candidates 契约。
- 下载幂等：DB done → 已有完整目录 → `.downloading` 原子提交。开始前回收本漫画 running 任务/临时目录，完成后 `replace_images` 回填页码与宽高。
- `update-check --download` 精确下载新章节与本地 pending，failed 只提示；跳过 legacy。报告包含本地已下载 X/Y 章。
- `chapter_no` 是站点顺序号；登记走 `insert_chapters`，占号需让位/重排，禁止忽略冲突后保留错序。跨漫画重复 URL 只跳过该条并返回 `skipped_reason`。
- `cover_image` 显式维护；`cover_url` 由适配器精确解析，避免 logo/占位图。`sync` 是章节校正与封面修复入口。
- 布尔 JSON 显式转换 0/1；时间写入使用 `db._NOW`，与 Go 本地毫秒文本格式一致。
