单仓库多目标工作区. Go 后端 Monarch + Flutter 安卓端 Torrid + Flutter 桌面端 Northstar.

- backend: backend/AGENTS.md
- android: android/AGENTS.md
- desktop: desktop/AGENTS.md

后端信息按需查阅:
- API 契约: backend/references/api/
- 数据库: backend/AGENTS_DB.md (索引), backend/references/db/ (明细)
- CLI 文档: backend/references/cli/

### 开发工作流

1. **后端变更** → 运行 `backend/references/scripts/generate_refs.ps1` → 提交代码 + `references/` 产物
2. **Flutter 端同步** → 对比 `backend/references/api/` diff → 更新对应网络层/任务模板
3. **数据流向** → Desktop 启停 Monarch + CLI → PostgreSQL → Android 在线消费（部分模块数据可回传）
   - mDNS 自动发现：Monarch 启动时通过 `_monarch._tcp` 注册，客户端通过组播 DNS 自动发现

### 分支策略

- 自签证书：三端统一，Flutter 端通过 `assets/cert/server.crt` 信任

> 当改动影响项目结构或开发流程时, 请更新涉及到的 AGENTS.md 中的相关部分. 当改动影响契约文件时, 请运行 `backend/references/scripts/generate_refs.ps1` 来生成最新的 references/ 产物.