# 站点适配器

继承 `BaseAdapter`，实现 `search`、`get_chapters`、`_fetch_chapter_image_urls`。
下载/重试/原子提交复用基类与 `util/common.py`；候选用 `normalize_match` 标注 exact/fuzzy。
新增站点在 `__init__.py` 注册（顺序即尝试顺序），`comix init` 登记站点。

| code | 关键约束 |
| --- | --- |
| manhuayu | Playwright，优先 chapter_images，回退滚动采集；搜索相关度弱 |
| nicemh | Playwright，优先 chapter_images，回退网络响应；允许缺页 |
| morui | requests，chapterImages + CDN；章节标题去“连载 ”前缀 |
| xmanhua | requests + packer 解码；必须桌面 UA，否则没有桌面章节列表；标题繁体 |

Playwright 统一用 `base.PLAYWRIGHT_OPTIONS`；新增浏览器依赖同步 `requirements.txt`。
