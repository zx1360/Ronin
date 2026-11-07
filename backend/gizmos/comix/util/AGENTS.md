# 通用工具

- `common.py`：HTTP 重试、原子下载、Windows 目录清理；`download_pages_atomic` 全部成功才提交 `.downloading`，失败清理临时目录。
- 进度和告警写 stderr，stdout 保持 CLI 结果 JSON。
- `image_size.py` 解析图片格式与宽高。下载拒绝无效图片，页码保持唯一有序。
