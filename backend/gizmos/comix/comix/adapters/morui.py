"""摩锐漫画适配器（https://www.morui.com/）。

章节图片地址直接内联在页面 JS 变量 chapterImages 中，纯 requests 即可；
图片可能是相对路径，需用页面声明的 chapterImageHost 或兜底 CDN 拼接。
"""
from __future__ import annotations

import json
import re
from typing import List, Tuple
from urllib.parse import quote, urljoin

from lxml import etree

from ..models import ChapterInfo, ComicDetail, ComicInfo
from .base import BaseAdapter

# 详情页链接形如 /comic/1165/
_DETAIL_RE = re.compile(r"/comic/(\d+)/?$")

# 相对路径图片的兜底 CDN 域名（页面未声明 chapterImageHost 时使用）
IMG_CDN_FALLBACK = "http://mrcover.alltucdn.cc"


class MoruiAdapter(BaseAdapter):
    code = "morui"
    name = "摩锐漫画"
    base_url = "https://www.morui.com/"
    strict_expected_total = True
    # 详情页封面在 p.cover 内（推荐位封面也在 a.cover 下，避免误取）
    cover_xpaths = ['//p[contains(@class,"cover")]//img/@src']

    # ------------------------------------------------------------------
    # search
    # ------------------------------------------------------------------
    def search(self, name: str) -> List[ComicInfo]:
        url = f"{self.base_url}search/?q={quote(name)}"
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
            # 搜索页是"最近更新"流，同一漫画多次出现；标题取 title 属性
            title = (a.get("title") or "").strip()
            if not title:
                img = a.xpath(".//img")
                if img:
                    title = (img[0].get("alt") or "").strip()
            if not title:
                continue
            seen.add(cid)
            results.append(
                ComicInfo(
                    title=title,
                    detail_url=urljoin(self.base_url, f"/comic/{cid}/"),
                    site_comic_id=cid,
                )
            )
        return self.normalize_match(results, name)

    # ------------------------------------------------------------------
    # get_chapters（支持多章节分区：分区合并为一条顺序章节列表）
    # ------------------------------------------------------------------
    def get_chapters(self, detail_url: str) -> ComicDetail:
        root = etree.HTML(self.get(detail_url).text)

        comic_name_raw = root.xpath("//div[contains(@class,'book-title')]//h1//span/text()")
        if not comic_name_raw:
            comic_name_raw = root.xpath("//h1//span/text()")
        if not comic_name_raw:
            raise RuntimeError("未能解析漫画名称，请检查页面结构是否变更")
        comic_name = comic_name_raw[0].strip()

        sections = root.xpath("//div[contains(@class,'comic-chapters')]")
        if not sections:
            sections = [root]
        multiple = len(sections) > 1

        chapters: List[ChapterInfo] = []
        no = 0
        for section in sections:
            links = section.xpath(".//div[contains(@class,'chapter-body')]//a")
            if not links and section is root:
                links = root.xpath("//div[contains(@class,'chapter-body')]//a")
            if not links:
                continue

            # 分区标题（多分区时作为章节标题前缀，便于区分正篇/番外）
            caption = ""
            if multiple:
                parts = section.xpath(
                    ".//div[contains(@class,'caption')]//span/text() | "
                    ".//div[contains(@class,'caption')]/text()"
                )
                caption = "".join(p.strip() for p in parts if isinstance(p, str)).strip()

            for link in links:
                href = link.xpath("./@href")
                txt = link.xpath(".//span/text()")
                if not href or not txt:
                    continue
                no += 1
                title = txt[0].strip()
                # 清理"连载/完结"等状态前缀，只留章节名
                for prefix in ("连载 ", "完结 ", "番外 ", "特别篇 "):
                    if title.startswith(prefix):
                        title = title[len(prefix):]
                        break
                if caption and caption != "章节":
                    title = f"{caption} {title}"
                chapters.append(
                    ChapterInfo(
                        chapter_no=no,
                        title=title,
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
    # 章节图片链接（纯 requests）
    # ------------------------------------------------------------------
    def _extract_chapter_image_host(self, html: str) -> str | None:
        match = re.search(r'var\s+chapterImageHost\s*=\s*"([^"]*)"', html)
        if match and match.group(1).strip():
            return match.group(1).strip()
        return None

    def _resolve_image_urls(self, raw_urls: List[str], image_host: str) -> List[str]:
        resolved: List[str] = []
        for u in raw_urls:
            if re.match(r"^(https?:)?//", u):
                resolved.append(u)
            else:
                resolved.append(image_host.rstrip("/") + "/" + u.lstrip("/"))
        return resolved

    def _fetch_chapter_image_urls(self, chapter_url: str) -> Tuple[List[str], int]:
        last_error = None
        for _ in range(self.chapter_retry_times):
            try:
                html = self.get(chapter_url).text
                match = re.search(r"var\s+chapterImages\s*=\s*(\[.*?\])\s*;", html, re.S)
                if not match:
                    raise RuntimeError("页面中未找到 chapterImages 变量")
                try:
                    image_list = json.loads(match.group(1))
                except json.JSONDecodeError:
                    raise RuntimeError("chapterImages 解析失败")
                img_urls = [
                    u.strip()
                    for u in image_list
                    if isinstance(u, str) and u.strip() and not u.startswith("data:")
                ]
                if not img_urls:
                    raise RuntimeError("未提取到任何图片链接")

                if any(not re.match(r"^(https?:)?//", u) for u in img_urls):
                    image_host = self._extract_chapter_image_host(html) or IMG_CDN_FALLBACK
                    img_urls = self._resolve_image_urls(img_urls, image_host)
                return img_urls, len(img_urls)
            except Exception as exc:
                last_error = exc
                self.sleep()
        raise RuntimeError(f"章节页面抓取失败: {last_error}")
