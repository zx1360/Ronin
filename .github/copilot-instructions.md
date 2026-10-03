单仓库多目标工作区. Go 后端(Monarch) + Flutter 安卓端(Torrid) + 网页运维端(Northstar, 由 Monarch 内置 HTTP 服务托管).

- backend: backend/AGENTS.md
- android: android/AGENTS.md
- ops: ops/AGENTS.md

后端信息按需查阅:
- 契约快照: backend/references/generated/（生成物，不入 git；真源是 Go 代码）
- 数据库: backend/AGENTS_DB.md (索引), backend/references/db/ (明细)

### 开发工作流

1. **后端变更** → 跑 `backend/references/scripts/generate_refs.ps1` 刷新契约快照（快照不入库，只需提交代码）
2. **端上同步** → 读 `backend/references/generated/api/routes.md`（端点 + 处理函数）定位实现，按响应结构更新对应网络层/任务模板
3. **数据流向** → Ops 网页端托管 Gallery CLI / comix 任务 → SQLite 单文件数据库 → Android 在线消费（部分模块数据可回传）

### 网络

Monarch 同时监听两个端口，接口完全一致，只有协议不同：`LOCAL_PORT`(7274) HTTPS（自签证书，
供 Android 等局域网消费端，mDNS 广播此端口）与 `LOCAL_HTTP_PORT`(7275) HTTP（本机浏览器打开运维页面用）。
运维页面为 `/ops/`，与 `/API/ops/local/*` 一样仅回环可访问（与端口无关）。

> 改动影响项目结构或开发流程时, 更新涉及到的 AGENTS.md(务必始终保持精简, 只写 agent 需要的信息). 改动影响路由/CLI 参数时, 运行 `generate_refs.ps1` 刷新契约快照(`-Check` 可校验快照是否已与代码脱节).
