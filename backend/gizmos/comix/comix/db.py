"""SQLite 数据访问层（stdlib sqlite3）。

与 Go 后端共用同一个单文件库（`DB_PATH`，默认 `backend/data/monarch.db`），
表名扁平化为 `comix_*`（SQLite 没有 schema）。每次调用建立独立连接（无状态），
所有函数返回 dict / dict 列表，便于直接序列化为 JSON。

并发模型（单写者）：
- SQLite 同一时刻只允许一个写者，因此模块级 `threading.Lock` 把本进程内所有写操作
  （下载线程池 COMIX_MAX_WORKERS 个线程共用一个 CLI 进程）串行化；
- 连接级 `busy_timeout` 兜底跨进程竞争（Go 服务同时读写同一个库），
  使爬虫不会把 `database is locked` 抛给 Go 调用方。

时间与布尔约定：
- 时间列一律 TEXT，格式见 `comix.timefmt`（UTC / 毫秒 / 定宽，与 Go `model.TimeFormat` 一致）；
  SQLite 没有 `now()`，插入/更新必须显式写入（`comix_comic.updated_at` 每次 UPDATE 都要带）。
- 布尔列一律 INTEGER 0/1；读取时归一回 Python bool，保证 CLI JSON 仍是 true/false。
"""
from __future__ import annotations

import re
import sqlite3
import threading
from contextlib import contextmanager
from typing import Any, Iterable, Iterator, Optional

from . import config
from .timefmt import now_text

# 单写者锁：把本进程内所有写操作串行化（可重入，便于组合写函数）。
# 取锁顺序固定为「先取锁再开连接」，避免持连接等锁。
_WRITE_LOCK = threading.RLock()

# 跨进程等锁时间（毫秒）：Go 服务用 10s，这里给得更宽裕，避免爬虫先报 database is locked。
_BUSY_TIMEOUT_MS = 15000

# ---------------------------------------------------------------------------
# 建表 SQL（扁平表名；一次 init 即产出全部表与三个只读桥接视图）
# ---------------------------------------------------------------------------

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS comix_site (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    code       TEXT NOT NULL UNIQUE,          -- 适配器标识: manhuayu/morui/nicemh/xmanhua/legacy
    name       TEXT NOT NULL,                 -- 站点名
    base_url   TEXT NOT NULL DEFAULT '',
    enabled    INTEGER NOT NULL DEFAULT 1,    -- 0/1
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS comix_comic (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,  -- 主键永不复用（存储目录名）
    title            TEXT NOT NULL,            -- 漫画名
    title_normalized TEXT NOT NULL DEFAULT '', -- 归一化标题，用于跨站同名关联
    site_id          INTEGER NOT NULL REFERENCES comix_site(id),
    site_comic_id    TEXT NOT NULL DEFAULT '', -- 站内漫画标识（slug/id），同站去重键
    detail_url       TEXT NOT NULL DEFAULT '',
    author           TEXT NOT NULL DEFAULT '',
    status           TEXT NOT NULL DEFAULT '', -- 连载中/已完结等
    cover_url        TEXT NOT NULL DEFAULT '',
    total_chapters   INTEGER NOT NULL DEFAULT 0,  -- 站内章节总数
    max_chapter_no   INTEGER NOT NULL DEFAULT 0,  -- 已登记的最大章节序号
    rel_dir          TEXT NOT NULL DEFAULT '',    -- 存储相对路径: comics/comic_id
    is_public        INTEGER NOT NULL DEFAULT 1,  -- 0/1（Go/Flutter 可更新）
    readed           INTEGER NOT NULL DEFAULT 0,  -- 0/1（Go/Flutter 可更新）
    cover_image      TEXT NOT NULL DEFAULT '',    -- 本地封面相对路径；下载/导入/backfill 显式维护
    created_at       TEXT NOT NULL,
    updated_at       TEXT NOT NULL,
    UNIQUE (site_id, site_comic_id)
);

-- 子表主键用 INTEGER PRIMARY KEY（= rowid 别名）：这些行随父行级联删除、不被外部引用，
-- 不需要 AUTOINCREMENT 的额外 sqlite_sequence 维护。chapter 是例外：chapter.id 就是
-- 磁盘目录名 comics/{comic_id}/{chapter_id}，复用旧 id 会让新章节误命中旧目录，
-- 因此 chapter 也用 AUTOINCREMENT 保证永不复用。
CREATE TABLE IF NOT EXISTS comix_chapter (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    comic_id   INTEGER NOT NULL REFERENCES comix_comic(id) ON DELETE CASCADE,
    site_id    INTEGER NOT NULL REFERENCES comix_site(id),
    chapter_no INTEGER NOT NULL,               -- 站内章节顺序号（1 起）
    title      TEXT NOT NULL DEFAULT '',
    url        TEXT NOT NULL,                  -- 章节页 URL，全局唯一用于跨站去重
    page_count INTEGER NOT NULL DEFAULT 0,
    rel_dir    TEXT NOT NULL DEFAULT '',       -- 存储相对路径: comics/comic_id/chapter_id
    status     TEXT NOT NULL DEFAULT 'pending',-- pending/done/failed
    error      TEXT NOT NULL DEFAULT '',       -- 最近一次失败原因
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE (comic_id, chapter_no),
    UNIQUE (url)
);

CREATE TABLE IF NOT EXISTS comix_image (
    id         INTEGER PRIMARY KEY,
    chapter_id INTEGER NOT NULL REFERENCES comix_chapter(id) ON DELETE CASCADE,
    sort_num   INTEGER NOT NULL,          -- 图片序号（与文件名数字一致，如 005.webp → 5）
    file_name  TEXT NOT NULL,             -- 文件名：001.jpg / 005.webp
    width      INTEGER NOT NULL DEFAULT 0,
    height     INTEGER NOT NULL DEFAULT 0,
    UNIQUE (chapter_id, sort_num)
);

CREATE TABLE IF NOT EXISTS comix_download_task (
    id          INTEGER PRIMARY KEY,
    comic_id    INTEGER NOT NULL REFERENCES comix_comic(id) ON DELETE CASCADE,
    chapter_id  INTEGER NOT NULL REFERENCES comix_chapter(id) ON DELETE CASCADE,
    status      TEXT NOT NULL DEFAULT 'queued', -- queued/running/done/failed/skipped
    image_count INTEGER NOT NULL DEFAULT 0,
    error       TEXT NOT NULL DEFAULT '',
    started_at  TEXT,
    finished_at TEXT,
    UNIQUE (chapter_id)
);

CREATE TABLE IF NOT EXISTS comix_comic_alias (
    id       INTEGER PRIMARY KEY,
    comic_id INTEGER NOT NULL REFERENCES comix_comic(id) ON DELETE CASCADE,
    name     TEXT NOT NULL,                    -- 别名/曾用名，用于跨站标题匹配
    UNIQUE (comic_id, name)
);

CREATE INDEX IF NOT EXISTS idx_chapter_comic ON comix_chapter (comic_id);
CREATE INDEX IF NOT EXISTS idx_task_chapter ON comix_download_task (chapter_id);
CREATE INDEX IF NOT EXISTS idx_image_chapter ON comix_image (chapter_id);

-- 桥接视图 id 系列列是 CAST(... AS TEXT) 表达式，Go 端以 text 连接/WHERE
-- （如 ch.comic_id = b.id）。SQLite 支持表达式索引，建在基表上才能让这些连接走索引
-- （否则 GetAllComicInfos 逐本全扫章节表）。
CREATE INDEX IF NOT EXISTS idx_comic_id_text         ON comix_comic (CAST(id AS TEXT));
CREATE INDEX IF NOT EXISTS idx_chapter_id_text       ON comix_chapter (CAST(id AS TEXT));
CREATE INDEX IF NOT EXISTS idx_chapter_comic_id_text ON comix_chapter (CAST(comic_id AS TEXT));
CREATE INDEX IF NOT EXISTS idx_image_id_text         ON comix_image (CAST(id AS TEXT));
CREATE INDEX IF NOT EXISTS idx_image_chapter_id_text ON comix_image (CAST(chapter_id AS TEXT));

-- 桥接视图：把基表投影成 Go/Flutter 期望的旧结构（只读，无 INSTEAD OF 触发器；
-- Go 端写操作直接落到基表 comix_comic）。
CREATE VIEW IF NOT EXISTS comix_comic_books AS
SELECT CAST(c.id AS TEXT) AS id,
       c.title,
       c.cover_image,
       c.is_public,
       c.readed
FROM comix_comic c;

CREATE VIEW IF NOT EXISTS comix_comic_chapters AS
SELECT CAST(ch.id AS TEXT) AS id,
       CAST(ch.comic_id AS TEXT) AS comic_id,
       substr('000'||ch.chapter_no, -3) || '_' || ch.title AS dir_name,
       ch.chapter_no AS chapter_index
FROM comix_chapter ch;

CREATE VIEW IF NOT EXISTS comix_comic_images AS
SELECT CAST(img.id AS TEXT) AS id,
       CAST(img.chapter_id AS TEXT) AS chapter_id,
       ch.rel_dir || '/' || img.file_name AS image_path,
       img.sort_num,
       img.width,
       img.height
FROM comix_image img
JOIN comix_chapter ch ON ch.id = img.chapter_id;
"""

# 期望的视图定义（用于 init 时对齐历史库的旧定义；SQLite 没有 CREATE OR REPLACE VIEW）
VIEWS = (
    ("comix_comic_books", """
        SELECT CAST(c.id AS TEXT) AS id, c.title, c.cover_image, c.is_public, c.readed
        FROM comix_comic c
    """),
    ("comix_comic_chapters", """
        SELECT CAST(ch.id AS TEXT) AS id, CAST(ch.comic_id AS TEXT) AS comic_id,
               substr('000'||ch.chapter_no, -3) || '_' || ch.title AS dir_name,
               ch.chapter_no AS chapter_index
        FROM comix_chapter ch
    """),
    ("comix_comic_images", """
        SELECT CAST(img.id AS TEXT) AS id, CAST(img.chapter_id AS TEXT) AS chapter_id,
               ch.rel_dir || '/' || img.file_name AS image_path,
               img.sort_num, img.width, img.height
        FROM comix_image img
        JOIN comix_chapter ch ON ch.id = img.chapter_id
    """),
)

# 幂等补丁：老库升级的新增列（SQLite 不支持 ADD COLUMN IF NOT EXISTS，改用 PRAGMA 守卫）。
PATCH_COLUMNS = (
    ("comix_chapter", "error", "TEXT NOT NULL DEFAULT ''"),
    ("comix_comic", "is_public", "INTEGER NOT NULL DEFAULT 1"),
    ("comix_comic", "readed", "INTEGER NOT NULL DEFAULT 0"),
    ("comix_comic", "cover_image", "TEXT NOT NULL DEFAULT ''"),
)


# ---------------------------------------------------------------------------
# 连接与建表
# ---------------------------------------------------------------------------

@contextmanager
def connect(create: bool = False) -> Iterator[sqlite3.Connection]:
    """建立数据库连接（sqlite3.Row 行工厂）。

    退出时提交并**关闭**连接：`sqlite3.Connection.__exit__` 只提交/回滚、不关闭文件句柄，
    若只写 `with connect()` 会每调用一次泄漏一个句柄（本模块 40+ 调用点，下载线程池会放大）。

    PRAGMA 逐连接设置（除 journal_mode 外都是连接级）：
    - `foreign_keys=ON`：SQLite 默认 OFF，所有 ON DELETE CASCADE 都依赖它；
    - `journal_mode=WAL` + `synchronous=NORMAL`：读写互不阻塞；
    - `busy_timeout`：跨进程（Go 服务）写竞争时等待而非立刻报错。

    `create=True` 仅由 `init_db()` 使用：允许库文件不存在时新建目录与文件。
    """
    path = config.db_file()
    if not path.exists():
        if not create:
            raise RuntimeError(
                f"数据库文件不存在: {path}（请先执行 python -m comix.cli init）"
            )
        path.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(str(path), timeout=_BUSY_TIMEOUT_MS / 1000)
    try:
        conn.row_factory = sqlite3.Row
        # 事务由本模块显式管理（BEGIN/COMMIT），关闭 sqlite3 的隐式事务
        conn.isolation_level = None
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute(f"PRAGMA busy_timeout={_BUSY_TIMEOUT_MS}")
        conn.execute("PRAGMA synchronous=NORMAL")
        conn.execute("PRAGMA foreign_keys=ON")
        yield conn
        conn.commit()
    except BaseException:
        conn.rollback()
        raise
    finally:
        conn.close()


@contextmanager
def _write_lock() -> Iterator[None]:
    """写操作串行化锁（见模块 docstring：SQLite 同一时刻只允许一个写者）。"""
    with _WRITE_LOCK:
        yield


@contextmanager
def transaction(conn: sqlite3.Connection) -> Iterator[sqlite3.Connection]:
    """显式事务：`BEGIN IMMEDIATE` 直接取写锁，避免"读事务升级为写"的死锁。

    SQLite 下单条语句违反约束只回滚该语句、不中止整个事务，因此本模块不再需要
    PostgreSQL 的保存点（SAVEPOINT）：冲突处直接 try/except 即可。
    """
    conn.execute("BEGIN IMMEDIATE")
    try:
        yield conn
        conn.execute("COMMIT")
    except BaseException:
        conn.execute("ROLLBACK")
        raise


def init_db() -> None:
    """幂等建表 + 视图 + 补丁（与 Go 服务共用同一个库文件）。"""
    with _write_lock(), connect(create=True) as conn:
        # 显式事务包裹整段 DDL：中途失败整体回滚，不留半套表
        conn.executescript("BEGIN IMMEDIATE;\n" + SCHEMA_SQL + "\nCOMMIT;")
        with transaction(conn):
            _patch_columns(conn)
            _ensure_views(conn)


def _has_column(conn: sqlite3.Connection, table: str, column: str) -> bool:
    """PRAGMA table_info 守卫（表名来自本模块常量，不接外部输入）。"""
    return any(row["name"] == column for row in conn.execute(f"PRAGMA table_info({table})"))


def _patch_columns(conn: sqlite3.Connection) -> None:
    """老库升级：仅缺失列才 ALTER TABLE ADD COLUMN（幂等）。"""
    for table, column, declaration in PATCH_COLUMNS:
        if not _has_column(conn, table, column):
            conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {declaration}")


def _normalize_sql(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _ensure_views(conn: sqlite3.Connection) -> None:
    """把视图定义对齐到本模块的期望定义（只读视图，重建无数据风险）。

    仅在定义不一致时 DROP + CREATE：避免每次 init 都改动 sqlite_master
    （那会让正在查询的 Go 服务连接被迫重编译语句）。
    """
    for name, definition in VIEWS:
        row = conn.execute(
            "SELECT sql FROM sqlite_master WHERE type = 'view' AND name = ?", (name,)
        ).fetchone()
        expected = f"CREATE VIEW {name} AS {definition}"
        if row and _normalize_sql(row["sql"]) == _normalize_sql(expected):
            continue
        conn.execute(f"DROP VIEW IF EXISTS {name}")
        conn.execute(f"CREATE VIEW {name} AS {definition}")


# ---------------------------------------------------------------------------
# 行 → dict
# ---------------------------------------------------------------------------

# 布尔列：SQLite 存 0/1，对外（CLI JSON）仍是 true/false，避免协议形状漂移
_BOOL_COLUMNS = frozenset({"enabled", "is_public", "readed"})


def _dict(row: Optional[sqlite3.Row]) -> Optional[dict]:
    """sqlite3.Row → dict（布尔列归一为 bool）。"""
    if row is None:
        return None
    result: dict[str, Any] = dict(row)
    for column in _BOOL_COLUMNS & result.keys():
        value = result[column]
        if value is not None:
            result[column] = bool(value)
    return result


def _dicts(rows: Iterable[sqlite3.Row]) -> list[dict]:
    return [_dict(row) for row in rows]  # type: ignore[misc]


def normalize_title(title: str) -> str:
    """标题归一化：小写、去空白与常见标点，用于跨站同名匹配。"""
    text = title.strip().lower()
    text = re.sub(r"[\s\-—_|/\\:：()（）\[\]【】.。·、，,！!？?~～*＊]", "", text)
    return text


# ---------------------------------------------------------------------------
# 站点
# ---------------------------------------------------------------------------

def register_site(code: str, name: str, base_url: str) -> int:
    """注册或更新站点适配器，返回 site.id。"""
    with _write_lock(), connect() as conn:
        conn.execute(
            """
            INSERT INTO comix_site (code, name, base_url, created_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT (code) DO UPDATE SET name = excluded.name, base_url = excluded.base_url
            """,
            (code, name, base_url, now_text()),
        )
        row = conn.execute("SELECT id FROM comix_site WHERE code = ?", (code,)).fetchone()
        return int(row["id"])


def list_sites() -> list[dict]:
    with connect() as conn:
        return _dicts(conn.execute("SELECT * FROM comix_site ORDER BY id").fetchall())


def get_site_by_code(code: str) -> Optional[dict]:
    with connect() as conn:
        return _dict(
            conn.execute("SELECT * FROM comix_site WHERE code = ?", (code,)).fetchone()
        )


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
    """插入漫画，返回 comic.id（rel_dir 在插入后按 id 回填）。"""
    with _write_lock(), connect() as conn:
        with transaction(conn):
            now = now_text()
            cur = conn.execute(
                """
                INSERT INTO comix_comic
                    (title, title_normalized, site_id, site_comic_id, detail_url,
                     author, status, cover_url, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (title, normalize_title(title), site_id, site_comic_id, detail_url,
                 author, status, cover_url, now, now),
            )
            comic_id = int(cur.lastrowid)
            conn.execute(
                "UPDATE comix_comic SET rel_dir = ? WHERE id = ?",
                (f"comics/{comic_id}", comic_id),
            )
            return comic_id


def find_comic_by_site(site_id: int, site_comic_id: str) -> Optional[dict]:
    with connect() as conn:
        return _dict(
            conn.execute(
                "SELECT * FROM comix_comic WHERE site_id = ? AND site_comic_id = ?",
                (site_id, site_comic_id),
            ).fetchone()
        )


def find_comics_by_title(title: str) -> list[dict]:
    """按归一化标题查找漫画（跨站同名关联用）。"""
    with connect() as conn:
        return _dicts(
            conn.execute(
                "SELECT * FROM comix_comic WHERE title_normalized = ? ORDER BY id",
                (normalize_title(title),),
            ).fetchall()
        )


def get_comic(comic_id: int) -> Optional[dict]:
    with connect() as conn:
        return _dict(
            conn.execute(
                """
                SELECT c.*, s.name AS site_name, s.code AS site_code
                FROM comix_comic c
                JOIN comix_site s ON s.id = c.site_id
                WHERE c.id = ?
                """,
                (comic_id,),
            ).fetchone()
        )


def list_comics() -> list[dict]:
    with connect() as conn:
        return _dicts(
            conn.execute(
                """
                SELECT c.*, s.name AS site_name, s.code AS site_code
                FROM comix_comic c
                JOIN comix_site s ON s.id = c.site_id
                ORDER BY c.id
                """
            ).fetchall()
        )


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
    with _write_lock(), connect() as conn:
        conn.execute(
            """
            UPDATE comix_comic
            SET title = ?, title_normalized = ?, detail_url = ?, author = ?,
                status = ?, total_chapters = ?, max_chapter_no = ?,
                cover_url = CASE WHEN ? <> '' THEN ? ELSE cover_url END,
                updated_at = ?
            WHERE id = ?
            """,
            (title, normalize_title(title), detail_url, author, status,
             total_chapters, max_chapter_no, cover_url, cover_url,
             now_text(), comic_id),
        )


def set_cover_url(comic_id: int, cover_url: str, force: bool = False) -> None:
    """写入站点封面地址。

    默认仅在原值为空时写入（保留既有值）；force=True 时覆盖
    （用于修复历史数据中解析错误或缺失的地址）。
    """
    if not cover_url:
        return
    with _write_lock(), connect() as conn:
        if force:
            conn.execute(
                """
                UPDATE comix_comic
                SET cover_url = ?, updated_at = ?
                WHERE id = ? AND cover_url IS NOT ?
                """,
                (cover_url, now_text(), comic_id, cover_url),
            )
        else:
            conn.execute(
                """
                UPDATE comix_comic
                SET cover_url = ?, updated_at = ?
                WHERE id = ? AND cover_url = ''
                """,
                (cover_url, now_text(), comic_id),
            )


def delete_comic(comic_id: int) -> bool:
    """删除漫画及其章节/任务（级联），返回是否删除成功。"""
    with _write_lock(), connect() as conn:
        cur = conn.execute("DELETE FROM comix_comic WHERE id = ?", (comic_id,))
        return cur.rowcount > 0


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
    "新章节占用序号"时，被占位的旧行只会向后顺延，不会反过来把新章节挤到后面，
    一轮即得到与站点一致的顺序。
    """
    result: list[dict] = []
    ordered = sorted(chapters, key=lambda c: int(c["chapter_no"]))
    with _write_lock(), connect() as conn:
        # 整批一个真实事务；单条 INSERT 的唯一冲突只回滚该语句（SQLite 语义），
        # 不会中止事务，因此冲突章节可跳过并如实上报，其余章节照常写入。
        with transaction(conn):
            # 序号占用表：chapter_no -> chapter_id（本次批量内既看见库中行、也看见刚插入的行）
            occupied: dict[int, int] = {
                r["chapter_no"]: r["id"]
                for r in conn.execute(
                    "SELECT id, chapter_no FROM comix_chapter WHERE comic_id = ?",
                    (comic_id,),
                ).fetchall()
            }
            by_url: dict[str, tuple[int, int]] = {
                r["url"]: (r["id"], r["chapter_no"])
                for r in conn.execute(
                    "SELECT id, chapter_no, url FROM comix_chapter WHERE comic_id = ?",
                    (comic_id,),
                ).fetchall()
            }

            def _reassign(chapter_id: int, new_no: int) -> None:
                for no, cid in list(occupied.items()):
                    if cid == chapter_id:
                        del occupied[no]
                        break
                conn.execute(
                    "UPDATE comix_chapter SET chapter_no = ?, updated_at = ? WHERE id = ?",
                    (new_no, now_text(), chapter_id),
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
                            # 让位：把当前占位行顺延到下一个空位（接力）
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

                # 新 URL：站点序号优先，占位行让位；序号被占满则顺延到最近空位
                final_no = want_no
                if final_no in occupied:
                    nxt = final_no + 1
                    while nxt in occupied:
                        nxt += 1
                    _reassign(occupied[final_no], nxt)
                chapter_id = 0
                skipped_reason = ""
                try:
                    now = now_text()
                    cur = conn.execute(
                        """
                        INSERT INTO comix_chapter
                            (comic_id, site_id, chapter_no, title, url, created_at, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                        (comic_id, site_id, final_no, title, url, now, now),
                    )
                    chapter_id = int(cur.lastrowid)
                except sqlite3.IntegrityError as exc:
                    # 唯一约束冲突只回滚本语句，不中止整批事务（无需 SAVEPOINT）。
                    message = str(exc)
                    if "comix_chapter.url" in message:
                        # 该 URL 已被其他漫画/来源登记（chapter.url 全局唯一）。
                        # 不能强行占用序号，否则会让本漫画后续章节全部错位；跳过并如实上报。
                        skipped_reason = "url 已被其他漫画登记"
                    elif "comic_id, comix_chapter.chapter_no" in message:
                        # 不允许静默丢章：chapter_no 冲突必须如实上报（见 comix/AGENTS.md）
                        skipped_reason = "chapter_no 冲突（序号让位未覆盖）"
                    else:
                        skipped_reason = message
                if not chapter_id:
                    result.append({
                        "chapter_no": final_no, "chapter_id": 0,
                        "title": title, "url": url,
                        "inserted": False, "renumbered": False,
                        "skipped_reason": skipped_reason or "插入失败",
                    })
                    continue
                conn.execute(
                    "UPDATE comix_chapter SET rel_dir = ? WHERE id = ?",
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
            "SELECT chapter_no FROM comix_chapter WHERE comic_id = ?", (comic_id,)
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
    本函数只发语句，事务由调用方提供（见 scheduler.sync_comics）。
    """
    if want_no < 1:
        want_no = 1
    cur = conn.execute(
        "SELECT chapter_no FROM comix_chapter WHERE id = ?", (chapter_id,)
    ).fetchone()
    if cur and cur["chapter_no"] == want_no:
        return want_no

    occupant = conn.execute(
        "SELECT id FROM comix_chapter WHERE comic_id = ? AND chapter_no = ? AND id <> ?",
        (comic_id, want_no, chapter_id),
    ).fetchone()

    if occupant:
        _place_chapter_at(conn, comic_id, occupant["id"], want_no + 1)

    conn.execute(
        "UPDATE comix_chapter SET chapter_no = ?, updated_at = ? WHERE id = ?",
        (want_no, now_text(), chapter_id),
    )
    return want_no


def list_chapters(comic_id: int) -> list[dict]:
    with connect() as conn:
        return _dicts(
            conn.execute(
                "SELECT * FROM comix_chapter WHERE comic_id = ? ORDER BY chapter_no",
                (comic_id,),
            ).fetchall()
        )


def get_chapter(chapter_id: int) -> Optional[dict]:
    with connect() as conn:
        return _dict(
            conn.execute(
                "SELECT * FROM comix_chapter WHERE id = ?", (chapter_id,)
            ).fetchone()
        )


def update_chapter_status(chapter_id: int, status: str, page_count: int = 0, error: str = "") -> None:
    with _write_lock(), connect() as conn:
        conn.execute(
            """
            UPDATE comix_chapter
            SET status = ?, page_count = ?, error = ?, updated_at = ?
            WHERE id = ?
            """,
            (status, page_count, error, now_text(), chapter_id),
        )


def count_chapters(comic_id: int) -> int:
    with connect() as conn:
        return int(
            conn.execute(
                "SELECT count(*) AS n FROM comix_chapter WHERE comic_id = ?", (comic_id,)
            ).fetchone()["n"]
        )


# ---------------------------------------------------------------------------
# 下载任务
# ---------------------------------------------------------------------------

def start_task(comic_id: int, chapter_id: int) -> None:
    with _write_lock(), connect() as conn:
        conn.execute(
            """
            INSERT INTO comix_download_task
                (comic_id, chapter_id, status, started_at)
            VALUES (?, ?, 'running', ?)
            ON CONFLICT (chapter_id) DO UPDATE
                SET status = 'running', error = '', started_at = excluded.started_at
            """,
            (comic_id, chapter_id, now_text()),
        )


def finish_task(chapter_id: int, status: str, image_count: int = 0, error: str = "") -> None:
    with _write_lock(), connect() as conn:
        conn.execute(
            """
            UPDATE comix_download_task
            SET status = ?, image_count = ?, error = ?, finished_at = ?
            WHERE chapter_id = ?
            """,
            (status, image_count, error, now_text(), chapter_id),
        )


def recover_running_tasks(comic_id: int | None = None) -> int:
    """回收进程中断残留的 running 任务（标记为 failed/进程中断）。

    每次下载开始前调用；comic_id 为 None 时回收全部（clean 命令）。
    返回受影响行数。
    """
    with _write_lock(), connect() as conn:
        if comic_id is not None:
            cur = conn.execute(
                """
                UPDATE comix_download_task
                SET status = 'failed', error = '进程中断，任务未完成', finished_at = ?
                WHERE status = 'running' AND comic_id = ?
                """,
                (now_text(), comic_id),
            )
        else:
            cur = conn.execute(
                """
                UPDATE comix_download_task
                SET status = 'failed', error = '进程中断，任务未完成', finished_at = ?
                WHERE status = 'running'
                """,
                (now_text(),),
            )
        return cur.rowcount


# ---------------------------------------------------------------------------
# 图片记录（comix_image：供 Go/Flutter 系统经视图读取图片路径与宽高）
# ---------------------------------------------------------------------------

def insert_images(chapter_id: int, images: Iterable[dict]) -> int:
    """写入章节下的图片记录（幂等：同章节同 sort_num 跳过）。

    images: [{"sort_num": 1, "file_name": "001.jpg", "width": 800, "height": 1188}]
    返回插入行数。
    """
    inserted = 0
    with _write_lock(), connect() as conn:
        with transaction(conn):
            for img in images:
                cur = conn.execute(
                    """
                    INSERT INTO comix_image
                        (chapter_id, sort_num, file_name, width, height)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT (chapter_id, sort_num) DO NOTHING
                    """,
                    (chapter_id, img["sort_num"], img["file_name"],
                     img["width"], img["height"]),
                )
                inserted += cur.rowcount
    return inserted


def clear_images(chapter_id: int) -> None:
    """删除章节下的全部图片记录（重新下载时先清理，保证与磁盘一致）。"""
    with _write_lock(), connect() as conn:
        conn.execute("DELETE FROM comix_image WHERE chapter_id = ?", (chapter_id,))


def count_images(comic_id: int) -> int:
    """统计漫画下的图片记录数（供验证）。"""
    with connect() as conn:
        return int(
            conn.execute(
                """
                SELECT count(*) AS n FROM comix_image img
                JOIN comix_chapter ch ON ch.id = img.chapter_id
                WHERE ch.comic_id = ?
                """,
                (comic_id,),
            ).fetchone()["n"]
        )


def set_cover_image(comic_id: int, cover_path: str) -> None:
    """写入漫画封面路径（仅在原值为空时）。cover_path 为相对存储根路径。"""
    with _write_lock(), connect() as conn:
        conn.execute(
            """
            UPDATE comix_comic
            SET cover_image = ?, updated_at = ?
            WHERE id = ? AND cover_image = ''
            """,
            (cover_path, now_text(), comic_id),
        )


def get_cover_image(comic_id: int) -> str:
    """读取漫画当前 cover_image（不存在返回空串）。"""
    with connect() as conn:
        row = conn.execute(
            "SELECT cover_image FROM comix_comic WHERE id = ?", (comic_id,)
        ).fetchone()
    return row["cover_image"] if row else ""


def repair_cover_image(comic_id: int, cover_path: str) -> tuple[str, str]:
    """强制校正封面路径（用于补空或修复指向已失效文件的值）。

    返回 (旧值, 新值)；cover_path 为空表示无法计算（如无已下载章节），
    此时仅在旧值指向失效路径的情况下清空。
    """
    with _write_lock(), connect() as conn:
        row = conn.execute(
            "SELECT cover_image FROM comix_comic WHERE id = ?", (comic_id,)
        ).fetchone()
        old = row["cover_image"] if row else ""
        if old == cover_path:
            return old, old
        conn.execute(
            """
            UPDATE comix_comic
            SET cover_image = ?, updated_at = ?
            WHERE id = ?
            """,
            (cover_path, now_text(), comic_id),
        )
    return old, cover_path


def first_image_of_comic(comic_id: int) -> str:
    """返回已下载章节（最小 chapter_no）的第一张图片相对路径；无则空串。"""
    with connect() as conn:
        row = conn.execute(
            """
            SELECT ch.rel_dir || '/' || img.file_name AS cover
            FROM comix_chapter ch
            JOIN comix_image img ON img.chapter_id = ch.id
            WHERE ch.comic_id = ? AND ch.status = 'done'
            ORDER BY ch.chapter_no, img.sort_num
            LIMIT 1
            """,
            (comic_id,),
        ).fetchone()
    return row["cover"] if row and row["cover"] else ""
