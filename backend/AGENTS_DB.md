# 数据库索引

**PostgreSQL 18.0** — 表结构及触发器定义.

| 模块 | Schema | 文件 | 说明 |
|------|--------|------|------|
| 全局初始化 | - | `references/db/init.sql` | 完整建表脚本 (Schema + 表 + 索引 + 触发器) |
| 漫画 | `comics` | `references/db/comics.md` | comic_books, comic_chapters, comic_images |
| 藏品 | `gallery` | `references/db/gallery.md` | media_assets, tags, media_tag_links + 触发器 |
| 用户数据 | `user_data` | `references/db/user_data.md` | essay_articles/labels/year_summaries, booklet_styles/records |