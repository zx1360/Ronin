单仓库多目标工作区. Go 后端(Monarch) + Flutter 安卓端(Torrid) + 网页运维端(Northstar, 由 Monarch 内置 HTTP 服务托管).

- backend: backend/AGENTS.md
- android: android/AGENTS.md
- ops: ops/AGENTS.md

后端信息按需查阅:
- 契约快照: backend/references/generated/（生成物，不入 git；真源是 Go 代码）
- 数据库: backend/AGENTS_DB.md (索引), backend/references/db/ (明细)
- CLI 参数快照: backend/references/generated/cli/

### 开发工作流

1. **后端变更** → 运行 `backend/references/scripts/generate_refs.ps1` 刷新契约快照（快照不入库，只需提交代码）
2. **端上同步** → 读 `backend/references/generated/api/routes.md`（端点 + 处理函数）定位实现，按响应结构更新对应网络层/任务模板；
   网页运维端（`ops/web/`）无构建步骤，改完刷新浏览器即可
3. **数据流向** → Ops 网页端托管 Gallery CLI / comix 任务 → SQLite 单文件数据库 → Android 在线消费（部分模块数据可回传）
   - mDNS 自动发现：Monarch 启动时通过 `_monarch._tcp` 注册（`scheme=http`），客户端通过组播 DNS 自动发现
   - 运维页面为 `/ops/`，仅本机回环可访问（本机能力接口 `/API/ops/local/*` 同理）

### 网络

- Monarch 启动后**同时监听两个端口**，接口完全一致，只有协议不同：`LOCAL_PORT`(7274) HTTPS（自签证书，
  供 Android 等局域网消费端，mDNS 广播此端口）与 `LOCAL_HTTP_PORT`(7275) HTTP（本机浏览器打开运维页面用）
- 运维页面：`http://127.0.0.1:7275/ops/` 或 `https://127.0.0.1:7274/ops/`，均仅回环可访问
- Android 端继续连 `https://<局域网IP>:7274`（`assets/cert/server.crt` 仍用于信任自签证书）

> 当改动影响项目结构或开发流程时, 请更新涉及到的 AGENTS.md 中的相关部分(务必始终保持AGENTS.md的精简). 当改动影响路由/CLI 参数时, 请运行 `backend/references/scripts/generate_refs.ps1` 刷新契约快照(`-Check` 可校验快照是否已与代码脱节).
