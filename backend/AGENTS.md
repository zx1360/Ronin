## 项目说明 (Monarch)

Ronin 三端架构的"唯一真理"层，Go 语言开发。

### 模块

- **Monarch HTTP**：Gin 服务器，为 Torrid (Android) 和 Northstar (Desktop) 提供 REST API。
- **Gizmos CLI**（`gizmos/`）：独立 Go module，命令行批处理（漫画索引、媒体摄入/刷新/删除）。

### 技术栈

Go + Gin + pgx + PostgreSQL 18.0。支持 HTTP/HTTPS（自签证书），`X-API-Key` 鉴权。Immich 反向代理（`/api/*` → `127.0.0.1:2283`）。启动时自动通过 mDNS (`_monarch._tcp`) 注册服务，供客户端自动发现。

### 快速启动

```bash
go run ./cmd -mode local    # 开发模式 (HTTP, 无鉴权)
go run ./cmd                # 生产模式 (HTTPS, X-API-Key 鉴权)
```

### 环境变量 (.env)

`LOCAL_PORT`, `LOCAL_DEBUG_PORT`, `STATIC_DIR`, `GALLERY_DIR`, `COMIC_DIR`, `DB_IP/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME`

### API 概览

| 路由组 | 关键端点 | 用途 |
|--------|---------|------|
| `/API/user-data` | `GET /sync/:module`, `POST /backup/:module` | 用户数据同步/备份 |
| `/API/comic` | `/meta-info`, `/comic-info`, `/chapter-info`, `/download` | 漫画浏览与离线下载 |
| `/API/gallery` | `/batch`, `/tags`, `/:id/:type`, `POST /push` | 媒体资产浏览、文件流、推送 |
| `/API/ops` | `GET /overview` | 系统概览（Desktop 用） |
| `/api/*` | 所有方法 | Immich 反向代理 |

### CLI 工具 (Gizmos)

详见 `references/cli/`。主要命令: Comic Indexer（`refresh`/`full-reindex`）、Gallery（`ingest`/`execute`/`refresh`）。

### 跨项目契约

修改 Go 接口或 CLI 后运行：
```powershell
powershell -ExecutionPolicy Bypass -File .\references\scripts\generate_refs.ps1
```
### 数据库

表定义及触发器见 `AGENTS_DB.md`（索引）和 `references/db/`（分模块明细）.

### 硬性要求

- 考虑边界情况, 做好异常防护.
- 除非明确要求, 不对已有功能引入破坏性修改.
- 更新数据库记录时显式更新所有字段值.
- 注意代码可维护性.