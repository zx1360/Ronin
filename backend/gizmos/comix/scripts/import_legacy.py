"""导入旧爬虫资源（comics_ 目录）到 comix 表结构，供既有 Go/Flutter 系统使用。

流程（可回退）：
1. 把 comics_/{漫画目录} 移动到存储根下的 {漫画目录}（同盘重命名，快；检测重名）
2. 在单个事务内写入 comics / comic_chapters / comic_images 记录
3. 任一本失败 → DB 事务回滚 + 目录回移，不影响其他漫画
4. 完成后自动删除空的 comics_ 目录

幂等：重复运行自动跳过已导入漫画（site_comic_id=目录名 唯一）。
崩溃自愈：若上次中断留下"已移动未导入"的目录（存储根下未登记的名称目录），
本次运行会先补导入（Phase 1 恢复）。

用法：
    python scripts/import_legacy.py               # 预览模式
    python scripts/import_legacy.py --execute     # 实际执行（移动+导入）
    python scripts/import_legacy.py --execute --limit 5   # 只处理前 5 本（测试）
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from comix import config, db
from util.common import scan_images

LEGACY_CODE = "legacy"
_NUM_RE = re.compile(r"^(\d+)_(.*)$")


# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------

def _parse_chapter_dir(name: str) -> tuple[int, str] | None:
    """解析章节目录名："10_我的出租屋新娘 10" -> (10, "我的出租屋新娘 10")。"""
    m = _NUM_RE.match(name)
    if not m:
        return None
    title = m.group(2).strip()
    if not title:
        return None
    return int(m.group(1)), title


def _is_numeric_dir(name: str) -> bool:
    """comix 新下载目录为纯数字（{comic_id}），旧资源为名称目录。"""
    return re.fullmatch(r"\d+", name) is not None


def _registered_legacy_dirs(conn) -> set[str]:
    rows = conn.execute(
        """
        SELECT c.site_comic_id FROM comics c
        JOIN comic_sites s ON s.id = c.site_id
        WHERE s.code = ?
        """,
        (LEGACY_CODE,),
    ).fetchall()
    return {r["site_comic_id"] for r in rows}


# ---------------------------------------------------------------------------
# 单本导入（必须在调用方事务内执行；文件已就位于 comic_dir）
# ---------------------------------------------------------------------------

def _import_one(conn, comic_dir: Path) -> dict:
    """导入一本漫画（comic_dir 为存储根下的实际目录）。返回结果 dict。"""
    title = comic_dir.name
    site_id = conn.execute(
        "SELECT id FROM comic_sites WHERE code = ?", (LEGACY_CODE,)
    ).fetchone()["id"]
    existing = conn.execute(
        "SELECT id FROM comics WHERE site_id = ? AND site_comic_id = ?",
        (site_id, title),
    ).fetchone()
    if existing:
        return {"skipped": True, "reason": "已导入"}

    # 扫描章节（目录名需 "数字_章节名"）
    chapters: list[tuple[int, str, str, list[dict]]] = []
    for sub in sorted(comic_dir.iterdir(), key=lambda p: p.name):
        if not sub.is_dir():
            continue
        parsed = _parse_chapter_dir(sub.name)
        if not parsed:
            continue
        no, ctitle = parsed
        images = scan_images(str(sub))
        if not images:
            continue
        chapters.append((no, ctitle, sub.name, images))
    chapters.sort(key=lambda c: c[0])
    if not chapters:
        return {"skipped": True, "reason": "无有效章节（目录为空或章节名无数字前缀）"}

    # 1) comic 行（封面 = 第一章第一图路径，显式维护）
    first_chapter = chapters[0]
    cover_path = f"comics/{title}/{first_chapter[2]}/{first_chapter[3][0]['file_name']}"
    comic_id = conn.execute(
        """
        INSERT INTO comics
            (title, title_normalized, site_id, site_comic_id, detail_url,
             total_chapters, max_chapter_no, rel_dir, cover_image)
        VALUES (?, ?, ?, ?, '', ?, ?, ?, ?)
        RETURNING id
        """,
        (title, db.normalize_title(title), site_id, title,
         len(chapters), chapters[-1][0], f"comics/{title}", cover_path),
    ).fetchone()["id"]

    # 2) 章节行 + 3) 图片行（逐章）
    total_images = 0
    for no, ctitle, sub_name, images in chapters:
        chapter = conn.execute(
            """
            INSERT INTO comic_chapters
                (comic_id, site_id, chapter_no, title, url,
                 page_count, rel_dir, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'done')
            ON CONFLICT (comic_id, chapter_no) DO NOTHING
            RETURNING id
            """,
            (comic_id, site_id, no, ctitle,
             f"legacy://comic-{comic_id}/ch-{no}",
             len(images), f"comics/{title}/{sub_name}"),
        ).fetchone()
        if not chapter:
            continue  # 幂等：该章已存在
        chapter_id = chapter["id"]
        conn.executemany(
            """
            INSERT INTO comic_images (chapter_id, sort_num, file_name, width, height)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT (chapter_id, sort_num) DO NOTHING
            """,
            [(chapter_id, img["sort_num"], img["file_name"], img["width"], img["height"])
             for img in images],
        )
        total_images += len(images)

    return {
        "imported": True,
        "comic_id": comic_id,
        "title": title,
        "chapters": len(chapters),
        "images": total_images,
    }


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

def main() -> int:
    # 强制 UTF-8 输出（Windows 控制台默认 GBK 会因特殊字符报错）
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except Exception:
            pass

    parser = argparse.ArgumentParser(description="导入旧爬虫资源（comics_ → 存储根）")
    parser.add_argument("--dry-run", action="store_true", help="只预览，不动文件不改库")
    parser.add_argument("--execute", action="store_true", help="实际执行（默认只预览）")
    parser.add_argument("--limit", type=int, help="最多处理 N 本（测试用）")
    parser.add_argument("--json", action="store_true", help="JSON 输出")
    args = parser.parse_args()

    if not args.execute:
        print("预览模式（--execute 执行实际导入）")
        args.dry_run = True

    src_root = Path(config.PROJECT_ROOT) / "comics_"
    dst_root = Path(config.COMIC_STORAGE_ROOT)

    processed = 0
    summary = {"moved": 0, "imported": 0, "skipped": 0, "failed": [], "recovered": 0}
    with db.connect() as conn:
        registered = _registered_legacy_dirs(conn)

    def report_import(comic_dir: Path, moved: bool) -> None:
        nonlocal processed
        if args.dry_run:
            summary["skipped"] += 1  # 预览统计用
            print(f"[预览] {comic_dir.name}: 将导入（{'移动' if moved else '原地'}）")
            return
        try:
            with db.transaction() as conn:
                result = _import_one(conn, comic_dir)
            if result.get("imported"):
                summary["imported"] += 1
                if moved:
                    summary["moved"] += 1
                print(f"[导入] {result['title']}: {result['chapters']}章 "
                      f"{result['images']}图 (comic_id={result['comic_id']})")
            else:
                summary["skipped"] += 1
                print(f"[跳过] {comic_dir.name}: {result['reason']}")
        except Exception as exc:
            summary["failed"].append({"title": comic_dir.name, "error": f"{type(exc).__name__}: {exc}"})
            print(f"[失败] {comic_dir.name}: {exc!r}")
            if moved:
                # 回退：DB 事务已回滚，把目录移回 comics_
                try:
                    shutil.move(str(comic_dir), str(src_root / comic_dir.name))
                    print(f"  → 已回移目录到 comics_/{comic_dir.name}")
                except Exception as mv:
                    summary["failed"][-1]["error"] += f"；目录回移失败: {mv!r}"

    # ---- Phase 1 恢复：存储根下已移动未登记的旧目录 ----
    if dst_root.is_dir():
        for d in sorted(dst_root.iterdir()):
            if not d.is_dir() or _is_numeric_dir(d.name):
                continue
            if d.name in registered:
                continue
            report_import(d, moved=False)
            registered.add(d.name)
            processed += 1
            if args.limit and processed >= args.limit:
                break

    # ---- Phase 2 迁移：comics_ 下目录 → 存储根 ----
    if src_root.is_dir() and not (args.limit and processed >= args.limit):
        for d in sorted(src_root.iterdir()):
            if not d.is_dir():
                continue
            if d.name in registered:
                continue
            if args.limit and processed >= args.limit:
                break
            target = dst_root / d.name
            if target.exists():
                summary["skipped"] += 1
                print(f"[跳过] {d.name}: 目标目录已存在")
                continue
            if args.dry_run:
                report_import(d, moved=True)
            else:
                shutil.move(str(d), str(target))  # 先移动
                report_import(target, moved=True)
            registered.add(d.name)
            processed += 1

    # 清理空的 comics_ 目录
    if src_root.is_dir() and not args.dry_run:
        try:
            if not list(src_root.iterdir()):
                src_root.rmdir()
                print("comics_ 目录已清空并删除")
        except OSError:
            pass

    if args.json:
        print(json.dumps({"ok": True, "data": summary}, ensure_ascii=False))
    else:
        print(f"\n汇总: 移动 {summary['moved']}，导入 {summary['imported']}，"
              f"跳过 {summary['skipped']}，失败 {len(summary['failed'])}")
        for f in summary["failed"]:
            print(f"  失败: {f['title']}: {f['error']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
