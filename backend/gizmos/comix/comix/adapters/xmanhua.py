"""xManga 适配器（https://www.xmanhua.net/）。

纯 requests 实现：
- 该站对移动 UA 返回移动版页面，必须固定桌面 UA；
- 章节图片接口 chapterimage.ashx 返回 Dean Edwards packer 混淆 JS，
  需在纯 Python 中解码（无需浏览器执行）；
- 搜索端点为 /search?title={关键词}（见 search.js），需桌面 UA。
"""
from __future__ import annotations

import re
from typing import List, Tuple
from urllib.parse import quote, urljoin

from fake_useragent import UserAgent
from lxml import etree

from ..models import ChapterInfo, ComicDetail, ComicInfo
from .base import BaseAdapter

# 详情页链接形如 /335xm/
_DETAIL_RE = re.compile(r"/(\d+xm)/?$")

# 该站固定桌面 UA，避免命中移动版页面
_DESKTOP_UA = UserAgent(platforms=["desktop"])


class XmanhuaAdapter(BaseAdapter):
    code = "xmanhua"
    name = "xManga"
    base_url = "https://www.xmanhua.net/"
    strict_expected_total = True

    def headers(self, referer: str = "") -> dict:
        h = super().headers(referer)
        h["User-Agent"] = _DESKTOP_UA.random
        return h

    # ------------------------------------------------------------------
    # search
    # ------------------------------------------------------------------
    def search(self, name: str) -> List[ComicInfo]:
        url = f"{self.base_url}search?title={quote(name)}"
        root = etree.HTML(self.get(url).text)

        results: List[ComicInfo] = []
        seen: set[str] = set()
        for a in root.xpath("//a[@href]"):
            m = _DETAIL_RE.search(a.get("href", ""))
            if not m:
                continue
            cid = m.group(1)
            if cid in seen:
                continue
            txt = "".join(a.xpath(".//text()")).strip()
            title = txt or (a.get("title") or "").strip()
            if not title:
                continue
            seen.add(cid)
            results.append(
                ComicInfo(
                    title=title,
                    detail_url=urljoin(self.base_url, f"/{cid}/"),
                    site_comic_id=cid,
                )
            )
        return self.normalize_match(results, name)

    # ------------------------------------------------------------------
    # get_chapters
    # ------------------------------------------------------------------
    def get_chapters(self, detail_url: str) -> ComicDetail:
        root = etree.HTML(self.get(detail_url).text)

        comic_name_raw = root.xpath('//p[contains(@class, "detail-info-title")]/text()')
        if not comic_name_raw:
            raise RuntimeError("未能解析漫画名称，请检查页面结构是否变更")
        comic_name = comic_name_raw[0].strip()

        raw: list[Tuple[str, str]] = []
        for link in root.xpath('//div[contains(@class, "detail-list-form-con")]/a'):
            href = link.get("href")
            if not href:
                continue
            title = "".join(link.xpath("./text()")).strip()
            raw.append((title, urljoin(self.base_url, href)))

        # 站点列表默认倒序（最新在前），反转为阅读顺序（从旧到新）
        raw.reverse()
        chapters = [
            ChapterInfo(chapter_no=i, title=title or f"第{i}話", url=url)
            for i, (title, url) in enumerate(raw, start=1)
        ]
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
    # packer 反混淆（站点特有，纯 Python 实现）
    # ------------------------------------------------------------------
    _PACKER_ARGS_RE = re.compile(
        r"\('((?:[^'\\]|\\.)*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*"
        r"'((?:[^'\\]|\\.)*)'(?:\s*\.split\(\s*'\|'\s*\))?\s*,",
        re.DOTALL,
    )

    def _base36(self, num: int) -> str:
        digits = "0123456789abcdefghijklmnopqrstuvwxyz"
        return digits[num] if num < 36 else self._base36(num // 36) + digits[num % 36]

    def _packer_token(self, num: int, base: int) -> str:
        head = "" if num < base else self._packer_token(num // base, base)
        tail = chr(num % base + 29) if num % base > 35 else self._base36(num % base)
        return head + tail

    def decode_packer(self, js: str) -> str | None:
        match = self._PACKER_ARGS_RE.search(js)
        if not match:
            return None
        body, base, count, keys_raw = match.group(1), int(match.group(2)), int(match.group(3)), match.group(4)
        keys = keys_raw.split("|")

        mapping = {}
        for i in range(count):
            token = self._packer_token(i, base)
            mapping[token] = keys[i] if i < len(keys) and keys[i] else token
        decoded = re.sub(r"\b\w+\b", lambda mo: mapping.get(mo.group(0), mo.group(0)), body)
        return decoded.replace("\\'", "'")

    # ------------------------------------------------------------------
    # 章节图片链接（纯 requests + ashx 接口）
    # ------------------------------------------------------------------
    def _extract_js_var(self, html: str, name: str) -> str:
        match = re.search(
            name + r'\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^;\s]+))',
            html,
        )
        if not match:
            raise RuntimeError(f"未能解析变量 {name}，页面结构可能已变更")
        return match.group(1) or match.group(2) or match.group(3)

    def _parse_ashx_response(self, text: str) -> list[str]:
        decoded = self.decode_packer(text)
        if not decoded:
            direct = re.findall(
                r"https?://[^\"'\s\\]+?\.(?:jpg|jpeg|png|webp)",
                text,
                flags=re.IGNORECASE,
            )
            if direct:
                return direct
            raise RuntimeError("chapterimage.ashx 响应无法解析")

        pix = re.search(r'pix\s*=\s*"([^"]+)"', decoded)
        key = re.search(r"key\s*=\s*'([^']+)'", decoded)
        cid = re.search(r"cid\s*=\s*(\d+)", decoded)
        pvalue = re.search(r"pvalue\s*=\s*\[([^\]]*)\]", decoded)
        if not (pix and key and cid and pvalue):
            raise RuntimeError("chapterimage.ashx 返回内容缺少关键字段")

        parts = re.findall(r'"([^"]+)"', pvalue.group(1))
        if not parts:
            raise RuntimeError("chapterimage.ashx 未包含图片路径")
        return [
            f"{pix.group(1)}{part}?cid={cid.group(1)}&key={key.group(1)}&uk="
            for part in parts
        ]

    def _fetch_ashx_page(self, session, chapter_url: str, cid: str, mid: str,
                        page: int, sign: str, dt: str) -> list[str]:
        params = {
            "cid": cid, "page": page, "key": "",
            "_cid": cid, "_mid": mid, "_dt": dt, "_sign": sign,
        }
        url = f"{self.base_url}m{cid}/chapterimage.ashx"
        resp = session.get(
            url,
            params=params,
            headers={**self.headers(), "Referer": chapter_url, "X-Requested-With": "XMLHttpRequest"},
            timeout=self.img_timeout_sec,
            verify=False,
        )
        resp.raise_for_status()
        return self._parse_ashx_response(resp.text)

    def _fetch_chapter_image_urls(self, chapter_url: str) -> Tuple[List[str], int]:
        session = self.session()
        html = session.get(
            chapter_url, headers=self.headers(), timeout=self.img_timeout_sec, verify=False
        ).text

        cid = self._extract_js_var(html, "XMANHUA_CID")
        mid = self._extract_js_var(html, "XMANHUA_MID")
        image_count = int(self._extract_js_var(html, "XMANHUA_IMAGE_COUNT"))
        sign = self._extract_js_var(html, "XMANHUA_VIEWSIGN")
        dt = self._extract_js_var(html, "XMANHUA_VIEWSIGN_DT")

        # 接口按页返回滑动窗口，"试看版"章节顺序会错乱，按文件名页码收集去重
        urls_map: dict[int, str] = {}
        for page in range(1, image_count + 1):
            for url in self._fetch_ashx_page(session, chapter_url, cid, mid, page, sign, dt):
                matched = re.search(r"/(\d+)_", url)
                if not matched:
                    continue
                page_no = int(matched.group(1))
                if 1 <= page_no <= image_count:
                    urls_map.setdefault(page_no, url)
            if len(urls_map) >= image_count:
                break
            if page % 10 == 0:
                self.sleep()

        if len(urls_map) < image_count:
            missing = [i for i in range(1, image_count + 1) if i not in urls_map]
            raise RuntimeError(f"图片收集不完整，缺失页: {missing}")
        return [urls_map[i] for i in range(1, image_count + 1)], image_count
