# 站点适配器

实现 `BaseAdapter` 的 `search`、`get_chapters` 和 `_fetch_chapter_image_urls`。候选经 `normalize_match`，线路和下载复用基类，浏览器通过 `reader()` 打开。`__init__.py` 的注册顺序决定站点尝试顺序。

- manhuayu 和 nicemh 先读 `chapter_images`，分别回退滚动采集与网络响应。nicemh 允许缺页。
- morui 从 `chapterImages` 读取 CDN 路径。xmanhua 用桌面 UA 获取章节并解码 packer。
