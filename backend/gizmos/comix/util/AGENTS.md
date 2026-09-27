# AGENTS.md —— 通用工具（util/）

跨模块复用的基础工具。**禁引 Pillow**（宽高解析用纯 Python 实现，零依赖）。

## 模块

| 文件 | 内容 | 关键函数 |
|---|---|---|
| `common.py` | HTTP 会话/随机头/原子下载/目录清理 | 见下 |
| `image_size.py` | 图片宽高解析（JPEG/PNG/WebP/GIF/BMP） | `get_image_size(path) -> (w, h)`，失败抛 `ImageSizeError` |

## common.py 关键函数

- `create_http_session()`：带重试（429/5xx + backoff）的 requests 会话
- `get_random_headers()`：fake-useragent 随机头
- `random_sleep(base, jitter)`：随机休眠降频
- `to_valid_windows_dirname(s)`：清洗非法文件名字符
- `download_pages_atomic(save_dir, chapter_url, fetch_image_urls, ...)`：
  **按新存储规范**原子下载整章（`save_dir/001.jpg`…，页码 3 位补齐），
  开头幂等检查（目录已有图直接返回），失败清理临时目录
- `scan_images(save_dir) -> list[dict]`：扫描目录图片记录
  （`sort_num`=文件名前导数字，重复递补；`width/height` 解析，失败记 0）
- `remove_dir_safely(path)`：删除目录（重试 + 只读处理，Windows 兼容）
- `finalize_chapter_dir(temp, final)`：临时目录 → 最终目录（原子提交，处理占用）

## 约定

- **QUIET 全局开关**：`--json` 模式下由 CLI 置 `True`，抑制下载进度打印
  （保证 stdout 只有 JSON）。新增打印代码必须遵守：进度 → stderr 或受 QUIET 控制。
- `download_pages_atomic` / `download_chapter_atomic`（旧版，保留兼容）：
  新代码一律用 `download_pages_atomic`（save_dir 直接是最终目录）。
- `scan_images` 是 `comix_image` 回填与旧资源导入共用的扫描逻辑，
  修改 sort_num/宽高规则会同时影响两条链路，需同步验证。
- `image_size.py` 解析失败返回/抛出约定：`scan_images` 捕获后记 0，不中断导入。
- 本层不做路径解析：存储根与 `rel_dir` 的换算统一用 `comix.config.storage_path()`
  （`util` 不 import `comix`，避免循环依赖）。
