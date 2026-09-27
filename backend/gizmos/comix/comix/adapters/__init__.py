"""站点适配器注册表。"""
from __future__ import annotations

from typing import Optional

from .base import BaseAdapter
from .manhuayu import ManhuayuAdapter
from .morui import MoruiAdapter
from .nicemh import NicemhAdapter
from .xmanhua import XmanhuaAdapter

# 注册顺序即 CLI/调度器尝试站点的顺序
_ADAPTER_CLASSES = [
    ManhuayuAdapter,
    MoruiAdapter,
    NicemhAdapter,
    XmanhuaAdapter,
]

ADAPTERS: dict[str, BaseAdapter] = {cls.code: cls() for cls in _ADAPTER_CLASSES}


def get_adapter(code: str) -> Optional[BaseAdapter]:
    """按站点代码取适配器实例。"""
    return ADAPTERS.get(code)


def all_adapters() -> list[BaseAdapter]:
    """返回全部适配器（按注册顺序）。"""
    return [ADAPTERS[cls.code] for cls in _ADAPTER_CLASSES]
