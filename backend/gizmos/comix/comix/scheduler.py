"""下载调度：搜索候选、选源、增量下载、更新检查、删除。

无状态设计：每个函数独立完成一次操作并返回可 JSON 序列化的 dict，
不保存任何会话状态；CLI 与后续 Go HTTP 服务都通过本层调用。
"""
from __future__ import annotations

import shutil
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import asdict
from pathlib import Path
from typing import Optional

from . import config, db
from .adapters import all_adapters, get_adapter
from .models import ChapterInfo
from util.common import QUIET, scan_images


def _storage_path(rel_dir: str) -> str:
    """将 DB 中的 rel_dir（形如 `comics/{comic_id}/{chapter_id}`）解析为存储根下的绝对路径。

    存储根由 .env 的 COMIC_STORAGE_ROOT 指定（如 Ronin 的 backend/static/comics），
    rel_dir 的 `comics/` 前缀对应存储根下的目录（与 /static 服务路径保持一致）。
    """
    return str(config.storage_path(rel_dir))


class CandidateChoiceRequired(Exception):
    """多候选时未指定选择，携带候选列表供上层展示/选择。"""

    def __init__(self, candidates: list[dict]):
        self.candidates = candidates
        super().__init__(f"存在 {len(candidates)} 个候选，需要指定 --pick 或 --site")


class NotFound(Exception):
    """未找到匹配结果。"""


# ---------------------------------------------------------------------------
# 孤儿回收（进程被中断后的自愈）
# ---------------------------------------------------------------------------

def _cleanup_downloading_dirs(rel_dir: str) -> int:
    """删除某漫画目录下遗留的 *.downloading 临时目录，返回清理数量。

    下载进程被 kill/断电时，.downloading 目录可能残留（图片下载到一半，
    未提交未清理）。每次下载开始前调用，保证不会读到半截章节。
    """
    comic_root = Path(_storage_path(rel_dir))
    if not comic_root.is_dir():
        return 0
    count = 0
    for child in comic_root.iterdir():
        if child.is_dir() and child.name.endswith(".downloading"):
            shutil.rmtree(child, ignore_errors=True)
            count += 1
    return count


def cleanup() -> dict:
    """全局孤儿回收（CLI clean 命令 / Go 服务维护接口）：
    - 回收全部 running 残留任务（标记 failed/进程中断）
    - 删除存储根下全部 *.downloading 残留目录
    """
    tasks = db.recover_running_tasks()
    dirs = 0
    root = Path(config.COMIC_STORAGE_ROOT)
    if root.is_dir():
        for child in root.rglob("*.downloading"):
            if child.is_dir():
                shutil.rmtree(child, ignore_errors=True)
                dirs += 1
    return {"recovered_tasks": tasks, "removed_temp_dirs": dirs}


# ---------------------------------------------------------------------------
# 站点注册
# ---------------------------------------------------------------------------

def ensure_sites() -> None:
    """将全部适配器注册进 site 表（幂等）。"""
    for ad in all_adapters():
        db.register_site(ad.code, ad.name, ad.base_url)


# ---------------------------------------------------------------------------
# 搜索与候选
# ---------------------------------------------------------------------------

def search_all(name: str, per_site: int = 10) -> dict:
    """全站搜索，返回候选列表与各站错误信息。

    每站候选按命中方式排序（完全同名优先）并截断，避免搜索结果过长。
    """
    ensure_sites()
    candidates: list[dict] = []
    errors: dict[str, str] = {}
    for ad in all_adapters():
        try:
            infos = ad.search(name)
            infos.sort(key=lambda i: 0 if i.match == "exact" else 1)
            for info in infos[:per_site]:
                item = asdict(info)
                item["site"] = ad.code
                item["site_name"] = ad.name
                candidates.append(item)
        except Exception as exc:
            errors[ad.code] = f"{type(exc).__name__}: {exc}"
    return {"candidates": candidates, "errors": errors}


def _resolve_candidate(
    candidates: list[dict], site_code: Optional[str], pick: Optional[int]
) -> dict:
    """从候选列表解析用户选择。"""
    if not candidates:
        raise NotFound("未找到匹配的漫画")
    if site_code:
        filtered = [c for c in candidates if c["site"] == site_code]
        if not filtered:
            raise NotFound(f"站点 {site_code} 无候选")
        if len(filtered) > 1 and pick is None:
            raise CandidateChoiceRequired(filtered)
        return filtered[pick] if pick is not None else filtered[0]
    if pick is not None:
        if 0 <= pick < len(candidates):
            return candidates[pick]
        raise CandidateChoiceRequired(candidates)
    if len(candidates) == 1:
        return candidates[0]
    raise CandidateChoiceRequired(candidates)


# ---------------------------------------------------------------------------
# 添加漫画
# ---------------------------------------------------------------------------

def _register_comic(site_code: str, detail, download: bool, range_spec: str | None,
                    latest_n: int | None) -> dict:
    """按已解析的 ComicDetail 登记漫画与章节，可选增量下载。"""
    site = db.get_site_by_code(site_code)
    existing = db.find_comic_by_site(site["id"], detail.comic.site_comic_id)

    if existing:
        comic_id = existing["id"]
        outcome = {"already_exists": True}
    else:
        comic_id = db.insert_comic(
            title=detail.comic.title,
            site_id=site["id"],
            site_comic_id=detail.comic.site_comic_id,
            detail_url=detail.comic.detail_url,
            author=detail.comic.author,
            status=detail.comic.status,
            cover_url=detail.comic.cover_url,
        )
        outcome = {"already_exists": False}

    # 登记新章节（幂等，同站同漫画重复添加不会重复登记）
    db.insert_chapters(comic_id, site["id"], [asdict(ch) for ch in detail.chapters])

    comic = db.get_comic(comic_id)
    chapters = db.list_chapters(comic_id)
    max_no = max((ch["chapter_no"] for ch in chapters), default=0)
    db.update_comic_meta(
        comic_id,
        title=comic["title"],
        detail_url=comic["detail_url"],
        author=comic["author"],
        status=comic["status"],
        total_chapters=len(chapters),
        max_chapter_no=max_no,
    )

    # 跨站同名关联提示
    related = [
        {"comic_id": c["id"], "title": c["title"], "site": c["site_code"]}
        for c in db.find_comics_by_title(comic["title"])
        if c["id"] != comic_id
    ]

    result = {
        "comic_id": comic_id,
        "title": comic["title"],
        "site": comic["site_code"],
        "site_name": comic["site_name"],
        "detail_url": comic["detail_url"],
        "rel_dir": comic["rel_dir"],
        "total_chapters": len(chapters),
        "related_comics": related,
        **outcome,
    }
    if download:
        result["download"] = download_comic(comic_id, range_spec=range_spec, latest_n=latest_n)
    return result


def add_comic(
    name: str,
    site_code: Optional[str] = None,
    pick: Optional[int] = None,
    download: bool = True,
    range_spec: Optional[str] = None,
    latest_n: Optional[int] = None,
) -> dict:
    """按名称搜索并添加漫画（候选选择后走 _register_comic）。"""
    ensure_sites()
    search_result = search_all(name)
    candidate = _resolve_candidate(search_result["candidates"], site_code, pick)

    adapter = get_adapter(candidate["site"])
    detail = adapter.get_chapters(candidate["detail_url"])
    result = _register_comic(candidate["site"], detail, download, range_spec, latest_n)
    result["search_errors"] = search_result["errors"]
    return result


def add_by_url(
    site_code: str,
    detail_url: str,
    download: bool = True,
    range_spec: Optional[str] = None,
    latest_n: Optional[int] = None,
) -> dict:
    """按详情页 URL 直接添加漫画（跳过搜索，便于迁移与已知链接添加）。"""
    ensure_sites()
    if not get_adapter(site_code):
        raise NotFound(f"未知站点: {site_code}")
    detail = get_adapter(site_code).get_chapters(detail_url)
    return _register_comic(site_code, detail, download, range_spec, latest_n)


# ---------------------------------------------------------------------------
# 下载（增量）
# ---------------------------------------------------------------------------

def _parse_range(range_spec: Optional[str]) -> Optional[set[int]]:
    """解析章节区间："1-5,8,10-12" -> {1,2,3,4,5,8,10,11,12}。

    非法输入抛带明确说明的 ValueError（CLI 转为 ok=false/退出码 1），
    避免用户只看到一句没有原因的失败（traceback 只在 stderr）。
    """
    if not range_spec:
        return None
    result: set[int] = set()
    for part in range_spec.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            if "-" in part:
                start_s, end_s = part.split("-", 1)
                start, end = int(start_s), int(end_s)
                if start <= 0 or end < start:
                    raise ValueError
                result.update(range(start, end + 1))
            else:
                no = int(part)
                if no <= 0:
                    raise ValueError
                result.add(no)
        except ValueError:
            raise ValueError(
                f"章节区间格式无效: {part!r}（应形如 1-5,8,10-12）"
            ) from None
    return result or None


def download_comic(
    comic_id: int,
    range_spec: Optional[str] = None,
    latest_n: Optional[int] = None,
    retry_failed: bool = True,
    chapter_ids: Optional[list[int]] = None,
    sync_site: bool = True,
) -> dict:
    """增量下载漫画：只下载未完成的章节（done 跳过）。

    range_spec 限定章节号；latest_n 只取最新 N 个待下载章节；
    chapter_ids 直接指定章节行 id（update-check 精确下载新登记章节时使用，
    避免因序号让位导致按号下载到错误章节）。
    并发数取适配器 max_workers（默认 .env COMIX_MAX_WORKERS）。
    """
    comic = db.get_comic(comic_id)
    if not comic:
        raise NotFound(f"漫画 {comic_id} 不存在")
    adapter = get_adapter(comic["site_code"])

    # 孤儿回收：上次进程中断残留的 running 任务与 .downloading 临时目录
    recovered_tasks = db.recover_running_tasks(comic_id)
    removed_dirs = _cleanup_downloading_dirs(comic["rel_dir"])
    if recovered_tasks or removed_dirs:
        # 进度日志走 stderr（--json 模式下不污染 stdout 的 JSON）
        print(
            f"已回收中断残留: 任务{recovered_tasks}个, 临时目录{removed_dirs}个",
            file=sys.stderr, flush=True,
        )

    # 先向站点核对一次章节列表：把站点已上线但本地未登记的章节补登记，
    # 避免"本地没有该章节 → download 什么都不做"却报告成功的假象。
    sync_info = _sync_chapters_from_site(comic, adapter) if sync_site else {
        "site_total": 0, "registered": 0, "added": 0, "renumbered": 0, "error": "",
    }

    all_chapters = db.list_chapters(comic_id)
    want = {ch["id"]: ch for ch in all_chapters if ch["status"] != "done"}
    if chapter_ids is not None:
        allow = set(chapter_ids)
        want = {i: ch for i, ch in want.items() if i in allow}
    if retry_failed:
        # failed 状态可重试；pending 默认下载
        pass
    else:
        want = {ch["id"]: ch for ch in want.values() if ch["status"] == "pending"}

    no_range = _parse_range(range_spec)
    if no_range is not None:
        want = {i: ch for i, ch in want.items() if ch["chapter_no"] in no_range}
    if latest_n is not None and latest_n > 0:
        sorted_want = sorted(want.values(), key=lambda ch: ch["chapter_no"])
        want = {ch["id"]: ch for ch in sorted_want[-latest_n:]}

    if not want:
        _ensure_cover_image(comic_id)
        return {
            "comic_id": comic_id,
            "title": comic["title"],
            "skipped": 0,
            "downloaded": [],
            "failed": [],
            "sync": sync_info,
            "message": "没有待下载的章节",
        }

    results: list[dict] = []
    failures: list[dict] = []

    def _download(ch: dict) -> dict:
        chapter = ChapterInfo(chapter_no=ch["chapter_no"], title=ch["title"], url=ch["url"])
        # rel_dir 为存储根相对路径（comics/{comic_id}/{chapter_id}）
        save_dir = _storage_path(ch["rel_dir"])
        db.start_task(comic_id, ch["id"])
        try:
            ok, pages, error = adapter.download_chapter(chapter, save_dir)
        except Exception as exc:  # 适配器内部未捕获的异常兜底
            ok, pages, error = False, 0, f"{type(exc).__name__}: {exc}"
        if ok:
            db.update_chapter_status(ch["id"], "done", pages)
            db.finish_task(ch["id"], "done", pages)
            # 回填图片记录（comix_image，供 Go/Flutter 经视图读取路径与宽高）
            try:
                db.clear_images(ch["id"])
                db.insert_images(ch["id"], scan_images(save_dir))
            except Exception as exc:
                if not QUIET:
                    print(f"警告: 图片记录回填失败(章节{ch['chapter_no']}): {exc}")
            return {"chapter_id": ch["id"], "chapter_no": ch["chapter_no"],
                    "title": ch["title"], "ok": True, "pages": pages,
                    "rel_dir": ch["rel_dir"], "error": ""}
        db.update_chapter_status(ch["id"], "failed", 0, error)
        db.finish_task(ch["id"], "failed", 0, error)
        return {"chapter_id": ch["id"], "chapter_no": ch["chapter_no"],
                "title": ch["title"], "ok": False, "pages": 0,
                "rel_dir": ch["rel_dir"], "error": error}

    # 失败章节整章重试一轮（沿用原脚本的稳定性策略）
    # 注意：每轮失败收集到 round_failures，避免在重试轮被清空导致
    # 最终失败章节丢失在 JSON 结果中（两轮都失败的才计入最终 failures）。
    remaining = list(want.values())
    for round_no in (1, 2):
        if not remaining:
            break
        round_failures = []
        with ThreadPoolExecutor(max_workers=adapter.max_workers) as pool:
            future_map = {pool.submit(_download, ch): ch for ch in remaining}
            round_results = []
            for future in as_completed(future_map):
                r = future.result()
                round_results.append(r)
        for r in round_results:
            if r["ok"]:
                results.append(r)
            else:
                round_failures.append(r)
        remaining = [ch for ch in remaining if ch["id"] in {f["chapter_id"] for f in round_failures}]
        if round_no == 2:
            failures.extend(round_failures)

    results.sort(key=lambda r: r["chapter_no"])
    # 封面维护：cover_image 为空时取已下载章节（最小 chapter_no）的第一张图
    _ensure_cover_image(comic_id)

    parts = []
    if sync_info.get("error"):
        parts.append(f"站点章节同步失败({sync_info['error'].split(':')[0]})，仅按本地登记下载")
    elif sync_info.get("added"):
        parts.append(f"站点新增登记 {sync_info['added']} 章")
    if results:
        parts.append(f"下载成功 {len(results)} 章")
    if failures:
        parts.append(f"失败 {len(failures)} 章（已重试一轮）")
    if not parts:
        parts.append("没有待下载的章节")
    return {
        "comic_id": comic_id,
        "title": comic["title"],
        "skipped": 0,
        "downloaded": results,
        "failed": failures,
        "sync": sync_info,
        "message": "；".join(parts),
    }


def _sync_chapters_from_site(comic: dict, adapter) -> dict:
    """向站点拉取章节列表并与本地对比，补登记缺失章节（不下载）。

    返回 {"site_total": n, "registered": m, "added": k, "renumbered": j, "error": ""}。
    抓取失败不阻塞下载（返回 error 字段，调用方按本地章节继续）。
    """
    info = {"site_total": 0, "registered": 0, "added": 0, "renumbered": 0, "error": ""}
    try:
        detail = adapter.get_chapters(comic["detail_url"])
    except Exception as exc:  # noqa: BLE001 - 站点不可达不应阻塞本地下载
        info["error"] = f"{type(exc).__name__}: {exc}"
        return info

    db.set_cover_url(comic["id"], getattr(detail.comic, "cover_url", ""))
    outcomes = db.insert_chapters(
        comic["id"], comic["site_id"], [asdict(ch) for ch in detail.chapters]
    )
    info["site_total"] = len(detail.chapters)
    info["registered"] = len(db.list_chapters(comic["id"]))
    info["added"] = sum(1 for o in outcomes if o["inserted"])
    info["renumbered"] = sum(1 for o in outcomes if o["renumbered"])
    if info["added"] or info["renumbered"]:
        chapters_now = db.list_chapters(comic["id"])
        db.update_comic_meta(
            comic["id"],
            title=comic["title"],
            detail_url=comic["detail_url"],
            author=comic["author"],
            status=comic["status"],
            total_chapters=len(chapters_now),
            max_chapter_no=max((ch["chapter_no"] for ch in chapters_now), default=0),
        )
    return info


def _ensure_cover_image(comic_id: int) -> str:
    """为封面为空的漫画补第一章第一图路径（相对项目根）。

    视图 comic_books.cover_image 是纯列，必须由下载/导入路径维护，
    不能依赖视图动态计算（相关子查询在 JOIN 放大后导致查询超时）。
    返回最终封面路径（空串表示无可用图，例如章节全部失败/未下载）。
    """
    if db.get_cover_image(comic_id):
        return db.get_cover_image(comic_id)
    cover = db.first_image_of_comic(comic_id)
    if cover:
        db.set_cover_image(comic_id, cover)
    return cover


def repair_covers(comic_id: Optional[int] = None) -> dict:
    """批量校正封面：

    - cover_image 为空但有已下载章节 → 取第一章第一图补上；
    - cover_image 指向磁盘上不存在的文件 → 重算并覆盖；
    - 无任何已下载章节 → 清空（避免下游引用失效路径）。

    返回 {"checked": n, "fixed": k, "cleared": j, "items": [...]}。
    磁盘存在性以 COMIC_STORAGE_ROOT 为根判断（与 /static 暴露路径一致）。
    """
    comics = db.list_comics()
    if comic_id is not None:
        comics = [c for c in comics if c["id"] == comic_id]

    fixed: list[dict] = []
    cleared: list[dict] = []
    checked = 0
    for comic in comics:
        checked += 1
        old = db.get_cover_image(comic["id"])
        new = db.first_image_of_comic(comic["id"])
        if old and old != new and _cover_file_exists(old):
            continue  # 现有封面有效，不打扰
        if old == new:
            continue
        db.repair_cover_image(comic["id"], new)
        item = {"comic_id": comic["id"], "title": comic["title"],
                "old": old, "new": new}
        (fixed if new else cleared).append(item)
    return {"checked": checked, "fixed": len(fixed), "cleared": len(cleared),
            "items": fixed + cleared}


def _cover_file_exists(rel_path: str) -> bool:
    """cover_image 是形如 comics/{comic_id}/{chapter_id}/001.jpg 的相对路径，
    对应存储根下去掉 `comics/` 前缀的位置。"""
    return config.storage_path(rel_path).is_file()


# ---------------------------------------------------------------------------
# 更新检查
# ---------------------------------------------------------------------------

def check_updates(comic_id: Optional[int] = None, all_comics: bool = False,
                  download: bool = False, latest_n: Optional[int] = None) -> dict:
    """检查连载更新：对比站内最新章节与本地已登记章节。

    download=True 时自动登记并下载新章节（增量）。
    """
    ensure_sites()
    if comic_id is not None:
        comics = [db.get_comic(comic_id)]
        if not comics[0]:
            raise NotFound(f"漫画 {comic_id} 不存在")
    elif all_comics:
        comics = db.list_comics()
    else:
        comics = []

    reports: list[dict] = []
    for comic in comics:
        # 本地历史资源（legacy）无来源站点，跳过连载更新
        if comic["site_code"] == "legacy":
            continue
        adapter = get_adapter(comic["site_code"])
        existing_before = db.list_chapters(comic["id"])
        base = {
            "comic_id": comic["id"],
            "title": comic["title"],
            "site": comic["site_code"],
            "site_name": comic.get("site_name", ""),
            "detail_url": comic["detail_url"],
            # 可核验性：同时给出本地登记数/已下载数/未下载数/失败数与站点章节数
            "local_registered": len(existing_before),
            "local_downloaded": sum(1 for ch in existing_before if ch["status"] == "done"),
            "local_pending": sum(1 for ch in existing_before if ch["status"] == "pending"),
            "local_failed": sum(1 for ch in existing_before if ch["status"] == "failed"),
            "local_max_no": max((ch["chapter_no"] for ch in existing_before), default=0),
        }
        try:
            detail = adapter.get_chapters(comic["detail_url"])
        except Exception as exc:
            reports.append({
                **base,
                "site_total": 0,
                "latest_site_no": 0,
                "new_chapters": [],
                "error": f"{type(exc).__name__}: {exc}",
                "message": "站点不可达，本次未检查成功（本地数据未受影响）",
            })
            continue

        existing_urls = {ch["url"] for ch in existing_before}
        site_urls = {ch.url for ch in detail.chapters}
        new_chapters = [ch for ch in detail.chapters if ch.url not in existing_urls]
        # 本地有、站点已下架（改版/删除）的章节，供用户判断是否需要清理
        stale_chapters = [ch for ch in existing_before if ch["url"] not in site_urls]
        # 注意：详情页可能截断章节列表（只显示最近 N 章），new 按 URL 去重即可

        report = {
            **base,
            "site_total": len(detail.chapters),
            "latest_site_no": max((ch.chapter_no for ch in detail.chapters), default=0),
            "new_chapters": [asdict(ch) for ch in new_chapters],
            "stale_count": len(stale_chapters),
            "error": "",
        }
        if new_chapters:
            report["message"] = (
                f"站点 {len(detail.chapters)} 章，本地已登记 {len(existing_before)} 章，"
                f"发现 {len(new_chapters)} 个新章节"
            )
        else:
            report["message"] = (
                f"无新章节（站点 {len(detail.chapters)} 章，"
                f"本地已登记 {len(existing_before)} 章）"
            )
        # 必须显式给出"本地实际下载进度"：只报"已是最新（本地登记 N 章）"
        # 会让"登记了但一章都没下载"的漫画看起来已完成（真实数据 comic 126/131）。
        report["message"] += (
            f"；本地已下载 {base['local_downloaded']}/{base['local_registered']} 章"
        )
        if base["local_pending"]:
            report["message"] += f"（{base['local_pending']} 章未下载）"
        if base["local_failed"]:
            report["message"] += f"（{base['local_failed']} 章下载失败可重试）"

        if download:
            site = db.get_site_by_code(comic["site_code"])
            # 登记的最终序号可能因序号让位（collision bump）而与站点序号不同，
            # 因此以 insert_chapters 的返回值为准，避免下载到错误章节。
            inserted_ids: list[int] = []
            if new_chapters:
                outcomes = db.insert_chapters(
                    comic["id"], site["id"], [asdict(ch) for ch in new_chapters]
                )
                inserted_ids = [o["chapter_id"] for o in outcomes if o["inserted"]]
                report["registered_now"] = len(outcomes)
                report["chapter_no_adjusted"] = sum(1 for o in outcomes if o["renumbered"])
            # 追更的语义是"把本地补齐到站点状态"：除新章节外，还要补下
            # "已登记但从未下载(pending)"的章节——它们不会被 URL 对比发现，
            # 否则永远停留在"已是最新"而实际一章都没有（真实数据 comic 126/131）。
            # failed 章节不自动重试（多为站点侧问题），只在报告中提示可重试。
            chapters_now = db.list_chapters(comic["id"])
            pending_ids = [ch["id"] for ch in chapters_now if ch["status"] == "pending"]
            target_ids = sorted(set(inserted_ids) | set(pending_ids))
            report["download_targets"] = len(target_ids)
            if target_ids:
                report["download"] = download_comic(
                    comic["id"], chapter_ids=target_ids, latest_n=latest_n,
                    sync_site=False,  # 本轮已拉取过站点章节列表，无需重复请求
                )
            # 刷新漫画元信息（total_chapters / max_chapter_no 保持与章节表一致）
            chapters_now = db.list_chapters(comic["id"])
            db.update_comic_meta(
                comic["id"],
                title=comic["title"],
                detail_url=comic["detail_url"],
                author=comic["author"],
                status=comic["status"],
                total_chapters=len(chapters_now),
                max_chapter_no=max((ch["chapter_no"] for ch in chapters_now), default=0),
            )
        reports.append(report)

    return {"reports": reports}


# ---------------------------------------------------------------------------
# 一次性维护：按站点章节列表校正本地登记 + 封面修复
# ---------------------------------------------------------------------------

def sync_comics(comic_id: Optional[int] = None, all_comics: bool = False,
                fix_covers: bool = True, register: bool = True,
                force_covers: bool = False) -> dict:
    """按站点章节列表校正本地登记数据：

    1. register=True 时把站点已上线但本地未登记的章节补登记；
    2. 把本地已登记章节的 chapter_no 校正到站点顺序（旧数据错位的修复手段）；
    3. fix_covers=True 时修复/补齐封面。

    已下载章节的磁盘文件与状态不受影响（rel_dir 不变，仅序号标签变化）。
    `stale` 为本地有、站点已下架（改版删除）的章节数，供人工判断。
    """
    ensure_sites()
    if comic_id is not None:
        comic = db.get_comic(comic_id)
        if not comic:
            raise NotFound(f"漫画 {comic_id} 不存在")
        comics = [comic]
    elif all_comics:
        comics = db.list_comics()
    else:
        raise NotFound("需要指定 --comic-id 或 --all")

    results: list[dict] = []
    for comic in comics:
        if comic["site_code"] == "legacy":
            continue
        entry = {
            "comic_id": comic["id"], "title": comic["title"], "site": comic["site_code"],
            "checked": True, "site_total": 0, "added": 0, "renumbered": 0,
            "missing_on_site": 0, "error": "", "cover": "",
        }
        adapter = get_adapter(comic["site_code"])
        try:
            detail = adapter.get_chapters(comic["detail_url"])
        except Exception as exc:  # noqa: BLE001
            entry["error"] = f"{type(exc).__name__}: {exc}"
            results.append(entry)
            continue

        site_chapters = [asdict(ch) for ch in detail.chapters]
        entry["site_total"] = len(site_chapters)
        db.set_cover_url(comic["id"], getattr(detail.comic, "cover_url", ""),
                         force=force_covers)

        if register:
            outcomes = db.insert_chapters(comic["id"], comic["site_id"], site_chapters)
            entry["added"] = sum(1 for o in outcomes if o["inserted"])
            entry["renumbered"] += sum(1 for o in outcomes if o["renumbered"])
        else:
            # 只重排：把站点已有的 URL 对应的本地行移动到站点序号
            site_by_url = {ch["url"]: ch for ch in site_chapters}
            with db.connect() as conn, db.transaction(conn):
                for local in db.list_chapters(comic["id"]):
                    target = site_by_url.get(local["url"])
                    if target and target["chapter_no"] != local["chapter_no"]:
                        db._place_chapter_at(  # noqa: SLF001 - 内部维护工具
                            conn, comic["id"], local["id"], target["chapter_no"]
                        )
                        entry["renumbered"] += 1

        chapters_now = db.list_chapters(comic["id"])
        site_urls = {ch["url"] for ch in site_chapters}
        entry["missing_on_site"] = sum(1 for ch in chapters_now if ch["url"] not in site_urls)
        db.update_comic_meta(
            comic["id"],
            title=comic["title"],
            detail_url=comic["detail_url"],
            author=comic["author"],
            status=comic["status"],
            total_chapters=len(chapters_now),
            max_chapter_no=max((ch["chapter_no"] for ch in chapters_now), default=0),
        )
        if fix_covers:
            entry["cover"] = _ensure_cover_image(comic["id"])
        results.append(entry)

    summary = {
        "comics": len(results),
        "added": sum(r["added"] for r in results),
        "renumbered": sum(r["renumbered"] for r in results),
        "errors": [r for r in results if r["error"]],
        "results": results,
    }
    if fix_covers:
        summary["covers"] = repair_covers(comic_id)
    return summary


# ---------------------------------------------------------------------------
# 删除与查询
# ---------------------------------------------------------------------------

def delete_comic(comic_id: int, keep_files: bool = False) -> dict:
    """删除漫画：默认同时删除 DB 记录与本地文件；keep_files=True 仅删记录。"""
    comic = db.get_comic(comic_id)
    if not comic:
        raise NotFound(f"漫画 {comic_id} 不存在")

    files_removed = False
    if not keep_files:
        root = Path(_storage_path(comic["rel_dir"]))
        if root.exists():
            shutil.rmtree(root, ignore_errors=True)
        files_removed = True

    db.delete_comic(comic_id)
    return {
        "comic_id": comic_id,
        "title": comic["title"],
        "files_removed": files_removed,
        "rel_dir": comic["rel_dir"],
    }


def list_comics() -> list[dict]:
    """列出全部已登记漫画（含各站已下载章节数）。"""
    ensure_sites()
    result = []
    for comic in db.list_comics():
        chapters = db.list_chapters(comic["id"])
        result.append({
            "comic_id": comic["id"],
            "title": comic["title"],
            "site": comic["site_code"],
            "site_name": comic["site_name"],
            "detail_url": comic["detail_url"],
            "rel_dir": comic["rel_dir"],
            "total_chapters": len(chapters),
            "downloaded": sum(1 for ch in chapters if ch["status"] == "done"),
            "failed": sum(1 for ch in chapters if ch["status"] == "failed"),
            # 实时计算，避免 comic 表缓存值滞后
            "max_chapter_no": max((ch["chapter_no"] for ch in chapters), default=0),
        })
    return result


def list_chapters(comic_id: int) -> dict:
    comic = db.get_comic(comic_id)
    if not comic:
        raise NotFound(f"漫画 {comic_id} 不存在")
    return {
        "comic_id": comic_id,
        "title": comic["title"],
        "site": comic["site_code"],
        "chapters": db.list_chapters(comic_id),
    }
