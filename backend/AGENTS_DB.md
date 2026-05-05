# 数据库索引

**PostgreSQL 18.0** — 表结构及触发器定义。分模块明细见 `references/db/`。

| 模块 | Schema | 文件 | 说明 |
|------|--------|------|------|
| 漫画 | `comics` | `references/db/comics.md` | comic_books, comic_chapters, comic_images |
| 藏品 | `gallery` | `references/db/gallery.md` | media_assets, tags, media_tag_links + 触发器 |
| 用户数据 | `user_data` | `references/db/user_data.md` | essay_articles/labels/year_summaries, booklet_styles/records |