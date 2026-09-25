"""推理线程数策略。

侧车在用户自己的 PC 上长时间跑批处理，必须给日常使用留出余量：
统一只用一半核心（上限 8），而不是 ONNX Runtime 默认的"吃满所有核心"。
"""

from __future__ import annotations

import os

MAX_THREADS = 8


def intra_op_threads() -> int:
    """返回单次推理应使用的线程数。"""
    cores = os.cpu_count() or 4
    return max(1, min(MAX_THREADS, cores // 2))
