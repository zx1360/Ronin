# Ronin 架构

| 端 | 职责与数据权威 |
| --- | --- |
| Monarch（`backend/`） | Go 后端。与 Gallery CLI、comix CLI 共用 SQLite 和媒体文件。在线画廊和漫画库以服务端为准。 |
| Torrid（`android/`） | Android 客户端。Drift + SQLite 保存本机数据。时迹由手机合并，Monarch 保存带修订号的备份。画廊工作副本绑定图库 ID。对话和随笔草稿留在本机。 |
| Northstar（`ops/web/`） | Vue + Vite，本机运维和编辑界面。Monarch 托管 `/ops/`，业务写入经 API，浏览器独立保存随笔草稿。 |

随笔与积微允许 Torrid 和 Northstar 分别编辑，双方通过 Monarch 按[跨端契约](../../backend/data/contracts/README.md)同步。Monarch 的局域网 HTTPS（mDNS 发现）和回环 HTTP 共用路由，`/ops/` 与 `/API/ops/local/*` 限回环访问。

Go 路由和 CLI 源码是接口真源。改路由或 Monarch/Gallery 参数时，可在 `backend/` 运行 `pwsh -File references/scripts/generate_refs.ps1` 刷新快照，核对已有快照时用 `-Check`。生成物不入库。

自用场景优先简单实现和复用。后端空闲须低负荷静默，新增常驻组件须先获同意。配置和密钥从 `backend/.env` 读取，避免输出或提交。
