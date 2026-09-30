import os
import random
import re
import shutil
import threading
import time
import warnings
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Callable, Iterable, List, Tuple
from urllib.parse import urljoin, urlparse

import requests
from fake_useragent import UserAgent
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

FAILED_RECORD_FILE = ".failed_chapters.txt"

# 安静模式：为 True 时抑制下载进度打印（--json 输出时由 CLI 开启）
QUIET = False


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


@dataclass(frozen=True)
class ChapterTask:
    """章节任务模型。"""

    index: int
    title: str
    url: str


def scan_images(save_dir: str) -> list[dict]:
    """扫描章节目录下的图片文件，返回图片记录列表。

    每条: {"sort_num", "file_name", "width", "height"}
    - sort_num 取文件名前导数字（005.webp → 5），与旧系统 comic_images.sort_num 语义一致；
      文件名非数字开头时按排序位置递补。
    - 宽高用纯 Python 解析文件头（JPEG/PNG/WebP/GIF/BMP），解析失败记 0。
    """
    from .image_size import ImageSizeError, get_image_size

    entries: list[tuple[int, str, str]] = []
    for name in os.listdir(save_dir):
        full = os.path.join(save_dir, name)
        if not os.path.isfile(full):
            continue
        m = re.match(r"(\d+)", name)
        sort_num = int(m.group(1)) if m else 10**9
        entries.append((sort_num, name, full))
    entries.sort(key=lambda e: e[0])

    results: list[dict] = []
    last = 0
    for i, (sort_num, name, full) in enumerate(entries, start=1):
        if sort_num == 10**9:
            sort_num = i
        if sort_num <= last:  # 重复/倒序序号递补，保证 sort_num 唯一且有序
            sort_num = last + 1
        last = sort_num
        try:
            w, h = get_image_size(full)
        except ImageSizeError:
            w, h = 0, 0
        results.append({"sort_num": sort_num, "file_name": name, "width": w, "height": h})
    return results


def init_requests_warnings() -> None:
    """关闭 requests 相关告警。"""
    warnings.filterwarnings("ignore")
    requests.packages.urllib3.disable_warnings()


def to_valid_windows_dirname(dirname: str) -> str:
    """清洗目录名中的非法字符。"""
    valid = re.sub(r"[\\/:*?\"<>|]", "_", dirname)
    return valid.strip()


def random_sleep(base: float, jitter: float) -> None:
    """随机等待，降低短时间高频请求特征。"""
    time.sleep(base + jitter * random.random())


def get_random_headers() -> dict:
    """生成随机请求头。"""
    ua = UserAgent()
    return {
        "User-Agent": ua.random,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Upgrade-Insecure-Requests": "1",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "same-origin",
    }


def create_http_session(
    retry_total: int = 3,
    backoff_factor: float = 0.8,
    status_forcelist: Iterable[int] = (429, 500, 502, 503, 504),
    allowed_methods: Iterable[str] = ("GET",),
    pool_connections: int = 20,
    pool_maxsize: int = 20,
) -> requests.Session:
    """创建带重试策略的会话。"""
    session = requests.Session()
    retry = Retry(
        total=retry_total,
        connect=retry_total,
        read=retry_total,
        backoff_factor=backoff_factor,
        status_forcelist=list(status_forcelist),
        allowed_methods=list(allowed_methods),
    )
    adapter = HTTPAdapter(max_retries=retry, pool_connections=pool_connections, pool_maxsize=pool_maxsize)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session


def ensure_dir(path: str) -> None:
    """确保目录存在。"""
    os.makedirs(path, exist_ok=True)


def chapter_dir_name(task: ChapterTask) -> str:
    """生成章节目录名。"""
    return f"{task.index}_{to_valid_windows_dirname(task.title)}"


def chapter_dir_has_images(chapter_dir: str) -> bool:
    """判断章节目录是否已有效下载。"""
    if not os.path.isdir(chapter_dir):
        return False
    for name in os.listdir(chapter_dir):
        full = os.path.join(chapter_dir, name)
        if os.path.isfile(full):
            return True
    return False


def detect_existing_chapters(comic_dir: str) -> set:
    """识别已存在且非空的章节索引。"""
    exists = set()
    for folder in os.listdir(comic_dir):
        folder_path = os.path.join(comic_dir, folder)
        if not os.path.isdir(folder_path):
            continue
        match = re.match(r"^(\d+)_", folder)
        if not match:
            continue
        if chapter_dir_has_images(folder_path):
            exists.add(int(match.group(1)))
    return exists


def normalize_image_url(image_url: str, chapter_url: str, base_url: str | None = None) -> str:
    """补全相对链接为绝对链接。"""
    if not image_url:
        return image_url
    if image_url.startswith("//"):
        if base_url:
            parsed = urlparse(base_url)
            scheme = parsed.scheme or "https"
            return f"{scheme}:{image_url}"
        return f"https:{image_url}"
    parsed = urlparse(image_url)
    if parsed.scheme:
        return image_url
    base = chapter_url or base_url or ""
    return urljoin(base, image_url)


def download_image_with_retry(
    session: requests.Session,
    image_url: str,
    save_path: str,
    chapter_url: str,
    img_timeout_sec: int,
    image_retry_times: int,
    base_url: str | None = None,
) -> None:
    """下载单张图片并在失败时重试。"""
    last_error = None
    resolved_url = normalize_image_url(image_url, chapter_url, base_url)

    for attempt in range(1, image_retry_times + 1):
        try:
            resp = session.get(
                resolved_url,
                headers={**get_random_headers(), "Referer": chapter_url},
                timeout=img_timeout_sec,
                verify=False,
            )
            resp.raise_for_status()
            if not resp.content:
                raise RuntimeError("空响应体")

            with open(save_path, "wb") as f:
                f.write(resp.content)
            return
        except Exception as exc:
            last_error = exc
            if os.path.exists(save_path):
                os.remove(save_path)
            random_sleep(0.8 * attempt, 0.5)

    raise RuntimeError(f"图片下载失败: {resolved_url}, 错误: {last_error}")


def write_failed_record(comic_dir: str, failed_indexes: List[int]) -> None:
    """写入失败章节记录。"""
    record_path = os.path.join(comic_dir, FAILED_RECORD_FILE)
    if not failed_indexes:
        if os.path.exists(record_path):
            os.remove(record_path)
        return

    with open(record_path, "w", encoding="utf-8") as f:
        for idx in sorted(failed_indexes):
            f.write(f"{idx}\n")


def _handle_remove_readonly(func, path, _exc_info) -> None:
    try:
        os.chmod(path, 0o666)
        func(path)
    except Exception:
        return


def remove_dir_safely(path: str, retry_times: int = 3) -> None:
    """删除目录并处理 Windows 下的占用与只读问题。"""
    if not os.path.isdir(path):
        return

    last_error = None
    for attempt in range(1, retry_times + 1):
        try:
            shutil.rmtree(path, onerror=_handle_remove_readonly)
            if not os.path.exists(path):
                return
        except Exception as exc:
            last_error = exc
        time.sleep(0.4 * attempt)

    if last_error:
        raise last_error


def finalize_chapter_dir(temp_dir: str, final_dir: str, retry_times: int = 3) -> None:
    """提交章节目录，处理 Windows 临时占用导致的失败。"""
    last_error = None
    for attempt in range(1, retry_times + 1):
        try:
            remove_dir_safely(final_dir, retry_times=retry_times)
            os.replace(temp_dir, final_dir)
            return
        except PermissionError as exc:
            last_error = exc
            if attempt == retry_times:
                raise
            time.sleep(0.5 * attempt)

    if last_error:
        raise last_error


def download_chapter_atomic(
    task: ChapterTask,
    comic_dir: str,
    fetch_image_urls: Callable[[str], Tuple[List[str], int]],
    img_timeout_sec: int,
    image_retry_times: int,
    strict_expected_total: bool = True,
    base_url: str | None = None,
) -> Tuple[bool, bool, str]:
    """原子化下载单章节，确保全成或全败。"""
    chapter_name = chapter_dir_name(task)
    final_dir = os.path.join(comic_dir, chapter_name)
    temp_dir = f"{final_dir}.downloading"

    if chapter_dir_has_images(final_dir):
        return True, True, "已存在，跳过"

    if os.path.isdir(temp_dir):
        shutil.rmtree(temp_dir, ignore_errors=True)
    ensure_dir(temp_dir)

    try:
        img_urls, expected_total = fetch_image_urls(task.url)
        if expected_total > 0 and len(img_urls) < expected_total:
            message = (
                f"警告: 章节{task.index} '{task.title}' 预期图片{expected_total}张，"
                f"但实际提取到{len(img_urls)}张"
            )
            if strict_expected_total:
                raise RuntimeError(message)
            print(f"{message}，继续下载...")

        session = create_http_session()
        total_for_pad = expected_total if expected_total > 0 else len(img_urls)
        pad_width = max(1, len(str(total_for_pad)))
        for i, img_url in enumerate(img_urls, start=1):
            resolved_url = normalize_image_url(img_url, task.url, base_url)
            ext = os.path.splitext(urlparse(resolved_url).path)[1].lower() or ".jpg"
            if len(ext) > 6:
                ext = ".jpg"
            save_path = os.path.join(temp_dir, f"{i:0{pad_width}d}{ext}")
            download_image_with_retry(
                session,
                resolved_url,
                save_path,
                task.url,
                img_timeout_sec,
                image_retry_times,
                base_url,
            )
            if i % 20 == 0:
                print(f"章节{task.index} '{task.title}', 图片{i}__Done!")
            random_sleep(0.3, 0.4)

        finalize_chapter_dir(temp_dir, final_dir)
        return True, False, f"成功({len(img_urls)}张)"
    except Exception as exc:
        shutil.rmtree(temp_dir, ignore_errors=True)
        return False, False, str(exc)


def download_pages_atomic(
    save_dir: str,
    chapter_url: str,
    fetch_image_urls: Callable[[str], Tuple[List[str], int]],
    img_timeout_sec: int,
    image_retry_times: int,
    strict_expected_total: bool = True,
    base_url: str | None = None,
) -> Tuple[bool, int, str]:
    """按新存储规范原子化下载单章：save_dir/001.jpg、002.jpg ...

    全部图片下载成功才保留目录（失败时清理），返回 (ok, page_count, error)。
    页码固定三位补齐（超过 999 张时自然扩展为四位）。
    """
    temp_dir = f"{save_dir}.downloading"
    # 幂等：目录已存在且含图片则视为已下载（原子提交保证目录完整性）
    if os.path.isdir(save_dir):
        existing = [
            f for f in os.listdir(save_dir)
            if os.path.isfile(os.path.join(save_dir, f))
        ]
        if existing:
            return True, len(existing), "已存在，跳过"
    if os.path.isdir(temp_dir):
        shutil.rmtree(temp_dir, ignore_errors=True)
    ensure_dir(temp_dir)

    try:
        img_urls, expected_total = fetch_image_urls(chapter_url)
        if expected_total > 0 and len(img_urls) < expected_total:
            message = (
                f"预期图片{expected_total}张，实际提取到{len(img_urls)}张"
            )
            if strict_expected_total:
                raise RuntimeError(message)
            if not QUIET:
                print(f"警告: {message}，继续下载...")

        session = create_http_session()
        total_for_pad = expected_total if expected_total > 0 else len(img_urls)
        pad_width = max(3, len(str(total_for_pad)))
        for i, img_url in enumerate(img_urls, start=1):
            resolved_url = normalize_image_url(img_url, chapter_url, base_url)
            ext = os.path.splitext(urlparse(resolved_url).path)[1].lower() or ".jpg"
            if len(ext) > 6:
                ext = ".jpg"
            save_path = os.path.join(temp_dir, f"{i:0{pad_width}d}{ext}")
            download_image_with_retry(
                session,
                resolved_url,
                save_path,
                chapter_url,
                img_timeout_sec,
                image_retry_times,
                base_url,
            )
            if i % 20 == 0:
                if not QUIET:
                    print(f"图片 {i}__Done!")
            random_sleep(0.3, 0.4)

        finalize_chapter_dir(temp_dir, save_dir)
        return True, len(img_urls), ""
    except Exception as exc:
        shutil.rmtree(temp_dir, ignore_errors=True)
        return False, 0, str(exc)


def run_download_round(
    chapters: List[ChapterTask],
    comic_dir: str,
    download_func: Callable[[ChapterTask, str], Tuple[bool, bool, str]],
    max_workers: int,
) -> Tuple[List[int], int]:
    """并发执行一轮章节下载，返回失败章节与跳过数量。"""
    failed_indexes: List[int] = []
    skipped = 0

    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        future_map = {pool.submit(download_func, ch, comic_dir): ch for ch in chapters}

        for future in as_completed(future_map):
            chapter = future_map[future]
            success, is_skipped, msg = future.result()
            if is_skipped:
                skipped += 1
                print(f"章节{chapter.index} '{chapter.title}' 跳过: {msg}")
                continue

            if success:
                print(f"####章节{chapter.index} '{chapter.title}' 下载成功: {msg}")
            else:
                failed_indexes.append(chapter.index)
                print(f"章节{chapter.index} '{chapter.title}' 下载失败: {msg}")

    return failed_indexes, skipped


def build_chapter_index_map(chapters: List[ChapterTask]) -> dict:
    """构建章节索引映射。"""
    return {chapter.index: chapter for chapter in chapters}
