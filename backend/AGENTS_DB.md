# 数据库索引

**PostgreSQL 18.0** — 表结构及触发器定义.

| 模块 | Schema | 文件 | 说明 |
|------|--------|------|------|
| 初始化 | - | `references/db/init.sql` | gallery + user_data 的建表/索引/函数/触发器（幂等，可重复执行） |
| 漫画 | `comix` | `references/db/comix.md` | 由外部 comix 爬虫项目维护，本项目只读写 |
| 藏品 | `gallery` | `references/db/gallery.md` | media_assets, tags, media_tag_links + 触发器 |
| 用户数据 | `user_data` | `references/db/user_data.md` | essay_articles/labels/year_summaries, booklet_styles/records |
