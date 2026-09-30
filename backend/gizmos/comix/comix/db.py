"""SQLite 数据访问层（标准库 sqlite3）。

设计要点：
- 表结构真源是 `references/db/sqlite.sql`（Monarch 启动时也会执行同一份脚本），
  本模块只负责打开连接与读写，不再自持建表 SQL，避免两处漂移。
- 连接不跨函数持有：`connect()` 用于读取，`transaction()` 用于写入
  （BEGIN IMMEDIATE + 单写者模型，跨进程由 busy_timeout 等待）。
- 每函数返回 dict / dict 列表，便于直接序列化为 JSON。
"""
from __future__ import annotations

import contextlib
import re
import sqlite3
from typing import Iterable, Iterator, Optional

from . import config

# 本地时间文本，与 Go 侧 dbutil 的存储格式一致
_NOW = "strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')"

BUSY_TIMEOUT_SEC = 10


def _dict_row(cursor: sqlite3.Cursor, row: tuple) -> dict:
    """结果行转普通 dict（支持 .get，便于上层直接序列化为 JSON）。"""
    return {col[0]: row[i] for i, col in enumerate(cursor.description)}


def _open() -> sqlite3.Connection:
    """打开连接（自动提交模式；事务由 transaction() 显式开启）。"""
    conn = sqlite3.connect(config.DB_FILE, timeout=BUSY_TIMEOUT_SEC, isolation_level=None)
    conn.row_factory = _dict_row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA busy_timeout = %d" % (BUSY_TIMEOUT_SEC * 1000))
    return conn


@contextlib.contextmanager
def connect() -> Iterator[sqlite3.Connection]:
    """读取用连接（退出即关闭，不持有事务）。"""
    conn = _open()
    try:
        yield conn
    finally:
        conn.close()


@contextlib.contextmanager
def transaction() -> Iterator[sqlite3.Connection]:
    """写入用连接：BEGIN IMMEDIATE → 提交；异常整体回滚。

    不依赖驱动的隐式事务：BEGIN IMMEDIATE 一开始就取写锁，配合单写者模型
    不会出现"读→写升级"失败。
    """
    conn = _open()
    try:
        conn.execute("BEGIN IMMEDIATE")
        try:
            yield conn
        except BaseException:
            conn.execute("ROLLBACK")
            raise
        conn.execute("COMMIT")
    finally:
        conn.close()


def init_db() -> None:
    """幂等应用建表脚本（与 Monarch 同一份 SQL）。"""
    with open(config.SCHEMA_FILE, "r", encoding="utf-8") as f:
        script = f.read()
    with connect() as conn:
        conn.executescript(script)


def normalize_title(title: str) -> str:
    """标题归一化：小写、去空白与常见标点，用于跨站同名匹配。"""
    text = title.strip().lower()
    text = re.sub(r"[\s\-—_|/\\:：()（）\[\]【】.。·、，,！!？?~～*＊]", "", text)
    return text


# ---------------------------------------------------------------------------
# 站点
# ---------------------------------------------------------------------------

def register_site(code: str, name: str, base_url: str) -> int:
    """注册或更新站点适配器，返回 comic_sites.id。"""
    with transaction() as conn:
        conn.execute(
            """
            INSERT INTO comic_sites (code, name, base_url)
            VALUES (?, ?, ?)
            ON CONFLICT (code) DO UPDATE SET name = excluded.name, base_url = excluded.base_url
            """,
            (code, name, base_url),
        )
        row = conn.execute("SELECT id FROM comic_sites WHERE code = ?", (code,)).fetchone()
        return row["id"]


def _site_row(row: Optional[dict]) -> Optional[dict]:
    """站点行归一化：SQLite 的 0/1 还原为布尔，保持 CLI JSON 契约不变。"""
    if row is None:
        return None
    row["enabled"] = bool(row["enabled"])
    return row


def list_sites() -> list[dict]:
    with connect() as conn:
        rows = conn.execute("SELECT * FROM comic_sites ORDER BY id").fetchall()
    return [_site_row(r) for r in rows]


def get_site_by_code(code: str) -> Optional[dict]:
    with connect() as conn:
        row = conn.execute("SELECT * FROM comic_sites WHERE code = ?", (code,)).fetchone()
    return _site_row(row)


# ---------------------------------------------------------------------------
# 漫画
# ---------------------------------------------------------------------------

def insert_comic(
    title: str,
    site_id: int,
    site_comic_id: str,
    detail_url: str,
    author: str = "",
    status: str = "",
    cover_url: str = "",
) -> int:
    """插入漫画，返回 comics.id（rel_dir 在插入后按 id 回填）。"""
    with transaction() as conn:
        row = conn.execute(
            """
            INSERT INTO comics
                (title, title_normalized, site_id, site_comic_id, detail_url, author, status, cover_url)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            RETURNING id
            """,
            (title, normalize_title(title), site_id, site_comic_id, detail_url,
             author, status, cover_url),
        ).fetchone()
        comic_id = row["id"]
        conn.execute(
            "UPDATE comics SET rel_dir = ? WHERE id = ?", (f"comics/{comic_id}", comic_id)
        )
        return comic_id


def find_comic_by_site(site_id: int, site_comic_id: str) -> Optional[dict]:
    with connect() as conn:
        return conn.execute(
            "SELECT * FROM comics WHERE site_id = ? AND site_comic_id = ?",
            (site_id, site_comic_id),
        ).fetchone()


def find_comics_by_title(title: str) -> list[dict]:
    """按归一化标题查找漫画（跨站同名关联用）。"""
    with connect() as conn:
        return conn.execute(
            "SELECT * FROM comics WHERE title_normalized = ? ORDER BY id",
            (normalize_title(title),),
        ).fetchall()


def get_comic(comic_id: int) -> Optional[dict]:
    with connect() as conn:
        return conn.execute(
            """
            SELECT c.*, s.name AS site_name, s.code AS site_code
            FROM comics c
            JOIN comic_sites s ON s.id = c.site_id
            WHERE c.id = ?
            """,
            (comic_id,),
        ).fetchone()


def list_comics() -> list[dict]:
    with connect() as conn:
        return conn.execute(
            """
            SELECT c.*, s.name AS site_name, s.code AS site_code
            FROM comics c
            JOIN comic_sites s ON s.id = c.site_id
            ORDER BY c.id
            """
        ).fetchall()


def update_comic_meta(
    comic_id: int,
    title: str,
    detail_url: str,
    author: str,
    status: str,
    total_chapters: int,
    max_chapter_no: int,
    cover_url: str = "",
) -> None:
    """更新漫画元信息；cover_url 非空时才覆盖（避免把已有封面地址清空）。"""
    with connect() as conn:
        conn.execute(
            f"""
            UPDATE comics
            SET title = ?, title_normalized = ?, detail_url = ?, author = ?,
                status = ?, total_chapters = ?, max_chapter_no = ?,
                cover_url = CASE WHEN ? <> '' THEN ? ELSE cover_url END,
                updated_at = {_NOW}
            WHERE id = ?
            """,
            (title, normalize_title(title), detail_url, author, status,
             total_chapters, max_chapter_no, cover_url, cover_url, comic_id),
        )


def set_cover_url(comic_id: int, cover_url: str, force: bool = False) -> None:
    """写入站点封面地址。

    默认仅在原值为空时写入（保留既有值）；force=True 时覆盖
    （用于修复历史数据中解析错误或缺失的地址）。
    """
    if not cover_url:
        return
    with connect() as conn:
        if force:
            conn.execute(
                f"""
                UPDATE comics
                SET cover_url = ?, updated_at = {_NOW}
                WHERE id = ? AND cover_url IS NOT ?
                """,
                (cover_url, comic_id, cover_url),
            )
        else:
            conn.execute(
                f"""
                UPDATE comics
                SET cover_url = ?, updated_at = {_NOW}
                WHERE id = ? AND cover_url = ''
                """,
                (cover_url, comic_id),
            )


def delete_comic(comic_id: int) -> bool:
    """删除漫画及其章节/任务（级联），返回是否删除成功。"""
    with connect() as conn:
        return conn.execute("DELETE FROM comics WHERE id = ?", (comic_id,)).rowcount > 0


# ---------------------------------------------------------------------------
# 章节
# ---------------------------------------------------------------------------

def insert_chapters(comic_id: int, site_id: int, chapters: Iterable[dict]) -> list[dict]:
    """批量插入章节，返回 [{chapter_no, chapter_id, title, url, inserted, renumbered}]。

    幂等语义（逐条判定，绝不静默丢章）：
    1. URL 已在**本漫画**下 → 视为已登记，复用该行，并把该行校正到站点序号
       （站点改版后章节顺序会变化，此处 renumber 保证 chapter_no 与站点一致）。
    2. URL 被其他来源占用：本漫画下无该 URL，则作为新行登记，
       序号从站点序号起顺延找空位（不丢章）。
    3. 同 comic_id 下 chapter_no 被别的 URL 占用 → 先把占位行顺延到后面的空位
       （collision bump 接力），再把站点序号让给本章节。
    4. URL 与序号都无冲突 → 直接插入。

    实现要点：按站点序号升序处理，并用本地占用表记录本次分配结果。
    """
    result: list[dict] = []
    ordered = sorted(chapters, key=lambda c: int(c["chapter_no"]))
    with transaction() as conn:
        occupied: dict[int, int] = {
            r["chapter_no"]: r["id"]
            for r in conn.execute(
                "SELECT id, chapter_no FROM comic_chapters WHERE comic_id = ?", (comic_id,)
            ).fetchall()
        }
        by_url: dict[str, tuple[int, int]] = {
            r["url"]: (r["id"], r["chapter_no"])
            for r in conn.execute(
                "SELECT id, chapter_no, url FROM comic_chapters WHERE comic_id = ?", (comic_id,)
            ).fetchall()
        }

        def _reassign(chapter_id: int, new_no: int) -> None:
            for no, cid in list(occupied.items()):
                if cid == chapter_id:
                    del occupied[no]
                    break
            conn.execute(
                f"UPDATE comic_chapters SET chapter_no = ?, updated_at = {_NOW} WHERE id = ?",
                (new_no, chapter_id),
            )
            occupied[new_no] = chapter_id

        for ch in ordered:
            url = ch["url"]
            want_no = max(1, int(ch["chapter_no"]))
            title = ch["title"]

            known = by_url.get(url)
            if known:
                chapter_id, old_no = known
                final_no = old_no
                if want_no != old_no:
                    if want_no in occupied and occupied[want_no] != chapter_id:
                        occupant = occupied[want_no]
                        nxt = want_no + 1
                        while nxt in occupied and occupied[nxt] != occupant:
                            nxt += 1
                        _reassign(occupant, nxt)
                    _reassign(chapter_id, want_no)
                    final_no = want_no
                result.append({
                    "chapter_no": final_no, "chapter_id": chapter_id,
                    "title": title, "url": url,
                    "inserted": False, "renumbered": final_no != old_no,
                })
                continue

            final_no = want_no
            if final_no in occupied:
                nxt = final_no + 1
                while nxt in occupied:
                    nxt += 1
                _reassign(occupied[final_no], nxt)
            row = None
            skipped_reason = ""
            try:
                conn.execute("SAVEPOINT insert_chapter")
                row = conn.execute(
                    """
                    INSERT INTO comic_chapters
                        (comic_id, site_id, chapter_no, title, url)
                    VALUES (?, ?, ?, ?, ?)
                    RETURNING id
                    """,
                    (comic_id, site_id, final_no, title, url),
                ).fetchone()
                conn.execute("RELEASE insert_chapter")
            except sqlite3.IntegrityError:
                conn.execute("ROLLBACK TO insert_chapter")
                conn.execute("RELEASE insert_chapter")
                # 该 URL 已被其他漫画/来源登记（comic_chapters.url 全局唯一）。
                # 不能强行占用序号，否则会让本漫画后续章节全部错位；跳过并如实上报。
                skipped_reason = "url 已被其他漫画登记"
            if row is None:
                result.append({
                    "chapter_no": final_no, "chapter_id": 0,
                    "title": title, "url": url,
                    "inserted": False, "renumbered": False,
                    "skipped_reason": skipped_reason or "插入失败",
                })
                continue
            chapter_id = row["id"]
            conn.execute(
                "UPDATE comic_chapters SET rel_dir = ? WHERE id = ?",
                (f"comics/{comic_id}/{chapter_id}", chapter_id),
            )
            occupied[final_no] = chapter_id
            by_url[url] = (chapter_id, final_no)
            result.append({
                "chapter_no": final_no, "chapter_id": chapter_id,
                "title": title, "url": url,
                "inserted": True, "renumbered": final_no != want_no,
            })
    return result


def _next_free_no(conn, comic_id: int, start_no: int) -> int:
    """返回 >= start_no 的第一个未被占用的 chapter_no。"""
    taken = {
        int(r["chapter_no"])
        for r in conn.execute(
            "SELECT chapter_no FROM comic_chapters WHERE comic_id = ?", (comic_id,)
        ).fetchall()
    }
    no = max(1, start_no)
    while no in taken:
        no += 1
    return no


def _place_chapter_at(conn, comic_id: int, chapter_id: int, want_no: int) -> int:
    """把指定章节放到 want_no：

    - want_no 空闲 → 直接改号；
    - want_no 被别的行占用 → 递归把占位行顺延到下一个空位（接力），再改号。

    返回最终序号。用于修正"站点顺序变化"导致的 chapter_no 错位。
    """
    if want_no < 1:
        want_no = 1
    cur = conn.execute(
        "SELECT chapter_no FROM comic_chapters WHERE id = ?", (chapter_id,)
    ).fetchone()
    if cur and cur["chapter_no"] == want_no:
        return want_no

    occupant = conn.execute(
        "SELECT id FROM comic_chapters "
        "WHERE comic_id = ? AND chapter_no = ? AND id <> ?",
        (comic_id, want_no, chapter_id),
    ).fetchone()

    if occupant:
        _place_chapter_at(conn, comic_id, occupant["id"], want_no + 1)

    conn.execute(
        f"UPDATE comic_chapters SET chapter_no = ?, updated_at = {_NOW} WHERE id = ?",
        (want_no, chapter_id),
    )
    return want_no


def list_chapters(comic_id: int) -> list[dict]:
    with connect() as conn:
        return conn.execute(
            "SELECT * FROM comic_chapters WHERE comic_id = ? ORDER BY chapter_no",
            (comic_id,),
        ).fetchall()


def get_chapter(chapter_id: int) -> Optional[dict]:
    with connect() as conn:
        return conn.execute(
            "SELECT * FROM comic_chapters WHERE id = ?", (chapter_id,)
        ).fetchone()


def update_chapter_status(chapter_id: int, status: str, page_count: int = 0, error: str = "") -> None:
    with connect() as conn:
        conn.execute(
            f"""
            UPDATE comic_chapters
            SET status = ?, page_count = ?, error = ?, updated_at = {_NOW}
            WHERE id = ?
            """,
            (status, page_count, error, chapter_id),
        )


def count_chapters(comic_id: int) -> int:
    with connect() as conn:
        return conn.execute(
            "SELECT count(*) AS n FROM comic_chapters WHERE comic_id = ?", (comic_id,)
        ).fetchone()["n"]


# ---------------------------------------------------------------------------
# 下载任务
# ---------------------------------------------------------------------------

def start_task(comic_id: int, chapter_id: int) -> None:
    with connect() as conn:
        conn.execute(
            f"""
            INSERT INTO comic_download_tasks (comic_id, chapter_id, status, started_at)
            VALUES (?, ?, 'running', {_NOW})
            ON CONFLICT (chapter_id) DO UPDATE
            SET status = 'running', error = '', started_at = {_NOW}
            """,
            (comic_id, chapter_id),
        )


def finish_task(chapter_id: int, status: str, image_count: int = 0, error: str = "") -> None:
    with connect() as conn:
        conn.execute(
            f"""
            UPDATE comic_download_tasks
            SET status = ?, image_count = ?, error = ?, finished_at = {_NOW}
            WHERE chapter_id = ?
            """,
            (status, image_count, error, chapter_id),
        )


def recover_running_tasks(comic_id: int | None = None) -> int:
    """回收进程中断残留的 running 任务（标记为 failed/进程中断）。

    每次下载开始前调用；comic_id 为 None 时回收全部（clean 命令）。
    返回受影响行数。
    """
    sql = (
        "UPDATE comic_download_tasks "
        f"SET status = 'failed', error = '进程中断，任务未完成', finished_at = {_NOW} "
        "WHERE status = 'running'"
    )
    args: tuple = ()
    if comic_id is not None:
        sql += " AND comic_id = ?"
        args = (comic_id,)
    with connect() as conn:
        return conn.execute(sql, args).rowcount


# ---------------------------------------------------------------------------
# 图片记录（供 Go/Flutter 系统读取图片路径与宽高）
# ---------------------------------------------------------------------------

def insert_images(chapter_id: int, images: Iterable[dict]) -> int:
    """写入章节下的图片记录（幂等：同章节同 sort_num 跳过）。返回插入行数。"""
    rows = [
        (chapter_id, img["sort_num"], img["file_name"], img["width"], img["height"])
        for img in images
    ]
    if not rows:
        return 0
    with transaction() as conn:
        cur = conn.executemany(
            """
            INSERT INTO comic_images (chapter_id, sort_num, file_name, width, height)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT (chapter_id, sort_num) DO NOTHING
            """,
            rows,
        )
        return cur.rowcount


def clear_images(chapter_id: int) -> None:
    """删除章节下的全部图片记录（重新下载时先清理，保证与磁盘一致）。"""
    with connect() as conn:
        conn.execute("DELETE FROM comic_images WHERE chapter_id = ?", (chapter_id,))


def replace_images(chapter_id: int, images: Iterable[dict]) -> int:
    """清理并重建章节的图片记录（单事务，避免中途失败留下空记录）。"""
    rows = [
        (chapter_id, img["sort_num"], img["file_name"], img["width"], img["height"])
        for img in images
    ]
    with transaction() as conn:
        conn.execute("DELETE FROM comic_images WHERE chapter_id = ?", (chapter_id,))
        if not rows:
            return 0
        cur = conn.executemany(
            """
            INSERT INTO comic_images (chapter_id, sort_num, file_name, width, height)
            VALUES (?, ?, ?, ?, ?)
            """,
            rows,
        )
        return cur.rowcount


def count_images(comic_id: int) -> int:
    """统计漫画下的图片记录数（供验证）。"""
    with connect() as conn:
        return conn.execute(
            """
            SELECT count(*) AS n FROM comic_images img
            JOIN comic_chapters ch ON ch.id = img.chapter_id
            WHERE ch.comic_id = ?
            """,
            (comic_id,),
        ).fetchone()["n"]


def set_cover_image(comic_id: int, cover_path: str) -> None:
    """写入漫画封面路径（仅在原值为空时）。cover_path 为存储根相对路径。"""
    with connect() as conn:
        conn.execute(
            f"""
            UPDATE comics
            SET cover_image = ?, updated_at = {_NOW}
            WHERE id = ? AND cover_image = ''
            """,
            (cover_path, comic_id),
        )


def get_cover_image(comic_id: int) -> str:
    """读取漫画当前 cover_image（不存在返回空串）。"""
    with connect() as conn:
        row = conn.execute(
            "SELECT cover_image FROM comics WHERE id = ?", (comic_id,)
        ).fetchone()
    return row["cover_image"] if row else ""


def repair_cover_image(comic_id: int, cover_path: str) -> tuple[str, str]:
    """强制校正封面路径（用于补空或修复指向已失效文件的值）。

    返回 (旧值, 新值)；cover_path 为空表示无法计算（如无已下载章节），
    此时仅在旧值指向失效路径的情况下清空。
    """
    with connect() as conn:
        row = conn.execute(
            "SELECT cover_image FROM comics WHERE id = ?", (comic_id,)
        ).fetchone()
        old = row["cover_image"] if row else ""
        if old == cover_path:
            return old, old
        conn.execute(
            f"UPDATE comics SET cover_image = ?, updated_at = {_NOW} WHERE id = ?",
            (cover_path, comic_id),
        )
    return old, cover_path


def first_image_of_comic(comic_id: int) -> str:
    """返回已下载章节（最小 chapter_no）的第一张图片相对路径；无则空串。"""
    with connect() as conn:
        row = conn.execute(
            """
            SELECT ch.rel_dir || '/' || img.file_name AS cover
            FROM comic_chapters ch
            JOIN comic_images img ON img.chapter_id = ch.id
            WHERE ch.comic_id = ? AND ch.status = 'done'
            ORDER BY ch.chapter_no, img.sort_num
            LIMIT 1
            """,
            (comic_id,),
        ).fetchone()
    return row["cover"] if row and row["cover"] else ""
