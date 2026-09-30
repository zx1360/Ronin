"""奈斯漫画适配器（https://www.nicemh.com/）。

章节图片需浏览器执行解密脚本，使用 Playwright 读取 window.params.chapter_images
（images_hosts 为域名列表），失败时回退网络响应采集。搜索为服务端渲染。
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

PAGE_TIMEOUT_MS = 60000
SCROLL_ROUNDS = 60
# 单次 Playwright 抓取操作的整体超时（防止驱动/浏览器启动失败时挂死进程）
PLAYWRIGHT_OP_TIMEOUT_SEC = 300

# 详情页链接形如 /manhua/{slug}
_DETAIL_RE = re.compile(r"/manhua/([^/?#]+)")


class NicemhAdapter(BaseAdapter):
    code = "nicemh"
    name = "奈斯漫画"
    base_url = "https://www.nicemh.com/"
    strict_expected_total = False  # 该站偶尔缺图，缺页仅警告不中断

    # ------------------------------------------------------------------
    # search
    # ------------------------------------------------------------------
    def search(self, name: str) -> List[ComicInfo]:
        url = f"{self.base_url}search?q={quote(name)}"
        root = etree.HTML(self.get(url).text)

        results: List[ComicInfo] = []
        seen: set[str] = set()
        for a in root.xpath("//a[@href]"):
            m = _DETAIL_RE.search(a.get("href", ""))
            if not m:
                continue
            slug = m.group(1)
            if slug in seen:
                continue
            txt = "".join(a.xpath(".//text()")).strip()
            if not txt:
                continue
            seen.add(slug)
            results.append(
                ComicInfo(
                    title=txt,
                    detail_url=urljoin(self.base_url, f"/manhua/{slug}"),
                    site_comic_id=slug,
                )
            )
        return self.normalize_match(results, name)

    # ------------------------------------------------------------------
    # get_chapters
    # ------------------------------------------------------------------
    def _extract_comic_slug(self, detail_url: str) -> str:
        match = re.search(r"/manhua/([^/?#]+)", detail_url)
        if not match:
            raise RuntimeError("详情页链接格式不正确，无法提取漫画标识")
        return match.group(1)

    def get_chapters(self, detail_url: str) -> ComicDetail:
        root = etree.HTML(self.get(detail_url, timeout=self.img_timeout_sec).text)
        comic_slug = self._extract_comic_slug(detail_url)

        # 站名/别名清洗后取最可靠的漫画名
        candidates = root.xpath(
            "//h2/text() | //h1/text() | //meta[@property='og:title']/@content | //title/text()"
        )
        comic_name = ""
        for raw in candidates:
            if not isinstance(raw, str):
                continue
            text = raw.strip()
            if not text:
                continue
            text = re.sub(r"\s+", " ", text)
            text = re.split(r"[-|_|｜]", text)[0].strip()
            if text and text not in {"奈斯漫画", comic_slug}:
                comic_name = text
                break
        if not comic_name:
            raise RuntimeError("未能解析漫画名称，请检查页面结构是否变更")

        chapter_map: dict[int, ChapterInfo] = {}
        for a in root.xpath("//a[@href]"):
            href = a.get("href", "").strip()
            text = "".join(a.xpath(".//text()")).strip()
            m = re.search(r"/manhua/([^/]+)/([0-9]+)\.html$", href)
            if not m or m.group(1) != comic_slug:
                continue
            no = int(m.group(2))
            chapter_map.setdefault(
                no,
                ChapterInfo(
                    chapter_no=no,
                    title=text or f"第{no}话",
                    url=urljoin(self.base_url, href),
                ),
            )
        chapters = [chapter_map[no] for no in sorted(chapter_map)]
        if not chapters:
            raise RuntimeError("未解析到章节列表，请检查页面结构是否变更")

        comic = ComicInfo(
            title=comic_name,
            detail_url=detail_url,
            site_comic_id=comic_slug,
            cover_url=self.extract_cover_url(root, detail_url),
        )
        return ComicDetail(comic=comic, chapters=chapters)

    # ------------------------------------------------------------------
    # 章节图片链接（Playwright）
    # ------------------------------------------------------------------
    def _collect_image_urls(self, page) -> Tuple[List[str], int]:
        """回退采集：DOM + 网络响应中按页码排序的真实图片 URL。"""
        page.wait_for_selector(".chapter-images .chapter-image", timeout=20000)
        time.sleep(1)
        expected_total = page.eval_on_selector_all(
            ".chapter-images .chapter-image", "els => els.length"
        )

        network_urls: List[str] = []
        page.on("response", lambda resp: network_urls.append(resp.url))

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
            cleaned = [
                u.strip()
                for u in fetched
                if isinstance(u, str) and u.strip()
                and not u.startswith(("data:", "blob:"))
                and "/scomic/" in u.lower()
                and re.search(r"\.(?:webp|jpg|jpeg|png)(?:\?.*)?$", u, re.IGNORECASE)
            ]
            cleaned = list(dict.fromkeys(cleaned))
            if len(cleaned) <= last_count:
                stable_rounds += 1
            else:
                stable_rounds = 0
            img_urls = cleaned
            last_count = len(img_urls)

            if expected_total > 0:
                if len(img_urls) >= expected_total or stable_rounds >= 3:
                    break
            elif img_urls and stable_rounds >= 5:
                break
            page.mouse.wheel(0, 2200)
            time.sleep(0.6)

        # 网络响应采集的真实图片 URL 按页码排序，优先返回
        cleaned_net = [
            u
            for u in dict.fromkeys(network_urls)
            if isinstance(u, str)
            and not u.startswith(("data:", "blob:"))
            and "/scomic/" in u.lower()
            and re.search(r"\.(?:webp|jpg|jpeg|png)(?:\?.*)?$", u, re.IGNORECASE)
        ]

        def _page_key(u: str) -> int:
            m = re.search(r"/(\d+)\.(?:webp|jpg|jpeg|png)", u)
            return int(m.group(1)) if m else 10**9

        cleaned_net.sort(key=_page_key)
        if cleaned_net:
            return cleaned_net, len(cleaned_net)
        return img_urls, expected_total

    def _fetch_chapter_image_urls(self, chapter_url: str) -> Tuple[List[str], int]:
        """优先读取解密后的 window.params.chapter_images，失败回退采集。

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
                                " return {list: o.chapter_images.slice(), domain: o.images_hosts}; }"
                            )
                        except Exception:
                            params_data = None
                        if params_data and params_data.get("list"):
                            break
                        time.sleep(0.5)

                    if params_data and params_data.get("list"):
                        domain_val = params_data.get("domain")
                        if isinstance(domain_val, list):
                            domain_val = domain_val[0] if domain_val else ""
                        domain = (domain_val or "https://s2.bzcdn.net").rstrip("/")
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
