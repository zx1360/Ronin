"""纯 Python 图片宽高解析（无 Pillow 依赖）。

支持 JPEG / PNG / WebP / GIF / BMP，解析文件头获取尺寸。
用于下载后回填 comic_images 表与旧资源导入。
"""
from __future__ import annotations

import struct
from pathlib import Path


class ImageSizeError(Exception):
    pass


def get_image_size(path: str | Path) -> tuple[int, int]:
    _, width, height = get_image_info(path)
    return width, height


def get_image_info(path: str | Path) -> tuple[str, int, int]:
    p = Path(path)
    with open(p, "rb") as f:
        head = f.read(64)

    if head[:8] == b"\x89PNG\r\n\x1a\n":
        if head[12:16] != b"IHDR" or len(head) < 24:
            raise ImageSizeError(f"PNG 头不完整: {p.name}")
        ext = ".png"
        w, h = struct.unpack(">II", head[16:24])
    elif len(head) >= 10 and head[:6] in (b"GIF87a", b"GIF89a"):
        ext = ".gif"
        w, h = struct.unpack("<HH", head[6:10])
    elif len(head) >= 26 and head[:2] == b"BM":
        ext = ".bmp"
        w, h = struct.unpack("<ii", head[18:26])
        h = abs(h)
    elif head[:2] == b"\xff\xd8":
        ext = ".jpg"
        w, h = _jpeg_size(p)
    elif head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        ext = ".webp"
        w, h = _webp_size(p)
    else:
        raise ImageSizeError(f"不支持的图片格式: {p.name}")
    if w <= 0 or h <= 0:
        raise ImageSizeError(f"无效图片尺寸: {p.name}")
    return ext, w, h


def _jpeg_size(p: Path) -> tuple[int, int]:
    with open(p, "rb") as f:
        f.seek(2)
        while f.read(1) == b"\xff":
            marker = f.read(1)
            while marker == b"\xff":
                marker = f.read(1)
            if not marker or marker in (b"\xd9", b"\xda"):
                break
            code = marker[0]
            length = int.from_bytes(f.read(2), "big")
            if length < 2:
                break
            if 0xC0 <= code <= 0xCF and code not in (0xC4, 0xC8, 0xCC):
                data = f.read(5)
                if len(data) == 5 and length >= 7:
                    h, w = struct.unpack(">HH", data[1:])
                    return w, h
                break
            f.seek(length - 2, 1)
    raise ImageSizeError(f"JPEG SOF 未找到: {p.name}")


def _webp_size(p: Path) -> tuple[int, int]:
    with open(p, "rb") as f:
        f.seek(12)
        while len(header := f.read(8)) == 8:
            fourcc = header[:4]
            size = int.from_bytes(header[4:], "little")
            next_chunk = f.tell() + size + (size & 1)
            chunk = f.read(min(size, 10))
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
            f.seek(next_chunk)
        raise ImageSizeError(f"WebP 块未识别: {p.name}")
