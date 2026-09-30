"""为已下载完成的章节补齐 comic_images 图片记录（含宽高解析），并补空封面。

适用场景：磁盘文件已存在但缺图片记录（历史下载、导入异常），以及任何需要
重建图片索引的情况。幂等，可重复运行。

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
        comics = [db.get_comic(comic_id)]
        chapter_rows = db.list_chapters(comic_id)
    else:
        comics = db.list_comics()
        chapter_rows = []
        for comic in comics:
            chapter_rows.extend(db.list_chapters(comic["id"]))

    # 只处理"已下载但缺图片记录"的章节（legacy 导入/下载回填已写记录的跳过，
    # 避免重新扫描 12 万文件）
    with db.connect() as conn:
        recorded = {
            r["chapter_id"]
            for r in conn.execute("SELECT DISTINCT chapter_id FROM comic_images").fetchall()
        }
    chapters = [c for c in chapter_rows if c["status"] == "done" and c["id"] not in recorded]

    filled = 0
    images_inserted = 0
    covers = 0
    errors: list[dict] = []
    for ch in chapters:
        save_dir = Path(config.storage_path(ch["rel_dir"]))
        if not save_dir.is_dir():
            errors.append({"chapter_id": ch["id"], "rel_dir": ch["rel_dir"], "error": "目录不存在"})
            continue
        try:
            images = scan_images(str(save_dir))
            if not images:
                errors.append({"chapter_id": ch["id"], "rel_dir": ch["rel_dir"], "error": "目录内无图片文件"})
                continue
            images_inserted += db.replace_images(ch["id"], images)
            filled += 1
        except Exception as exc:
            errors.append({"chapter_id": ch["id"], "rel_dir": ch["rel_dir"], "error": str(exc)})

    # 封面补齐：cover_image 为空时取第一章第一图（cover_image 是显式维护的纯列）
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
