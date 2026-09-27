# AGENTS.md —— 站点适配器（comix/adapters/）

四站爬虫的站点特有逻辑。**所有通用逻辑必须留在 `base.py` / `util/common.py`，
适配器文件内不允许出现可提取的公共代码**（自用维护性要求）。

## 接口（BaseAdapter）

```python
class BaseAdapter:
    code / name / base_url                # 站点元信息
    page_timeout_sec / img_timeout_sec / image_retry_times /
    chapter_retry_times / max_workers / strict_expected_total   # 稳定性配置（.env 默认）

    def search(self, name) -> list[ComicInfo]           # 站点搜索 → 候选
    def get_chapters(self, detail_url) -> ComicDetail   # 详情页 → 漫画+章节
    def _fetch_chapter_image_urls(self, chapter_url) -> tuple[list[str], int]  # 章节图片 URL
    # download_chapter 由基类实现（原子下载到 save_dir，页码 3 位补齐），站点通常不覆盖
```

- `download_chapter(chapter, save_dir)` → `(ok, pages, error)`：图片下载/重试/原子提交
  全在基类；站点只需提供图片 URL 列表。
- 基类工具：`self.get(url)`（带重试会话+随机头）、`self.session()`、`self.headers()`、
  `self.sleep()`。
- 搜索候选通过 `self.normalize_match(list, name)` 标注 exact/fuzzy。

## 新增站点步骤（最小改动）

1. 新建 `comix/adapters/xxx.py`，继承 `BaseAdapter`，实现三个方法；
2. `comix/adapters/__init__.py` 注册表中加入类（顺序即调度尝试顺序）；
3. 站点注册进 DB：`python -m comix.cli init` 会自动注册全部适配器；
4. 新增站点若需要 Playwright，用 `base.PLAYWRIGHT_OPTIONS`，并在
   `requirements.txt` 注释、`docs/` 与根 AGENTS.md 站点表更新。

## 各站要点

| code | 站点 | 图片获取 | 搜索端点 | 注意 |
|---|---|---|---|---|
| manhuayu | 漫画鱼 | Playwright（window.params.chapter_images，回退滚动采集） | `/search/{词}/` | 需浏览器；图片多为 webp；搜索相关度弱 |
| morui | 摩锐漫画 | 纯 requests（内联 chapterImages + CDN 拼接） | `/search/?q=` | 章节标题需清理"连载 "前缀；搜索页是更新流，相关度弱 |
| nicemh | 奈斯漫画 | Playwright（params.chapter_images + 网络响应回退） | `/search?q=` | 需浏览器；strict_expected_total=False（允许缺页） |
| xmanhua | xManga | 纯 requests（chapterimage.ashx + packer 解码） | `/search?title=` | 必须桌面 UA（覆写 headers）；标题为繁体 |

## 陷阱记录（踩过的坑）

- **xmanhua 移动端 UA 会返回移动版页面**（无桌面章节列表）——必须覆写 `headers()`。
- **manhuayu/nicemh 的 Playwright 沙箱**：沙箱环境启动 Chromium 需完整权限
  （命名管道），非代码问题。
- **nicemh 章节标题"开始阅读"等特殊文案**是站点自身数据，解析不属 bug。
- **搜索接口差异大**：部分站点（漫画鱼/摩锐）搜索相关度低，上层应侧重 exact
  命中或用 `add-url` 直接按详情 URL 添加。
