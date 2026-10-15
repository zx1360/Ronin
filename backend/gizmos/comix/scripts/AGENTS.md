# 运维脚本

`check_updates.py` 用于计划任务追更，参数 `--download` / `--latest N` / `--json`。
复用 scheduler，不在脚本中重复实现下载/数据库逻辑；配置与路径沿用 comix.config，输出强制 UTF-8。
