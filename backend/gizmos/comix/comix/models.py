"""轻量数据模型：适配器与调度层之间传递的数据结构。"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class ComicInfo:
    """站点搜索/详情页解析出的漫画信息。"""

    title: str
    detail_url: str
    site_comic_id: str = ""   # 站内漫画标识（slug/id）
    author: str = ""
    status: str = ""          # 连载状态
    cover_url: str = ""
    match: str = ""           # 搜索命中方式: exact/fuzzy（仅 search 使用）


@dataclass
class ChapterInfo:
    """单章节信息。"""

    chapter_no: int
    title: str
    url: str


@dataclass
class ComicDetail:
    """详情页解析结果：漫画信息 + 章节列表。"""

    comic: ComicInfo
    chapters: list[ChapterInfo] = field(default_factory=list)


@dataclass
class ChapterDownloadResult:
    """单章节下载结果。"""

    chapter_id: int
    chapter_no: int
    title: str
    ok: bool
    skipped: bool = False
    pages: int = 0
    rel_dir: str = ""
    error: str = ""
