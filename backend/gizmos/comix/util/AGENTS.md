# 通用工具

- `common.py`：HTTP 重试、原子下载、Windows 目录清理；`download_pages_atomic` 全部成功才提交 `.downloading`，失败清理临时目录。
- `--json` 由 CLI 开启 `QUIET`，进度仅写 stderr 或受 QUIET 控制，stdout 必须保持单行 JSON。
- `image_size.py` 纯 Python 解析宽高，不引入 Pillow；解析失败由 `scan_images` 记 0。扫描页码须保持唯一且有序，与 `comic_images.sort_num` 对应。
