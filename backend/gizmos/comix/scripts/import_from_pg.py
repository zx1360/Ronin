"""一次性导入：PostgreSQL 的 comix.* 数据 → 共享 SQLite 库的 comix_* 表。

安全流程（PostgreSQL 只读、SQLite 可重跑）：

1. 先用同一份 SQLite 库建好 comix_* 表与桥接视图：
       python -m comix.cli init
   （未建表时本脚本拒绝运行，不会替你改动库结构）
2. 设好 PostgreSQL 连接环境变量（标准 libpq 变量；未设置时用括号内默认值）：
       PGHOST(localhost) / PGPORT(5432) / PGUSER(postgres)
       PGDATABASE(monarch) / PGPASSWORD(无默认值，未设置则走 .pgpass/peer 认证)
       例：$env:PGPASSWORD="..."; python scripts/import_from_pg.py
3. 脚本在 PostgreSQL 侧开启**只读事务**（连接级 default_transaction_read_only=on
   + SET TRANSACTION READ ONLY），全程只发 SELECT，生产库不可能被修改；
4. 每个表一个 SQLite 事务，逐表 INSERT ... ON CONFLICT (id) DO NOTHING：
   id 稳定保留，重复运行安全（已导入的行跳过）；
5. 结束时逐表比较两边行数，任何不一致即以非零退出码失败（exit 1）。

回退：删除 SQLite 库文件（或仅删除本次写入的 comix_* 行）即回到导入前状态；
PostgreSQL 全程只读、未做任何修改，因此无需回退步骤。

依赖：psycopg 仅本一次性脚本需要，不在运行时 requirements.txt 里：
    pip install "psycopg[binary]>=3.1"
"""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

try:  # 仅一次性导入脚本需要，按需安装，运行时不依赖
    import psycopg
    from psycopg.rows import dict_row
except ImportError:  # pragma: no cover - 环境相关
    raise SystemExit(
        "缺少 psycopg（仅本一次性导入脚本需要）："
        'pip install "psycopg[binary]>=3.1"'
    )

from comix import config, db
from comix.timefmt import format_time

# ---------------------------------------------------------------------------
# 表清单（按外键依赖顺序：site → comic → chapter → image/download_task/alias）
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class TableSpec:
    pg_table: str        # PostgreSQL：库 monarch，schema comix
    sqlite_table: str    # SQLite：扁平表名
    columns: tuple[str, ...]
    bool_columns: tuple[str, ...] = ()
    time_columns: tuple[str, ...] = ()


SPECS: tuple[TableSpec, ...] = (
    TableSpec(
        "comix.site", "comix_site",
        ("id", "code", "name", "base_url", "enabled", "created_at"),
        bool_columns=("enabled",),
        time_columns=("created_at",),
    ),
    TableSpec(
        "comix.comic", "comix_comic",
        ("id", "title", "title_normalized", "site_id", "site_comic_id", "detail_url",
         "author", "status", "cover_url", "total_chapters", "max_chapter_no", "rel_dir",
         "is_public", "readed", "cover_image", "created_at", "updated_at"),
        bool_columns=("is_public", "readed"),
        time_columns=("created_at", "updated_at"),
    ),
    TableSpec(
        "comix.chapter", "comix_chapter",
        ("id", "comic_id", "site_id", "chapter_no", "title", "url",
         "page_count", "rel_dir", "status", "error", "created_at", "updated_at"),
        time_columns=("created_at", "updated_at"),
    ),
    TableSpec(
        "comix.image", "comix_image",
        ("id", "chapter_id", "sort_num", "file_name", "width", "height"),
    ),
    TableSpec(
        "comix.download_task", "comix_download_task",
        ("id", "comic_id", "chapter_id", "status", "image_count", "error",
         "started_at", "finished_at"),
        time_columns=("started_at", "finished_at"),
    ),
    TableSpec(
        "comix.comic_alias", "comix_comic_alias",
        ("id", "comic_id", "name"),
    ),
)

REQUIRED_SQLITE_TABLES = tuple(spec.sqlite_table for spec in SPECS)
REQUIRED_SQLITE_VIEWS = ("comix_comic_books", "comix_comic_chapters", "comix_comic_images")


# ---------------------------------------------------------------------------
# 辅助
# ---------------------------------------------------------------------------

def _pg_kwargs() -> dict:
    """PostgreSQL 连接参数：标准 libpq 环境变量，未设置时用本项目原有默认值。

    显式给 host/port/user/dbname 默认值（而不是交给 libpq），避免未设 PGUSER 时
    意外以操作系统用户名连接；密码只从 PGPASSWORD 取，未设置则交给 .pgpass/peer 认证。
    """
    kwargs: dict = {
        "host": os.getenv("PGHOST", "localhost"),
        "port": os.getenv("PGPORT", "5432"),
        "user": os.getenv("PGUSER", "postgres"),
        "dbname": os.getenv("PGDATABASE", "monarch"),
    }
    if password := os.getenv("PGPASSWORD"):
        kwargs["password"] = password
    # 连接级只读：即使后续语句写错也不可能改动生产库
    kwargs["options"] = "-c default_transaction_read_only=on"
    return kwargs


def _describe_target(kwargs: dict) -> str:
    return (f"host={kwargs.get('host', '(默认)')} port={kwargs.get('port', '(默认)')} "
            f"user={kwargs.get('user', '(默认)')} dbname={kwargs['dbname']}")


def _convert(spec: TableSpec, row: dict) -> list:
    """TIMESTAMPTZ → 定宽 TEXT；BOOLEAN → 0/1；其余原样（id 保持不变）。"""
    values: list = []
    for column in spec.columns:
        value = row[column]
        if value is None:
            values.append(None)
        elif column in spec.bool_columns:
            values.append(1 if value else 0)
        elif column in spec.time_columns:
            if isinstance(value, datetime):
                values.append(format_time(value))
            elif isinstance(value, date):
                values.append(format_time(datetime(value.year, value.month, value.day)))
            else:
                values.append(str(value))
        else:
            values.append(value)
    return values


def _check_sqlite_schema(conn) -> list[str]:
    """返回缺失的表/视图名（空表示可直接导入）。"""
    present = {
        row["name"]
        for row in conn.execute(
            "SELECT name FROM sqlite_master WHERE type IN ('table', 'view')"
        ).fetchall()
    }
    missing = [t for t in REQUIRED_SQLITE_TABLES if t not in present]
    missing += [v for v in REQUIRED_SQLITE_VIEWS if v not in present]
    return missing


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except Exception:
            pass

    # 1) SQLite 侧必须先有 schema（本脚本绝不改动表结构）
    if not config.db_file().exists():
        print(f"[中止] 数据库文件不存在: {config.db_file()}"
              f"（请先执行 python -m comix.cli init）")
        return 2

    with db.connect() as conn:
        missing = _check_sqlite_schema(conn)
        if missing:
            print("[中止] SQLite 库缺少以下表/视图，请先执行 python -m comix.cli init：")
            for name in missing:
                print(f"  - {name}")
            print(f"      库文件: {config.DB_PATH}")
            return 2

        kwargs = _pg_kwargs()
        print(f"[连接] PostgreSQL: {_describe_target(kwargs)}"
              + ("" if "password" in kwargs else "（未设 PGPASSWORD，按 .pgpass/peer 认证）"))
        print(f"[目标] SQLite: {config.DB_PATH}")

        inserted: dict[str, int] = {}
        with psycopg.connect(row_factory=dict_row, autocommit=False, **kwargs) as pg:
            # 只读事务：PostgreSQL 侧全程 SELECT，绝不写生产库
            with pg.transaction():
                pg.execute("SET TRANSACTION READ ONLY")

                for spec in SPECS:
                    columns = ", ".join(spec.columns)
                    placeholders = ", ".join("?" for _ in spec.columns)
                    sql = (
                        f"INSERT INTO {spec.sqlite_table} ({columns}) "
                        f"VALUES ({placeholders}) ON CONFLICT (id) DO NOTHING"
                    )
                    count = 0
                    # 服务端游标：28 万行图片不必一次性读进内存
                    with pg.cursor(name=f"cur_{spec.sqlite_table}") as cur:
                        cur.itersize = 2000
                        cur.execute(f"SELECT {columns} FROM {spec.pg_table} ORDER BY id")
                        # 每表一个事务：中途失败只影响本表，重跑安全
                        with db._write_lock(), db.transaction(conn):  # noqa: SLF001 - 复用数据层写锁
                            for row in cur:
                                result = conn.execute(sql, _convert(spec, row))
                                count += result.rowcount
                    inserted[spec.sqlite_table] = count
                    print(f"[导入] {spec.pg_table} → {spec.sqlite_table}: 新增 {count} 行")

        # 2) 逐表行数比对，任何不一致都算失败
        print("\n[校验] 行数比对（PostgreSQL vs SQLite）")
        mismatched: list[str] = []
        with psycopg.connect(row_factory=dict_row, autocommit=False, **kwargs) as pg:
            with pg.transaction():
                pg.execute("SET TRANSACTION READ ONLY")
                for spec in SPECS:
                    pg_count = pg.execute(
                        f"SELECT count(*) AS n FROM {spec.pg_table}"
                    ).fetchone()["n"]
                    sq_count = conn.execute(
                        f"SELECT count(*) AS n FROM {spec.sqlite_table}"
                    ).fetchone()["n"]
                    ok = pg_count == sq_count
                    if not ok:
                        mismatched.append(spec.sqlite_table)
                    print(f"  {'OK  ' if ok else 'FAIL'} {spec.sqlite_table:<20} "
                          f"PG={pg_count:<8} SQLite={sq_count:<8} 新增={inserted[spec.sqlite_table]}")

        if mismatched:
            print(f"\n[失败] 行数不一致: {', '.join(mismatched)}"
                  f"（SQLite 库可能已有爬虫写入的行，或导入被中断；请核对后重跑）")
            return 1
        print("\n[完成] 全部表行数一致；PostgreSQL 侧全程只读，未做任何修改。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
