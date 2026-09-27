"""无状态命令行入口：python -m comix.cli <command> [options]

设计要点：
- 每次调用独立进程、独立数据库连接，无任何会话状态；
- 进度日志一律走 stderr，--json 模式下结果 JSON 走 stdout，
  供本地 Go HTTP 服务直接捕获解析；
- 业务性错误（未找到/多候选）返回 JSON error 与候选列表，退出码 2；
  意外异常退出码 1；成功退出码 0。

常用命令：
    init                    建表并注册站点
    search <名称>            全站搜索候选
    add <名称> [--site 站点] [--pick N] [--no-download] [--range 1-5,8] [--latest N]
    list                    列出已登记漫画
    chapters <comic_id>     查看漫画章节状态
    download <comic_id> [--range 1-5,8] [--latest N] [--no-retry-failed]
    update-check [--comic-id ID | --all] [--download] [--latest N]
    delete <comic_id> [--keep-files]
    sites                   列出可用站点
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime

from . import db, scheduler
from .scheduler import CandidateChoiceRequired, NotFound

import util.common as _common  # 控制安静模式


# ---------------------------------------------------------------------------
# 输出
# ---------------------------------------------------------------------------

def _json_default(obj):
    """datetime/date 序列化为 ISO 字符串，其余交给标准 JSON。"""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")


def emit_ok(data: dict) -> None:
    print(json.dumps({"ok": True, "data": data}, ensure_ascii=False, default=_json_default))


def emit_error(message: str, extra: dict | None = None) -> None:
    payload: dict = {"ok": False, "error": message}
    if extra:
        payload.update(extra)
    print(json.dumps(payload, ensure_ascii=False, default=_json_default))


def log(msg: str) -> None:
    """进度日志 → stderr（不污染 JSON stdout）。"""
    print(msg, file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# 命令实现
# ---------------------------------------------------------------------------

def cmd_init(args) -> None:
    db.init_db()
    scheduler.ensure_sites()
    emit_ok({"message": "数据库表已创建，站点已注册", "sites": db.list_sites()})


def cmd_sites(args) -> None:
    emit_ok({"sites": db.list_sites()})


def cmd_search(args) -> None:
    result = scheduler.search_all(args.name)
    emit_ok({"keyword": args.name, **result})


def _pick_interactively(candidates: list[dict]) -> int:
    log("存在多个候选，请选择：")
    for i, c in enumerate(candidates):
        log(f"  [{i}] [{c['site_name']}] {c['title']}  {c['detail_url']}")
    while True:
        try:
            choice = input("输入序号回车: ").strip()
            idx = int(choice)
            if 0 <= idx < len(candidates):
                return idx
        except (ValueError, EOFError):
            pass
        log("输入无效，请重新输入")


def cmd_add(args) -> None:
    pick = args.pick
    try:
        result = scheduler.add_comic(
            name=args.name,
            site_code=args.site,
            pick=pick,
            download=not args.no_download,
            range_spec=args.range,
            latest_n=args.latest,
        )
    except CandidateChoiceRequired as exc:
        if args.json:
            emit_error("需要选择候选", {"candidates": exc.candidates})
            sys.exit(2)
        pick = _pick_interactively(exc.candidates)
        result = scheduler.add_comic(
            name=args.name, site_code=args.site, pick=pick,
            download=not args.no_download, range_spec=args.range, latest_n=args.latest,
        )
    except NotFound as exc:
        emit_error(str(exc))
        sys.exit(2)
    emit_ok(result)


def cmd_add_url(args) -> None:
    try:
        result = scheduler.add_by_url(
            site_code=args.site,
            detail_url=args.url,
            download=not args.no_download,
            range_spec=args.range,
            latest_n=args.latest,
        )
    except NotFound as exc:
        emit_error(str(exc))
        sys.exit(2)
    emit_ok(result)


def cmd_list(args) -> None:
    emit_ok({"comics": scheduler.list_comics()})


def cmd_chapters(args) -> None:
    try:
        result = scheduler.list_chapters(args.comic_id)
    except NotFound as exc:
        emit_error(str(exc))
        sys.exit(2)
    emit_ok(result)


def cmd_download(args) -> None:
    try:
        result = scheduler.download_comic(
            args.comic_id,
            range_spec=args.range,
            latest_n=args.latest,
            retry_failed=not args.no_retry_failed,
        )
    except NotFound as exc:
        emit_error(str(exc))
        sys.exit(2)
    emit_ok(result)


def cmd_update_check(args) -> None:
    try:
        result = scheduler.check_updates(
            comic_id=args.comic_id,
            all_comics=args.all,
            download=args.download,
            latest_n=args.latest,
        )
    except NotFound as exc:
        emit_error(str(exc))
        sys.exit(2)
    emit_ok(result)


def cmd_delete(args) -> None:
    try:
        result = scheduler.delete_comic(args.comic_id, keep_files=args.keep_files)
    except NotFound as exc:
        emit_error(str(exc))
        sys.exit(2)
    emit_ok(result)


def cmd_clean(args) -> None:
    """回收中断残留：running 任务 + *.downloading 临时目录。"""
    result = scheduler.cleanup()
    emit_ok(result)


def cmd_sync(args) -> None:
    """维护命令：按站点章节列表补齐/重排本地章节，并可修复封面。

    典型用途：站点改版后本地 chapter_no 与站点顺序错位、或本地缺失章节时，
    无需重新下载即可把登记数据校正到与站点一致（已下载章节的文件不受影响）。
    """
    result = scheduler.sync_comics(
        comic_id=args.comic_id,
        all_comics=args.all,
        fix_covers=not args.no_covers,
        register=not args.no_register,
        force_covers=args.force_covers,
    )
    emit_ok(result)



# ---------------------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="comix",
        description="漫画下载管理系统（无状态 CLI，JSON 输入输出）",
    )
    parser.add_argument("--json", action="store_true", help="JSON 输出模式（供 Go 服务调用）")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("init", help="建表并注册站点")
    p.set_defaults(func=cmd_init)

    p = sub.add_parser("sites", help="列出可用站点")
    p.set_defaults(func=cmd_sites)

    p = sub.add_parser("search", help="全站搜索漫画候选")
    p.add_argument("name", help="漫画名称关键词")
    p.set_defaults(func=cmd_search)

    p = sub.add_parser("add", help="搜索并添加漫画（可选下载）")
    p.add_argument("name", help="漫画名称关键词")
    p.add_argument("--site", help="指定站点代码（manhuayu/morui/nicemh/xmanhua）")
    p.add_argument("--pick", type=int, help="多候选时按序号选择")
    p.add_argument("--no-download", action="store_true", help="只登记不下载")
    p.add_argument("--range", help="章节区间，如 1-5,8,10-12")
    p.add_argument("--latest", type=int, help="只下载最新 N 章")
    p.set_defaults(func=cmd_add)

    p = sub.add_parser("add-url", help="按详情页 URL 直接添加漫画（跳过搜索）")
    p.add_argument("site", help="站点代码（manhuayu/morui/nicemh/xmanhua）")
    p.add_argument("url", help="漫画详情页 URL")
    p.add_argument("--no-download", action="store_true", help="只登记不下载")
    p.add_argument("--range", help="章节区间，如 1-5,8,10-12")
    p.add_argument("--latest", type=int, help="只下载最新 N 章")
    p.set_defaults(func=cmd_add_url)

    p = sub.add_parser("list", help="列出已登记漫画")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("chapters", help="查看漫画章节状态")
    p.add_argument("comic_id", type=int)
    p.set_defaults(func=cmd_chapters)

    p = sub.add_parser("download", help="增量下载漫画未完成章节")
    p.add_argument("comic_id", type=int)
    p.add_argument("--range", help="章节区间，如 1-5,8,10-12")
    p.add_argument("--latest", type=int, help="只下载最新 N 章")
    p.add_argument("--no-retry-failed", action="store_true", help="不重试 failed 章节")
    p.set_defaults(func=cmd_download)

    p = sub.add_parser("update-check", help="检查连载更新")
    p.add_argument("--comic-id", type=int, help="指定漫画")
    p.add_argument("--all", action="store_true", help="检查全部漫画")
    p.add_argument("--download", action="store_true", help="自动下载新章节")
    p.add_argument("--latest", type=int, help="自动下载时只取最新 N 章")
    p.set_defaults(func=cmd_update_check)

    p = sub.add_parser("delete", help="删除漫画（DB 记录与本地文件）")
    p.add_argument("comic_id", type=int)
    p.add_argument("--keep-files", action="store_true", help="保留本地文件")
    p.set_defaults(func=cmd_delete)

    p = sub.add_parser("clean", help="回收中断残留（running 任务与 .downloading 临时目录）")
    p.set_defaults(func=cmd_clean)

    p = sub.add_parser("sync", help="按站点章节列表补齐/重排本地章节，并可修复封面")
    p.add_argument("--comic-id", type=int, help="只处理指定漫画")
    p.add_argument("--all", action="store_true", help="处理全部非 legacy 漫画")
    p.add_argument("--no-covers", action="store_true", help="跳过封面修复")
    p.add_argument("--force-covers", action="store_true",
                   help="用站点解析结果覆盖已有 cover_url（修复历史缺失/错误地址）")
    p.add_argument("--no-register", action="store_true", help="只重排/修复，不新增登记章节")
    p.set_defaults(func=cmd_sync)

    return parser


def main(argv: list[str] | None = None) -> int:
    # 强制 UTF-8 输出，保证 JSON 与日志编码一致（Windows 控制台默认 GBK 会乱码）
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except Exception:
            pass

    parser = build_parser()
    args = parser.parse_args(argv)

    if args.json:
        _common.QUIET = True  # 抑制下载进度打印，保证 stdout 只有 JSON

    try:
        args.func(args)
    except CandidateChoiceRequired as exc:
        emit_error("需要选择候选", {"candidates": exc.candidates})
        return 2
    except NotFound as exc:
        emit_error(str(exc))
        return 2
    except Exception as exc:  # 意外异常：输出错误信息与堆栈（stderr）
        log(f"意外错误: {type(exc).__name__}: {exc}")
        if args.json:
            emit_error(f"{type(exc).__name__}: {exc}")
        else:
            import traceback
            traceback.print_exc()
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
