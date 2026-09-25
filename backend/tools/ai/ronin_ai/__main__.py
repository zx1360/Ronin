"""侧车入口：`python -m ronin_ai`（常驻协议模式）或 `--probe`（依赖探测）。"""

from __future__ import annotations

import sys

from .protocol import main

if __name__ == "__main__":
    sys.exit(main())
