# Ronin

单仓库三端：Monarch（Go 后端）、Torrid（Flutter Android）、Northstar（后端托管的静态运维页）。
架构与数据权威关系见 `docs/architecture/README.md`；各端规则见 `backend/AGENTS.md`、`android/AGENTS.md`、`ops/AGENTS.md`。

- SQLite、媒体文件由后端与其托管的 gallery/comix CLI 共用；Android 的画廊是缓存，对话仅存本机，随笔/打卡通过整体同步与后端对齐。
- HTTPS `LOCAL_PORT`（7274，mDNS 广播）与 HTTP `LOCAL_HTTP_PORT`（7275）路由相同；`/ops/` 和 `/API/ops/local/*` 仅回环可访问。
- API/CLI 真源是 Go 代码。改路由或 CLI 参数后在 `backend/` 用 `pwsh -File references/scripts/generate_refs.ps1` 刷新快照；`-Check` 校验，生成物不入 git。客户端按快照定位处理函数核对 DTO。
- 生产数据不得用于写入试验；验收使用临时库或只读源库的副本，完成后清理。配置/密钥读取 `.env`，不得提交。
- 个人自用，优先可读性与简单实现；后端空闲应低负荷静默运行。命令使用 PowerShell 7（`pwsh`）。
- 结构或开发流程变化时才更新涉及的 agent 说明，只保留关键约束，不记录改动历史。
