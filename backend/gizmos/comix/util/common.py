import ipaddress
import os
import random
import re
import shutil
import socket
import sys
import threading
import time
from functools import cache
from pathlib import Path
from typing import Callable
from urllib.parse import urljoin, urlsplit

import requests
from fake_useragent import UserAgent
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from .image_size import ImageSizeError, get_image_info, get_image_size

MAX_IMAGE_BYTES = 64 * 1024 * 1024
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".jpe", ".jfif", ".png", ".webp", ".gif", ".bmp"}


def run_with_timeout(fn: Callable[[], object], timeout_sec: float) -> object:
    """在守护线程中执行 fn 并等待结果；超时抛 RuntimeError。

    用于防止 playwright 等第三方库在驱动/浏览器启动失败时挂死整个下载进程
    （实测 sync_playwright() 启动失败时进程可能永不退出）。超时后守护线程随
    进程退出回收；仅在异常环境触发，正常路径无额外开销。
    """
    box: dict = {}

    def _runner() -> None:
        try:
            box["value"] = fn()
        except BaseException as exc:  # noqa: BLE001 - 跨线程传递原始异常
            box["error"] = exc

    thread = threading.Thread(target=_runner, daemon=True)
    thread.start()
    thread.join(timeout_sec)
    if thread.is_alive():
        raise RuntimeError(f"操作超过 {timeout_sec:.0f}s 未完成(疑似卡死，已放弃等待)")
    if "error" in box:
        raise box["error"]  # type: ignore[misc]
    return box.get("value")


def random_sleep(base: float, jitter: float) -> None:
    """随机等待，降低短时间高频请求特征。"""
    time.sleep(base + jitter * random.random())


@cache
def _user_agent() -> UserAgent:
    return UserAgent()


def get_random_headers() -> dict:
    """生成随机请求头。"""
    return {
        "User-Agent": _user_agent().random,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Upgrade-Insecure-Requests": "1",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "same-origin",
    }


def require_public_url(url: str) -> None:
    parsed = urlsplit(url)
    host = parsed.hostname
    if (parsed.scheme not in ("http", "https") or not host or parsed.username is not None
            or parsed.port not in (None, 80, 443)):
        raise requests.exceptions.InvalidURL("只允许访问公开 HTTP(S) 地址")
    try:
        addresses = socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
    except OSError as exc:
        raise requests.exceptions.ConnectionError(f"域名解析失败: {host}") from exc
    for address in addresses:
        ip = ipaddress.ip_address(address[4][0])
        if not ip.is_global or ip.is_multicast:
            raise requests.exceptions.InvalidURL(f"拒绝访问非公开地址: {host}")


class PublicHTTPAdapter(HTTPAdapter):
    def send(self, request, **kwargs):
        require_public_url(request.url)
        return super().send(request, **kwargs)


def create_http_session(proxy: str | None) -> requests.Session:
    session = requests.Session()
    session.trust_env = False
    session.verify = os.getenv("REQUESTS_CA_BUNDLE") or os.getenv("CURL_CA_BUNDLE") or True
    session.max_redirects = 5
    if proxy:
        session.proxies = {"http": proxy, "https": proxy}
    retry = Retry(
        total=2,
        backoff_factor=0.8,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=("GET",),
        respect_retry_after_header=False,
    )
    adapter = PublicHTTPAdapter(max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session


def scan_images(save_dir: Path) -> list[dict]:
    """校验已落盘的章节，供中断后补写图片索引。"""
    entries: list[tuple[int, Path]] = []
    for path in save_dir.iterdir():
        if not path.is_file() or path.name.startswith(".") or path.name.lower() == "thumbs.db":
            continue
        if path.suffix.lower() not in IMAGE_EXTENSIONS or path.stat().st_size > MAX_IMAGE_BYTES:
            raise ImageSizeError(f"章节目录含无效图片: {path.name}")
        number = re.match(r"(\d+)", path.name)
        entries.append((int(number.group(1)) if number else 10**9, path))
    entries.sort(key=lambda item: (item[0], item[1].name))

    images: list[dict] = []
    last = 0
    for i, (number, path) in enumerate(entries, 1):
        number = max(last + 1, i if number == 10**9 else number)
        width, height = get_image_size(path)
        images.append({"sort_num": number, "file_name": path.name, "width": width, "height": height})
        last = number
    return images


def download_image_with_retry(
    session: requests.Session,
    image_url: str,
    page_path: Path,
    chapter_url: str,
    timeout: int,
    retries: int,
) -> tuple[str, int, int]:
    resolved_url = urljoin(chapter_url, image_url)
    partial = page_path.with_suffix(".part")
    headers = get_random_headers()
    headers.update({"Referer": chapter_url, "Accept": "image/webp,image/png,image/jpeg,image/gif,image/bmp"})
    last_error = None
    for attempt in range(retries):
        try:
            deadline = time.monotonic() + timeout
            with session.get(resolved_url, headers=headers, timeout=timeout, stream=True) as response:
                response.raise_for_status()
                with partial.open("wb") as file:
                    size = 0
                    for chunk in response.iter_content(64 * 1024):
                        size += len(chunk)
                        if size > MAX_IMAGE_BYTES:
                            raise RuntimeError("图片超过 64 MiB")
                        if time.monotonic() > deadline:
                            raise RuntimeError("图片下载超时")
                        file.write(chunk)
            ext, width, height = get_image_info(partial)
            target = page_path.with_suffix(ext)
            partial.replace(target)
            return target.name, width, height
        except Exception as exc:
            last_error = exc
            partial.unlink(missing_ok=True)
            if attempt + 1 < retries:
                random_sleep(0.8 * (attempt + 1), 0.5)
    raise RuntimeError(f"第 {int(page_path.name)} 页图片下载失败: {last_error}") from last_error


def finalize_chapter_dir(temp_dir: Path, final_dir: Path) -> None:
    for attempt in range(3):
        try:
            if final_dir.is_dir():
                final_dir.rmdir()
            temp_dir.replace(final_dir)
            return
        except PermissionError:
            if attempt == 2:
                raise
            time.sleep(0.5 * (attempt + 1))


def download_pages_atomic(
    save_dir: str,
    chapter_url: str,
    fetch_image_urls: Callable[[str], tuple[list[str], int]],
    session: requests.Session,
    img_timeout_sec: int,
    image_retry_times: int,
    strict_expected_total: bool,
) -> list[dict]:
    final_dir = Path(save_dir)
    if final_dir.is_dir() and (existing := scan_images(final_dir)):
        return existing

    temp_dir = final_dir.with_name(final_dir.name + ".downloading")
    if temp_dir.is_dir():
        shutil.rmtree(temp_dir)
    try:
        image_urls, expected = fetch_image_urls(chapter_url)
    except Exception as exc:
        raise RuntimeError(f"章节图片链接解析失败: {exc}") from exc
    if not image_urls:
        raise RuntimeError("章节未解析到图片链接")
    if len(image_urls) < expected:
        message = f"预期 {expected} 页，解析到 {len(image_urls)} 页"
        if strict_expected_total:
            raise RuntimeError(message)
        print(message, file=sys.stderr, flush=True)

    temp_dir.mkdir(parents=True)
    try:
        images = []
        pad = max(3, len(str(max(expected, len(image_urls)))))
        for i, image_url in enumerate(image_urls, 1):
            name, width, height = download_image_with_retry(
                session, image_url, temp_dir / f"{i:0{pad}d}", chapter_url,
                img_timeout_sec, image_retry_times,
            )
            images.append({"sort_num": i, "file_name": name, "width": width, "height": height})
            if i % 20 == 0:
                print(f"已下载 {i}/{len(image_urls)} 页", file=sys.stderr, flush=True)
            random_sleep(0.3, 0.4)
        finalize_chapter_dir(temp_dir, final_dir)
        return images
    finally:
        if temp_dir.is_dir():
            shutil.rmtree(temp_dir, ignore_errors=True)
