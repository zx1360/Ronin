当前项目包含一个Go后端和两个Flutter前端(安卓和桌面).各子项目详情见各自 AGENTS.md.

- 根总览: AGENTS.md
- backend: backend/AGENTS.md
- android: android/AGENTS.md
- desktop: desktop/AGENTS.md

按需查阅:
- API 契约: backend/references/api/
- 数据库: backend/AGENTS_DB.md (索引), backend/references/db/ (明细)
- CLI 文档: backend/references/cli/

(当改动影响项目结构或开发流程时, 请更新 AGENTS.md 中的相关部分.)
(当改动影响契约文件时, 请运行 `backend/references/scripts/generate_refs.ps1` 来生成最新的 references/ 产物.)