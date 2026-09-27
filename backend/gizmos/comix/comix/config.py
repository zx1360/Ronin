"""全局配置：从项目根 .env 加载存储/并发配置，并解析共享 SQLite 库路径。

数据库是 Ronin 后端的单文件 SQLite（与 Go 侧同一个 monarch.db），
路径解析与 `backend/gizmos/internal/service/config/config.go` 保持同一策略。
"""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# 项目根目录（comix 包的上一级，即 backend/gizmos/comix）
PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

# ---------------------------------------------------------------------------
# 共享 SQLite 库路径
# ---------------------------------------------------------------------------

# 探测顺序与 Go 侧一致：先 backend/ 下（开发时在 backend/ 运行），
# 再 ../../data（CLI 由 Go 服务以 cwd=backend/gizmos/comix 拉起）。
DB_PATH_CANDIDATES = (
    "data/monarch.db",
    "../../data/monarch.db",
    "../data/monarch.db",
)


def resolve_db_path() -> str:
    """解析 SQLite 库路径。

    `DB_PATH` 环境变量优先（相对路径按当前工作目录解析，与 Go 侧一致）；
    否则按候选顺序取第一个已存在的库；都不存在时按 comix CLI 的实际
    工作目录回退到 `../../data/monarch.db`（即 backend/data/monarch.db）。
    """
    configured = os.getenv("DB_PATH", "").strip()
    if configured:
        return configured
    for candidate in DB_PATH_CANDIDATES:
        if Path(candidate).is_file():
            return candidate
    # PROJECT_ROOT = <backend>/gizmos/comix：在 Ronin 仓库内时按后端数据目录回退
    if PROJECT_ROOT.parent.name == "gizmos":
        return "../../data/monarch.db"
    return "data/monarch.db"


def db_file() -> Path:
    """数据库文件的 Path（相对路径按当前工作目录解析）。"""
    return Path(DB_PATH)


DB_PATH = resolve_db_path()


# ---------------------------------------------------------------------------
# 存储与稳定性配置
# ---------------------------------------------------------------------------

def _resolve_storage_root() -> str:
    """漫画存储根目录：.env 为绝对路径（如 Ronin 的 backend/static/comics）。"""
    raw = os.getenv("COMIC_STORAGE_ROOT", "./comics").strip() or "./comics"
    path = Path(raw)
    return str(path if path.is_absolute() else PROJECT_ROOT / path)


COMIC_STORAGE_ROOT = _resolve_storage_root()

# 下载并发与稳定性配置
COMIX_MAX_WORKERS = int(os.getenv("COMIX_MAX_WORKERS", "2"))
IMG_TIMEOUT_SEC = int(os.getenv("IMG_TIMEOUT_SEC", "20"))
IMAGE_RETRY_TIMES = int(os.getenv("IMAGE_RETRY_TIMES", "4"))
PAGE_TIMEOUT_SEC = int(os.getenv("PAGE_TIMEOUT_SEC", "20"))
CHAPTER_RETRY_TIMES = int(os.getenv("CHAPTER_RETRY_TIMES", "2"))


def storage_path(rel_dir: str) -> Path:
    """把 DB 中的 rel_dir 解析为磁盘绝对路径。

    rel_dir 形如 `comics/{comic_id}/{chapter_id}`，其 `comics/` 前缀对应
    存储根目录本身（与 Go 侧 `comix.StoragePath`、/static 暴露路径一致）。
    """
    relative = rel_dir[7:] if rel_dir.startswith("comics/") else rel_dir
    return Path(COMIC_STORAGE_ROOT) / relative


def ensure_storage_root() -> Path:
    """确保存储根目录存在，返回其 Path。"""
    root = Path(COMIC_STORAGE_ROOT)
    root.mkdir(parents=True, exist_ok=True)
    return root
