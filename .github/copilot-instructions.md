单仓库多目标工作区. Go 后端(Monarch) + Flutter 安卓应用(frontend) + 运维网页端(ops).

- backend: backend/AGENTS.md
- frontend: frontend/AGENTS.md
- ops: ops/AGENTS.md

后端信息按需查阅:
- API 契约: backend/references/api/ (含生成的 contract.json)
- 数据库: backend/AGENTS_DB.md (索引), backend/references/db/ (明细)
- CLI 文档: backend/references/cli/

### 开发工作流

1. **后端变更** → 运行 `backend/references/scripts/generate_refs.ps1` → 提交代码 + `references/` 与客户端契约产物
2. **客户端同步** → 契约（端点与模型）越界部分由生成产出，手工只需接新页面
3. **数据流向** → Monarch（单文件 SQLite）← 前端在线消费/回传用户数据；gallery CLI 由 Monarch 管理生命周期
   - ops 网页端（`http://127.0.0.1:<LOCAL_DEBUG_PORT>/ops/`）只经回环 http 调用后端提供的本机能力，自身不起进程、不落文件
   - mDNS 自动发现：Monarch 启动时通过 `_monarch._tcp` 注册，客户端通过组播 DNS 自动发现

### 分支策略

- 自签证书：后端与前端统一，Flutter 端通过 `assets/cert/server.crt` 信任；ops 走回环 http 无需证书

> 当改动影响项目结构或开发流程时, 请更新涉及到的 AGENTS.md 中的相关部分(务必始终保持AGENTS.md的精简). 当改动影响契约文件时, 请运行 `backend/references/scripts/generate_refs.ps1` 来生成最新的 references/ 产物.
