# AGENTS.md —— 运维脚本（scripts/）

独立脚本，均可直接 `python scripts/xxx.py` 运行；批量操作遵循
"每单元一个事务 + 失败回退 + 幂等可重跑"。

## 脚本清单

| 脚本 | 职责 | 关键参数 |
|---|---|---|
| `check_updates.py` | 全量更新检查（计划任务追更） | `--download` 自动追更 / `--latest N` / `--json` |
| `import_legacy.py` | 导入旧资源（存储根下的名称目录） | `--dry-run` / `--execute` / `--limit N` / `--json` |

## 关键约定与陷阱（踩过的坑）

1. **写入必须走 `db.transaction()`**（`BEGIN IMMEDIATE` → 提交/回滚）。
   `db.connect()` 是只读连接；裸 `conn.execute` 写多条语句会各自自动提交、
   失去原子性，失败时无法整体回退。
2. **文件移动需处理只读/占用**：用 `util.common.remove_dir_safely`（带重试与
   只读处理）；跨目录移动优先 `shutil.move`（同盘 rename），失败需回退。
3. **导入幂等**：`import_legacy.py` 以 `site_comic_id=目录名` 唯一、章节以
   `(comic_id, chapter_no)` 唯一、图片以 `(chapter_id, sort_num)` 唯一实现
   幂等；中断后重跑自动补导入"已移动未登记"的目录（Phase 1 恢复）。
4. **回退保护**：`import_legacy` 每本一个事务，失败回滚 DB + 目录回移。
5. **UTF-8 输出**：所有脚本入口 `stream.reconfigure(encoding="utf-8")`
   （Windows 控制台 GBK 遇特殊字符如 `～` 会崩）。
6. **存储路径**：一律用 `comix.config.storage_path(rel_dir)` 解析，
   不要自己拼 `PROJECT_ROOT`——存储根由 backend/.env 指定。

## 环境准备顺序（全新环境）

```powershell
pip install -r requirements.txt
python -m playwright install chromium        # 漫画鱼/奈斯需要
python -m comix.cli init                      # 建表（读 backend/references/db/sqlite.sql）+ 注册站点
python scripts/import_legacy.py --execute     # 导入旧资源（如有）
```
