"""适配器基类：收敛所有爬虫通用逻辑（配置、稳定性、HTTP、下载）。

四个站点适配器只需继承本类并实现站点特有逻辑：
    search(name)                       -> list[ComicInfo]
    get_chapters(detail_url)           -> ComicDetail
    _fetch_chapter_image_urls(url)     -> (list[str], int)  站点解析图片链接
download_chapter 在基类中统一实现，站点通常无需覆盖。
"""
from __future__ import annotations

import random
from typing import List, Tuple

from .. import config
from ..models import ChapterInfo, ComicDetail, ComicInfo
from util.common import (
    create_http_session,
    download_pages_atomic,
    get_random_headers,
    init_requests_warnings,
    random_sleep,
)

# 通用 Playwright 启动参数（需要浏览器的站点复用）
PLAYWRIGHT_OPTIONS = {
    "headless": True,
    "args": [
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--disable-logging",
        "--log-level=3",
        "--disable-extensions",
        "--ignore-certificate-errors",
    ],
}


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

    def __init__(self) -> None:
        init_requests_warnings()

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
    def download_chapter(self, chapter: ChapterInfo, save_dir: str) -> Tuple[bool, int, str]:
        """下载单章全部图片到 save_dir（原子化，失败不留残目录）。"""
        ok, pages, error = download_pages_atomic(
            save_dir=save_dir,
            chapter_url=chapter.url,
            fetch_image_urls=self._fetch_chapter_image_urls,
            img_timeout_sec=self.img_timeout_sec,
            image_retry_times=self.image_retry_times,
            strict_expected_total=self.strict_expected_total,
            base_url=self.base_url,
        )
        return ok, pages, error

    # ------------------------------------------------------------------
    # 通用工具
    # ------------------------------------------------------------------
    def session(self):
        """创建带重试策略的 requests 会话。"""
        return create_http_session()

    def headers(self, referer: str = "") -> dict:
        """生成随机请求头（可附带 Referer）。"""
        h = get_random_headers()
        if referer:
            h["Referer"] = referer
        return h

    def get(self, url: str, timeout: int | None = None, referer: str = "", **kw):
        """GET 请求快捷方法（带重试会话与随机头）。"""
        session = self.session()
        resp = session.get(
            url,
            headers=self.headers(referer),
            timeout=timeout or self.page_timeout_sec,
            verify=False,
            **kw,
        )
        resp.raise_for_status()
        return resp

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
