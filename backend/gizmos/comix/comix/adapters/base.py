"""适配器基类：收敛所有爬虫通用逻辑（配置、稳定性、HTTP、下载）。

四个站点适配器只需继承本类并实现站点特有逻辑：
    search(name)                       -> list[ComicInfo]
    get_chapters(detail_url)           -> ComicDetail
    _fetch_chapter_image_urls(url)     -> (list[str], int)  站点解析图片链接
download_chapter 在基类中统一实现，站点通常无需覆盖。
"""
from __future__ import annotations

import os
from contextlib import contextmanager
from functools import cached_property
from typing import List, Tuple
from urllib.parse import unquote, urlsplit

import requests
from playwright.sync_api import sync_playwright
from requests.utils import get_environ_proxies, select_proxy

from .. import config
from ..models import ChapterInfo, ComicDetail, ComicInfo
from util.common import (
    create_http_session,
    download_pages_atomic,
    get_random_headers,
    random_sleep,
    require_public_url,
)


class BaseAdapter:
    # ---- 站点元信息（子类覆盖） ----
    code: str = "base"
    name: str = "Base"
    base_url: str = ""

    # ---- 稳定性配置（.env 提供默认值，子类可覆盖） ----
    page_timeout_sec: int = config.PAGE_TIMEOUT_SEC
    img_timeout_sec: int = config.IMG_TIMEOUT_SEC
    image_retry_times: int = config.IMAGE_RETRY_TIMES
    chapter_retry_times: int = config.CHAPTER_RETRY_TIMES
    max_workers: int = config.COMIX_MAX_WORKERS
    # 章节图片总数是否必须完整（True=缺图即失败重试，False=警告后继续）
    strict_expected_total: bool = True

    # ------------------------------------------------------------------
    # 子类必须实现的接口
    # ------------------------------------------------------------------
    def search(self, name: str) -> List[ComicInfo]:
        raise NotImplementedError(f"{self.code} 未实现 search()")

    def get_chapters(self, detail_url: str) -> ComicDetail:
        raise NotImplementedError(f"{self.code} 未实现 get_chapters()")

    def _fetch_chapter_image_urls(self, chapter_url: str) -> Tuple[List[str], int]:
        raise NotImplementedError(f"{self.code} 未实现 _fetch_chapter_image_urls()")

    # ------------------------------------------------------------------
    # 通用实现（站点通常无需覆盖）
    # ------------------------------------------------------------------
    def download_chapter(self, chapter: ChapterInfo, save_dir: str) -> list[dict]:
        with self.session() as session:
            return download_pages_atomic(
                save_dir=save_dir,
                chapter_url=chapter.url,
                fetch_image_urls=self._fetch_chapter_image_urls,
                session=session,
                img_timeout_sec=self.img_timeout_sec,
                image_retry_times=self.image_retry_times,
                strict_expected_total=self.strict_expected_total,
            )

    # ------------------------------------------------------------------
    # 通用工具
    # ------------------------------------------------------------------
    @cached_property
    def proxy(self) -> str | None:
        key = f"COMIX_{self.code.upper()}_ROUTE"
        value = os.getenv(key, "system").strip()
        if value.lower() in ("", "system"):
            value = select_proxy(self.base_url, get_environ_proxies(self.base_url)) or "direct"
        if value.lower() == "direct":
            return None
        parsed = urlsplit(value)
        if parsed.scheme not in ("http", "https") or not parsed.hostname:
            raise ValueError(f"{key} 需设为 system、direct 或 HTTP(S) 代理地址")
        return value

    def session(self):
        return create_http_session(self.proxy)

    @contextmanager
    def reader(self, chapter_url: str, timeout_ms: int):
        require_public_url(chapter_url)
        options = {"headless": True, "chromium_sandbox": True}
        if self.proxy:
            proxy = urlsplit(self.proxy)
            server = proxy.netloc.rsplit("@", 1)[-1]
            options["proxy"] = {"server": f"{proxy.scheme}://{server}"}
            if proxy.username is not None:
                options["proxy"]["username"] = unquote(proxy.username)
                options["proxy"]["password"] = unquote(proxy.password or "")
        else:
            options["args"] = ["--no-proxy-server"]

        def allow_public(route):
            try:
                require_public_url(route.request.url)
            except (ValueError, requests.RequestException):
                route.abort()
            else:
                route.continue_()

        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(**options)
            try:
                context = browser.new_context(service_workers="block")
                context.route("http*://**/*", allow_public)
                page = context.new_page()
                response = page.goto(chapter_url, wait_until="domcontentloaded", timeout=timeout_ms)
                if response is None or not response.ok:
                    status = response.status if response else "无响应"
                    raise RuntimeError(f"{self.code} 章节页请求失败（{status}）")
                require_public_url(page.url)
                yield page
            finally:
                browser.close()

    def headers(self, referer: str = "") -> dict:
        """生成随机请求头（可附带 Referer）。"""
        h = get_random_headers()
        if referer:
            h["Referer"] = referer
        return h

    def get(self, url: str, timeout: int | None = None, referer: str = "", **kw):
        try:
            with self.session() as session:
                resp = session.get(
                    url, headers=self.headers(referer),
                    timeout=timeout or self.page_timeout_sec, **kw,
                )
                resp.raise_for_status()
                return resp
        except requests.RequestException as exc:
            raise RuntimeError(f"{self.code} 页面请求失败: {exc}") from exc

    def sleep(self) -> None:
        """随机小睡，降低短时高频请求特征。"""
        random_sleep(1.0, 0.8)

    # ------------------------------------------------------------------
    # 常用辅助
    # ------------------------------------------------------------------
    def normalize_match(self, candidates: List[ComicInfo], name: str) -> List[ComicInfo]:
        """给搜索候选标注命中方式：标题完全一致为 exact，否则 fuzzy。"""
        import re as _re

        def norm(s: str) -> str:
            return _re.sub(r"[\s\-—_|/\\:：()（）\[\]【】.。·、，,！!？?~～*＊]", "", s).lower()

        target = norm(name)
        for c in candidates:
            c.match = "exact" if norm(c.title) == target else "fuzzy"
        return candidates

    # 封面候选 xpath（按站点覆盖；未命中时回退 og:image / data-src / 首图）
    cover_xpaths: List[str] = [
        '//meta[@property="og:image"]/@content',
        '//*[contains(@class,"book-cover")]//img/@src',
        '//*[contains(@class,"detail-info-cover")]//img/@src',
        '//*[contains(@class,"cover")]//img/@src',
        '//*[contains(@class,"detail")]//img/@src',
    ]

    def extract_cover_url(self, root, page_url: str) -> str:
        """从详情页 DOM 解析封面地址（绝对化）；解析不到返回空串。

        cover_url 缺失会导致客户端无封面可显示（必须显式解析，不依赖客户端猜测）。
        """
        for xp in self.cover_xpaths:
            for raw in root.xpath(xp):
                value = (raw or "").strip()
                if not value or value.startswith("data:"):
                    continue
                if value.endswith(".svg"):
                    continue
                return self._absolutize(value, page_url)
        # 回退：data-src 懒加载属性
        for raw in root.xpath("//img/@data-src"):
            value = (raw or "").strip()
            if value and not value.startswith("data:"):
                return self._absolutize(value, page_url)
        return ""

    def _absolutize(self, url: str, page_url: str) -> str:
        from urllib.parse import urljoin
        if url.startswith("//"):
            return "https:" + url
        return urljoin(page_url or self.base_url, url)
