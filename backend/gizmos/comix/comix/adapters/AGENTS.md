# 站点适配器

实现 `BaseAdapter` 的 `search`、`get_chapters` 和 `_fetch_chapter_image_urls`。用 `normalize_match` 标记候选，下载与线路复用基类，Playwright 通过 `reader()` 打开。新增适配器在 `__init__.py` 注册，顺序决定尝试顺序。

- manhuayu / nicemh 先读 `chapter_images`，回退路径分别为滚动采集和网络响应。nicemh 允许缺页。
- morui 从 `chapterImages` 读取 CDN 路径。xmanhua 用桌面 UA 获取章节列表，并解码 packer。
