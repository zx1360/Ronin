# Ronin

- Monarch（`backend/`）的 SQLite 和媒体文件由后端、Gallery CLI、comix CLI 共用。Northstar（`ops/web/`）通过 Monarch API 写数据，由 Monarch 托管在 `/ops/`。
- Torrid（`android/`）用 Drift + SQLite 保存本机数据。随笔和积微允许手机与后端分别编辑，按记录版本和删除标记合并。时迹由手机合并，Monarch 保存带修订号的备份。图库工作副本绑定图库 ID。随笔草稿和对话存于创建它们的客户端。
- Monarch 提供同路由的局域网 HTTPS（mDNS 发现）和回环 HTTP。`/ops/` 与 `/API/ops/local/*` 仅允许回环访问。
- 行为以源码为准。改路由或 CLI 参数后在 `backend/` 运行 `pwsh -File references/scripts/generate_refs.ps1`，用 `-Check` 校验。生成物不入库。跨端契约样例在 `backend/data/contracts/`。
- 根目录运行 `pwsh -File verify.ps1 -Scope backend|android|ops|contracts|all`，按需选择一项。浏览器冒烟用 `-OpsBase` 指向隔离实例。验收写入使用临时库，完成后清理。配置和密钥读取 `.env`，避免输出或提交。
- 个人自用，优先复用现有实现。后端空闲须低负荷静默，新增常驻组件须先获同意。命令用 PowerShell 7。
