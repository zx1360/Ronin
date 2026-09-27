"""自动全量更新检查脚本：遍历全部已登记漫画，检查连载更新。

用法：
    python scripts/check_updates.py                 # 只检查并报告
    python scripts/check_updates.py --download      # 检查并自动增量下载新章节
    python scripts/check_updates.py --latest 3      # 配合 --download 只取最新 3 章
    python scripts/check_updates.py --json          # JSON 输出（供 Go 服务/计划任务）

可直接加入系统计划任务定时执行，实现无人值守自动追更。
退出码：0 成功；2 无已登记漫画。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from comix import scheduler


def _json_default(obj):
    from datetime import date, datetime

    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")


def main() -> int:
    import sys as _sys

    for stream in (_sys.stdout, _sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except Exception:
            pass

    parser = argparse.ArgumentParser(description="全量更新检查")
    parser.add_argument("--download", action="store_true", help="自动增量下载新章节")
    parser.add_argument("--latest", type=int, help="自动下载时只取最新 N 章")
    parser.add_argument("--json", action="store_true", help="JSON 输出")
    args = parser.parse_args()

    comics = scheduler.list_comics()
    if not comics:
        print(json.dumps({"ok": True, "data": {"reports": [], "message": "暂无已登记漫画"}},
                         ensure_ascii=False, default=_json_default) if args.json else "暂无已登记漫画")
        return 2

    result = scheduler.check_updates(all_comics=True, download=args.download, latest_n=args.latest)

    if args.json:
        print(json.dumps({"ok": True, "data": result}, ensure_ascii=False, default=_json_default))
        return 0

    for r in result["reports"]:
        if r["error"]:
            print(f"[错误] {r['title']}({r['site']}): {r['error']}")
            continue
        status = "有更新" if r["new_chapters"] else "无更新"
        print(f"[{status}] {r['title']}({r['site']}) 站点最新第{r['latest_site_no']}章, 本地第{r['local_max_no']}章")
        if r["new_chapters"]:
            for ch in r["new_chapters"][:10]:
                print(f"    新章节: 第{ch['chapter_no']}章 {ch['title']}")
            if len(r["new_chapters"]) > 10:
                print(f"    ... 共 {len(r['new_chapters'])} 章")
        if args.download and r.get("download"):
            dl = r["download"]
            print(f"    下载完成 {len(dl['downloaded'])} 章, 失败 {len(dl['failed'])} 章")
            for f in dl["failed"]:
                print(f"    失败: 第{f['chapter_no']}章 {f['title']}: {f['error']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
