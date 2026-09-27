"""时间列格式：与 Go 侧 `model.TimeFormat` 完全一致（UTC / 毫秒 / 定宽）。

数据库时间列一律 TEXT，格式 `2006-01-02T15:04:05.000Z`：
定宽且按字典序即时序，Go 与本模块都直接读写它，不做时区/本地化转换。
禁止在别处散落格式字符串——所有时间写入都走 `now_text()`。
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

# 与 Go 侧 `model.TimeFormat` 一致（毫秒三位）
TIME_FORMAT = "%Y-%m-%dT%H:%M:%S.000Z"

# 历史/兼容输入格式（与 Go 侧 `model.ParseTime` 的布局列表对齐）
_PARSE_FORMATS = (
    "%Y-%m-%dT%H:%M:%S.%fZ",
    "%Y-%m-%dT%H:%M:%SZ",
    "%Y-%m-%dT%H:%M:%S.%f%z",
    "%Y-%m-%dT%H:%M:%S%z",
    "%Y-%m-%dT%H:%M:%S",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d",
)


def format_time(value: datetime) -> str:
    """把 datetime 归一化为存储格式（UTC、毫秒、定宽）。

    与 Go 的 `model.FormatTime` 等价；naive datetime 按 UTC 处理。
    """
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    value = value.astimezone(timezone.utc)
    # 显式拼毫秒：strftime 的 %f 是微秒，直接截断到三位（与 Go 的 .000 一致）
    return value.strftime("%Y-%m-%dT%H:%M:%S.") + f"{value.microsecond // 1000:03d}Z"


def now_text() -> str:
    """当前时间的存储格式。"""
    return format_time(datetime.now(timezone.utc))


def parse_text(text: Optional[str]) -> Optional[datetime]:
    """解析存储格式时间；解析失败返回 None（空串同样返回 None）。

    兼容 Go 侧 `model.ParseTime` 接受的历史变体（RFC3339 带/不带毫秒、
    `YYYY-MM-DD HH:MM:SS`、纯日期），解析结果统一为 UTC。
    """
    if not text:
        return None
    raw = text.strip()
    if not raw:
        return None
    for layout in _PARSE_FORMATS:
        try:
            parsed = datetime.strptime(raw, layout)
        except ValueError:
            continue
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    return None
