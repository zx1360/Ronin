"""纯 Python 图片宽高解析（无 Pillow 依赖）。

支持 JPEG / PNG / WebP / GIF / BMP，解析文件头获取尺寸。
用于下载后回填 comix_image 表与旧资源导入。
"""
from __future__ import annotations

import struct
from pathlib import Path


class ImageSizeError(Exception):
    pass


def get_image_size(path: str | Path) -> tuple[int, int]:
    """返回 (width, height)。无法识别时抛 ImageSizeError。"""
    p = Path(path)
    with open(p, "rb") as f:
        head = f.read(64)
    if not head:
        raise ImageSizeError(f"空文件: {p.name}")

    # ---- PNG ----
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        if head[12:16] != b"IHDR" or len(head) < 24:
            raise ImageSizeError(f"PNG 头不完整: {p.name}")
        w, h = struct.unpack(">II", head[16:24])
        return w, h

    # ---- GIF ----
    if head[:6] in (b"GIF87a", b"GIF89a"):
        w, h = struct.unpack("<HH", head[6:10])
        return w, h

    # ---- BMP ----
    if head[:2] == b"BM":
        w, h = struct.unpack("<ii", head[18:26])
        return w, abs(h)

    # ---- JPEG ----
    if head[:2] == b"\xff\xd8":
        return _jpeg_size(p, head)

    # ---- WebP ----
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return _webp_size(p, head)

    raise ImageSizeError(f"不支持的图片格式: {p.name} (头: {head[:8].hex()})")


def _jpeg_size(p: Path, head: bytes) -> tuple[int, int]:
    with open(p, "rb") as f:
        data = head
        pos = 2  # 跳过 SOI
        while pos < len(data) or pos < 0xFFFF:
            if pos + 4 > len(data):
                chunk = f.read(0x4000)
                if not chunk:
                    break
                data += chunk
                if pos + 4 > len(data):
                    break
            marker = data[pos]
            if marker != 0xFF:  # 填充字节
                pos += 1
                continue
            code = data[pos + 1]
            if code in (0xD8, 0xD9) or 0xD0 <= code <= 0xD7:  # SOI/EOI/RST
                pos += 2
                continue
            length = struct.unpack(">H", data[pos + 2:pos + 4])[0]
            # SOF0-SOF15（排除 DHT(C4)/DAC(CC)/DQT(DB)/COM(FE)/APP 等）
            if 0xC0 <= code <= 0xCF and code not in (0xC4, 0xC8, 0xCC):
                if pos + 9 > len(data):
                    chunk = f.read(0x4000)
                    if not chunk:
                        break
                    data += chunk
                h, w = struct.unpack(">HH", data[pos + 5:pos + 9])
                return w, h
            pos += 2 + length
    raise ImageSizeError(f"JPEG SOF 未找到: {p.name}")


def _webp_size(p: Path, head: bytes) -> tuple[int, int]:
    with open(p, "rb") as f:
        data = head
        pos = 12  # RIFF 头后
        while pos + 8 <= len(data):
            fourcc = data[pos:pos + 4]
            size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
            chunk = data[pos + 8:pos + 8 + size]
            if len(chunk) < size:  # 头 64 字节可能不够，读补齐
                f.seek(pos + 8)
                chunk = f.read(size)
            if fourcc == b"VP8 " and len(chunk) >= 10:
                w = struct.unpack("<H", chunk[6:8])[0] & 0x3FFF
                h = struct.unpack("<H", chunk[8:10])[0] & 0x3FFF
                return w, h
            if fourcc == b"VP8L" and len(chunk) >= 5:
                bits = chunk[1:5]
                b0, b1, b2, b3 = bits[0], bits[1], bits[2], bits[3]
                w = 1 + (((b1 & 0x3F) << 8) | b0)
                h = 1 + (((b3 & 0x0F) << 10) | (b2 << 2) | ((b1 & 0xC0) >> 6))
                return w, h
            if fourcc == b"VP8X" and len(chunk) >= 10:
                b4, b5, b6 = chunk[4], chunk[5], chunk[6]
                b7, b8, b9 = chunk[7], chunk[8], chunk[9]
                w = 1 + (b4 | (b5 << 8) | (b6 << 16))
                h = 1 + (b7 | (b8 << 8) | (b9 << 16))
                return w, h
            pos += 8 + size + (size & 1)  # 分块 2 字节对齐
        raise ImageSizeError(f"WebP 块未识别: {p.name}")
