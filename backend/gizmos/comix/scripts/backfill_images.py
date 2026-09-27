"""为已下载完成的章节补齐 comix_image 图片记录（含宽高解析）。

适用场景：迁移之前已下载的章节（磁盘文件已存在但无 image 记录），
以及任何需要重建图片索引的情况。幂等，可重复运行。

用法：python scripts/backfill_images.py [--comic-id N] [--json]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from comix import config, db
from util.common import scan_images


def backfill(comic_id: int | None = None) -> dict:
    if comic_id is not None:
        comic = db.get_comic(comic_id)
        comics = [comic] if comic else []
        chapter_rows = db.list_chapters(comic_id)
    else:
        comics = db.list_comics()
        chapter_rows = []
        for comic in comics:
            chapter_rows.extend(db.list_chapters(comic["id"]))

    # 只处理"已下载但缺图片记录"的章节（导入/下载回填已写记录的跳过，
    # 避免重新扫描 28 万文件）
    with db.connect() as conn:
        recorded = {
            r["chapter_id"]
            for r in conn.execute("SELECT DISTINCT chapter_id FROM comix_image").fetchall()
        }
    chapters = [c for c in chapter_rows if c["status"] == "done" and c["id"] not in recorded]

    filled = 0
    images_inserted = 0
    errors: list[dict] = []
    for ch in chapters:
        # rel_dir 是相对存储根的路径（comics/{comic_id}/{chapter_id}）
        save_dir = config.storage_path(ch["rel_dir"])
        if not save_dir.is_dir():
            errors.append({"chapter_id": ch["id"], "rel_dir": ch["rel_dir"], "error": "目录不存在"})
            continue
        try:
            images = scan_images(str(save_dir))
            if not images:
                errors.append({"chapter_id": ch["id"], "rel_dir": ch["rel_dir"], "error": "目录内无图片文件"})
                continue
            db.clear_images(ch["id"])
            images_inserted += db.insert_images(ch["id"], images)
            filled += 1
        except Exception as exc:
            errors.append({"chapter_id": ch["id"], "rel_dir": ch["rel_dir"], "error": str(exc)})

    # 封面补齐：cover_image 是纯列（视图不做相关子查询），必须显式维护
    covers = 0
    for comic in comics:
        if comic["cover_image"]:
            continue
        cover = db.first_image_of_comic(comic["id"])
        if cover:
            db.set_cover_image(comic["id"], cover)
            covers += 1

    return {
        "chapters_scanned": len(chapters),
        "chapters_filled": filled,
        "images_inserted": images_inserted,
        "covers_set": covers,
        "errors": errors,
    }


def main() -> int:
    # 强制 UTF-8 输出（Windows 控制台默认 GBK 遇特殊字符会崩）
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except Exception:
            pass

    parser = argparse.ArgumentParser(description="为已下载章节补齐图片记录")
    parser.add_argument("--comic-id", type=int, help="只处理指定漫画")
    parser.add_argument("--json", action="store_true", help="JSON 输出")
    args = parser.parse_args()

    result = backfill(args.comic_id)
    if args.json:
        print(json.dumps({"ok": True, "data": result}, ensure_ascii=False))
        return 0
    print(f"扫描章节 {result['chapters_scanned']}，补齐 {result['chapters_filled']}，"
          f"图片记录 {result['images_inserted']}")
    for e in result["errors"]:
        print(f"  错误: 章节{e['chapter_id']} {e['rel_dir']}: {e['error']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
