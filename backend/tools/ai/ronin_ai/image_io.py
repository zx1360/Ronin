"""图片读取。

统一走 numpy + cv2.imdecode，而不是 cv2.imread：
Windows 上 cv2.imread 使用 ANSI 接口打开文件，遇到中文/表情等非 ASCII 路径会
直接返回 None。媒体库里的文件名大量包含中文，因此所有读图都走这里。
"""

from __future__ import annotations

from typing import Any

import numpy as np


def load_bgr(path: str) -> Any:
    """读取图片为 BGR ndarray；失败返回 None。"""
    import cv2

    buffer = np.fromfile(path, dtype=np.uint8)
    if buffer.size == 0:
        return None
    return cv2.imdecode(buffer, cv2.IMREAD_COLOR)
