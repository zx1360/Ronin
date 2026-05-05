## 项目说明 (Monarch)

Ronin 三端架构的"唯一真理"层，由 Go 语言开发，包含两大模块。

### 模块

- **Monarch HTTP**（仓库根）: Gin 服务器，为 Android (Torrid) 和 Desktop (Northstar) 提供 REST API。
- **Gizmos CLI**（`gizmos/`）: 独立 Go module，负责命令行批处理——漫画索引、媒体资产摄入/刷新/执行删除。

### 技术栈

- Go + Gin + GORM + PostgreSQL 18.0
- 支持 HTTP/HTTPS 双模式（自签证书），`X-API-Key` 鉴权
- Immich 反向代理（`/api/*` → `127.0.0.1:2283`）
- Swagger (swag) 自动生成 API 文档

### 快速启动

```bash
# 本地开发模式 (HTTP, 无鉴权)
go run ./cmd -mode local

# 生产模式 (HTTPS, X-API-Key 鉴权)
go run ./cmd
```

### 环境变量 (.env)

| 变量 | 说明 |
|------|------|
| `LOCAL_PORT` | 服务端口 |
| `LOCAL_DEBUG_PORT` | 调试端口 |
| `STATIC_DIR` | 静态资源目录 |
| `GALLERY_DIR` | 画廊媒体根目录 |
| `COMIC_DIR` | 漫画资源根目录 |
| `DB_IP/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME` | PostgreSQL 连接 |

### API 概览

| 路由组 | 端点 | 用途 |
|--------|------|------|
| `/API/user-data` | `GET /sync/:module`, `POST /backup/:module` | 用户数据同步/备份 |
| `/API/comic` | `GET /meta-info`, `/comic-info`, `/comic-info/:id`, `/chapter-info/:id`, `/download/:id` | 漫画浏览与离线下载 |
| `/API/gallery` | `GET /batch`, `/tags`, `/:id/:type`; `POST /push` | 媒体资产浏览、文件流、客户端推送 |
| `/API/library` | （预留） | 库存页 |
| `/API/ops` | `GET /overview` | 系统概览（桌面运维用） |
| `/api/*` | 所有方法 | Immich 反向代理 |
| `/static` | 静态文件 | 资源托管 |

### CLI 工具 (Gizmos)

| 工具 | 模式 | 功能 |
|------|------|------|
| Comic Indexer | `refresh` / `full-reindex` | 增量/全量检索漫画文件写入数据库 |
| Gallery | `ingest` / `execute` / `refresh` | 摄入媒体文件 → 生成缩略图 → 归档；执行客户端删除；刷新元数据 |

### 跨项目契约

修改 Go 接口或 CLI 后，必须运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\references\scripts\generate_refs.ps1
```

提交时把代码改动和 `references/` 产物一起提交。Flutter 工作区更新后优先看 `references/api/swagger.json` 和 `routes.json` 的差异，按最新契约改客户端并联调。

### 硬性要求（AI 辅助开发备忘）

- 考虑到边界情况，做好异常防护。
- 除非明确要求，不对已有功能引入破坏性修改。
- 更新数据库记录时显式更新所有字段值。
- 修改直到项目无错且能正确按预期运行。
- 注意代码可维护性。

### 数据库

表定义及触发器参见 `./AGENTS_DB.md`。

### 关联项目

- 桌面运维端: `../desktop/` (Northstar)
- 安卓移动端: `../android/` (Torrid)