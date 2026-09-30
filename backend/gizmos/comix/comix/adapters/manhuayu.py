"""漫画鱼适配器（https://www.manhuayu88.com/）。

章节图片需浏览器执行解密脚本，使用 Playwright 读取 window.params.chapter_images，
失败时回退滚动采集。搜索为服务端渲染，纯 requests 即可。
"""
from __future__ import annotations

import re
import time
from typing import List, Tuple
from urllib.parse import quote, urljoin

from lxml import etree
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
from playwright.sync_api import sync_playwright

from ..models import ChapterInfo, ComicDetail, ComicInfo
from .base import PLAYWRIGHT_OPTIONS, BaseAdapter
from util.common import run_with_timeout

# 稳定性配置（站点特有，覆盖 .env 默认）
PAGE_TIMEOUT_MS = 60000
SCROLL_ROUNDS = 60
# 单次 Playwright 抓取操作的整体超时（防止驱动/浏览器启动失败时挂死进程）
PLAYWRIGHT_OP_TIMEOUT_SEC = 300

# 详情页链接形如 /8375（数字 id）
_DETAIL_RE = re.compile(r"/(\d+)/?$")


class ManhuayuAdapter(BaseAdapter):
    code = "manhuayu"
    name = "漫画鱼"
    base_url = "https://www.manhuayu88.com/"
    strict_expected_total = True
    # 详情页封面在 div.metas-image 内（站点 logo/占位图在前，必须精确选择）
    cover_xpaths = ['//div[contains(@class,"metas-image")]//img/@src']

    # ------------------------------------------------------------------
    # search
    # ------------------------------------------------------------------
    def search(self, name: str) -> List[ComicInfo]:
        url = f"{self.base_url}search/{quote(name)}/"
        root = etree.HTML(self.get(url).text)

        results: List[ComicInfo] = []
        seen: set[str] = set()
        for a in root.xpath("//a[@href]"):
            m = _DETAIL_RE.search(a.get("href", ""))
            if not m or len(m.group(1)) < 3:  # 排除翻页等短数字链接
                continue
            cid = m.group(1)
            if cid in seen:
                continue
            txt = "".join(a.xpath(".//text()")).strip()
            if not txt:
                continue
            seen.add(cid)
            results.append(
                ComicInfo(
                    title=txt,
                    detail_url=urljoin(self.base_url, f"/{cid}"),
                    site_comic_id=cid,
                )
            )
        return self.normalize_match(results, name)

    # ------------------------------------------------------------------
    # get_chapters
    # ------------------------------------------------------------------
    def get_chapters(self, detail_url: str) -> ComicDetail:
        root = etree.HTML(self.get(detail_url, timeout=self.img_timeout_sec).text)

        comic_name_raw = root.xpath('//*[@id="content-container"]/div[1]/ul/li[3]/span/text()')
        if not comic_name_raw:
            raise RuntimeError("未能解析漫画名称，请检查页面结构是否变更")
        comic_name = comic_name_raw[0].strip()

        chapters: List[ChapterInfo] = []
        for i, li in enumerate(
            root.xpath('//*[@id="content-container"]/div[3]/div[2]/ul/li'), start=1
        ):
            href = li.xpath("./a/@href")
            txt = li.xpath("./a/text()")
            if not href or not txt:
                continue
            chapters.append(
                ChapterInfo(
                    chapter_no=i,
                    title=txt[0].strip(),
                    url=urljoin(self.base_url, href[0]),
                )
            )
        if not chapters:
            raise RuntimeError("未解析到章节列表，请检查页面结构是否变更")

        m = _DETAIL_RE.search(detail_url)
        comic = ComicInfo(
            title=comic_name,
            detail_url=detail_url,
            site_comic_id=m.group(1) if m else "",
            cover_url=self.extract_cover_url(root, detail_url),
        )
        return ComicDetail(comic=comic, chapters=chapters)

    # ------------------------------------------------------------------
    # 章节图片链接（Playwright）
    # ------------------------------------------------------------------
    def _collect_image_urls(self, page) -> Tuple[List[str], int]:
        """滚动采集：优先取 .chapter-image 容器的 data-original。"""
        page.wait_for_selector(".chapter-images .chapter-image", timeout=20000)
        time.sleep(1)
        expected_total = page.eval_on_selector_all(
            ".chapter-images .chapter-image", "els => els.length"
        )

        img_urls: List[str] = []
        last_count = 0
        stable_rounds = 0
        for _ in range(SCROLL_ROUNDS):
            fetched = page.eval_on_selector_all(
                ".chapter-images .chapter-image",
                """
                els => els.map(el => {
                  const img = el.querySelector('img');
                  return el.getAttribute('data-original')
                    || el.getAttribute('data-src')
                    || el.getAttribute('data-echo')
                    || (img && (img.getAttribute('src')
                      || img.getAttribute('data-src')
                      || img.getAttribute('data-original')
                      || img.getAttribute('data-echo')));
                }).filter(Boolean)
                """,
            )
            cleaned = [u.strip() for u in fetched if isinstance(u, str) and u.strip()]
            cleaned = [u for u in cleaned if not u.startswith("data:")]
            cleaned = list(dict.fromkeys(cleaned))

            if len(cleaned) <= last_count:
                stable_rounds += 1
            else:
                stable_rounds = 0
            img_urls = cleaned
            last_count = len(img_urls)

            if expected_total > 0:
                if len(img_urls) >= expected_total and stable_rounds >= 1:
                    break
            elif img_urls and stable_rounds >= 5:
                break

            page.mouse.wheel(0, 2200)
            time.sleep(0.6)

        # 安全网：数量不足时从页面 HTML 补充 mhpic.net 图片
        if expected_total > 0 and len(img_urls) < expected_total:
            html = page.content()
            html_urls = re.findall(
                r"https?://[^\"'\s>]*mhpic\.net[^\"'\s>]+\.(?:webp|jpg|jpeg|png)",
                html,
                flags=re.IGNORECASE,
            )
            html_urls = list(dict.fromkeys(html_urls))
            if len(html_urls) >= expected_total:
                img_urls = html_urls
        return img_urls, expected_total

    def _fetch_chapter_image_urls(self, chapter_url: str) -> Tuple[List[str], int]:
        """优先读取解密后的 window.params.chapter_images，失败回退滚动采集。

        整个抓取操作由 run_with_timeout 保护：playwright 驱动/浏览器启动失败时
        实测会挂死（进程永不退出），超时后立即失败并跳过重试（环境性故障）。
        """
        def _attempt() -> Tuple[List[str], int]:
            with sync_playwright() as p:
                browser = p.chromium.launch(**PLAYWRIGHT_OPTIONS)
                page = browser.new_page()
                try:
                    page.goto(chapter_url, wait_until="domcontentloaded", timeout=PAGE_TIMEOUT_MS)
                    self.sleep()

                    params_data = None
                    for _ in range(30):
                        try:
                            params_data = page.evaluate(
                                "() => { const o = window.params;"
                                " if (!o || !Array.isArray(o.chapter_images)) return null;"
                                " return {list: o.chapter_images.slice(), domain: o.images_domain}; }"
                            )
                        except Exception:
                            params_data = None
                        if params_data and params_data.get("list"):
                            break
                        time.sleep(0.5)

                    if params_data and params_data.get("list"):
                        domain = (params_data.get("domain") or "").rstrip("/")
                        urls = [
                            u if u.startswith("http") else f"{domain}/{u.lstrip('/')}"
                            for u in params_data["list"]
                            if isinstance(u, str) and u.strip()
                        ]
                        if urls:
                            return urls, len(urls)

                    img_urls, expected_total = self._collect_image_urls(page)
                    if not img_urls:
                        raise RuntimeError("未提取到任何图片链接")
                    return img_urls, expected_total
                finally:
                    browser.close()

        last_error = None
        for _ in range(self.chapter_retry_times):
            try:
                return run_with_timeout(_attempt, PLAYWRIGHT_OP_TIMEOUT_SEC)
            except PlaywrightTimeoutError as exc:
                last_error = RuntimeError(f"页面加载超时: {exc}")
            except RuntimeError as exc:
                if "疑似卡死" in str(exc):
                    raise  # 环境性卡死：重试无意义，立即失败
                last_error = exc
            except Exception as exc:
                last_error = exc
            self.sleep()
        raise RuntimeError(f"章节页面抓取失败: {last_error}")
