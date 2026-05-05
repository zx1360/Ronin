## Ronin 三端架构 · 总览

单仓库多目标工作区。Go 后端 Monarch + Flutter 安卓端 Torrid + Flutter 桌面端 Northstar。

> 各子项目详情见各自 `AGENTS.md`。数据库结构见 `backend/AGENTS_DB.md`（索引）及 `backend/references/db/`（分模块明细）。API 契约见 `backend/references/api/`。

### 开发工作流

1. **后端变更** → 运行 `backend/references/scripts/generate_refs.ps1` → 提交代码 + `references/` 产物
2. **Flutter 端同步** → 对比 `backend/references/api/` diff → 更新对应网络层/任务模板
3. **数据流向** → Desktop 启停 Monarch + CLI → PostgreSQL → Android 在线消费（可 `POST /API/gallery/push` 回传）

### 分支策略

- `release`：统一修订分支，各子项目无独立分支
- 自签证书：三端统一，Flutter 端通过 `assets/cert/server.crt` 信任