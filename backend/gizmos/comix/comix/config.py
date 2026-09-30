"""全局配置。

数据库文件与漫画存储根目录由 **Ronin 后端根目录的 .env**（backend/.env）统一持有，
Go 服务调用本 CLI 时会直接注入 `MONARCH_DB_FILE` / `COMIC_STORAGE_ROOT` 环境变量；
本文件的两级 .env 加载只是为了让 comix 能独立运行（调试/运维脚本）。

加载顺序：先 backend/.env（数据库与存储根），再本项目 .env（爬虫专用参数，可覆盖）。
"""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# comix 项目根（comix 包的上一级）：backend/gizmos/comix
PROJECT_ROOT = Path(__file__).resolve().parent.parent
# Ronin 后端根（backend/）：数据库与存储根配置的真源
BACKEND_ROOT = PROJECT_ROOT.parent.parent

load_dotenv(BACKEND_ROOT / ".env")
load_dotenv(PROJECT_ROOT / ".env", override=True)


def _resolve(raw: str, default: Path) -> str:
    """相对路径一律按 backend/ 解析，统一为规范化的绝对路径。"""
    value = raw.strip() if raw else ""
    path = Path(value) if value else default
    if not path.is_absolute():
        path = BACKEND_ROOT / path
    return str(path.resolve())


# 单文件 SQLite 数据库（与 Monarch、gizmos 共用）
DB_FILE = _resolve(
    os.getenv("MONARCH_DB_FILE") or os.getenv("DB_FILE", ""),
    BACKEND_ROOT / "data" / "monarch.db",
)

# 建表脚本真源（Monarch 启动时执行同一份脚本）
SCHEMA_FILE = str(BACKEND_ROOT / "references" / "db" / "sqlite.sql")

# 漫画存储根目录（其下直接是 {comic_id}/{chapter_id}/... 与 legacy 名称目录）
COMIC_STORAGE_ROOT = _resolve(
    os.getenv("COMIC_STORAGE_ROOT", ""),
    BACKEND_ROOT.parent / "_static" / "comics",
)

# 下载并发与稳定性配置
COMIX_MAX_WORKERS = int(os.getenv("COMIX_MAX_WORKERS", "2"))
IMG_TIMEOUT_SEC = int(os.getenv("IMG_TIMEOUT_SEC", "20"))
IMAGE_RETRY_TIMES = int(os.getenv("IMAGE_RETRY_TIMES", "4"))
PAGE_TIMEOUT_SEC = int(os.getenv("PAGE_TIMEOUT_SEC", "20"))
CHAPTER_RETRY_TIMES = int(os.getenv("CHAPTER_RETRY_TIMES", "2"))


def ensure_storage_root() -> Path:
    """确保存储根目录存在，返回其 Path。"""
    root = Path(COMIC_STORAGE_ROOT)
    root.mkdir(parents=True, exist_ok=True)
    return root


def storage_path(rel_dir: str) -> str:
    """把 DB 中的 rel_dir（形如 `comics/{comic_id}/{chapter_id}`）解析为绝对路径。

    `comics/` 前缀与 /static 服务路径保持一致，对应存储根下的目录。
    """
    relative = rel_dir[7:] if rel_dir.startswith("comics/") else rel_dir
    return str(Path(COMIC_STORAGE_ROOT) / relative)
