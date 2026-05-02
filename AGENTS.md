## Ronin 三端架构 · 总览

单仓库多目标工作区，服务于个人数字生活。一个后端，两个前端，构成完整闭环。

### 项目地图

| 目录 | 项目名 | 角色 | 技术栈 |
|------|--------|------|--------|
| `backend/` | Monarch | API 服务器 + CLI 批处理（唯一真理） | Go + Gin + GORM + PostgreSQL |
| `android/` | Torrid | 安卓移动端消费应用 | Flutter + Riverpod + Dio |
| `desktop/` | Northstar | Windows 桌面运维管理面板 | Flutter + Riverpod + `dart:io` |

### 协同架构

```
 Desktop (Northstar)           Android (Torrid)
    │ 启动/监控/管CLI              │ 消费 API + 推送
    ▼                              ▼
          Backend (Monarch)
          Gin HTTP API Server
          ├─ /API/comic/*      → 漫画浏览、离线下载
          ├─ /API/gallery/*    → 媒体资产、文件流
          ├─ /API/user-data/*  → 用户数据同步备份
          ├─ /API/ops/*        → 系统概览（Desktop 用）
          ├─ /api/*            → Immich 代理
          └─ /static/*         → 资源托管
                    │
          Gizmos CLI (gizmos/)
          ├─ Comic Indexer     → 漫画文件检索入库
          └─ Gallery           → 媒体摄入/缩略图/归档/刷新
                    │
              PostgreSQL 18.0
```

### 开发工作流

1. **后端变更**（API / CLI）
   - 修改 Go 代码 → 运行 `generate_refs.ps1` → 提交代码 + `references/` 产物
   - 产物位置：`backend/references/api/swagger.json`、`routes.json`、`routes.md`、`cli/*.md`

2. **Flutter 端同步**
   - 拉取后端提交 → 对比 `references/api/` 目录 diff
   - Torrid: 更新 `lib/core/services/` 和 `lib/providers/api_client/` 中对应的网络层代码
   - Northstar: 更新 `OpsApiClient` / `default_task_templates.dart` / ArgPreset 参数

3. **数据流向**
   - Desktop 启停 Monarch + 执行 CLI 任务 → 数据进入 PostgreSQL
   - Android 通过 API 在线消费（漫画阅读、画廊浏览）
   - Android 可通过 `POST /API/gallery/push` 将移动端标签/媒体回传后端

### 自签证书

三端统一使用自签证书。Flutter 端通过 `assets/cert/server.crt` 信任该证书，HTTPS 时不依赖系统证书存储。

### 分支策略

- `release`：所有子项目 `fd4800a` 修订于此分支
- 各子项目无独立分支，统一提交节奏
- 根目录 `Ronin.code-workspace` 定义 VS Code 多根工作区配置

### 快速参考

```bash
# 启动后端 (开发模式)
cd backend && go run ./cmd -mode local

# 运行 CLI 工具
cd backend/gizmos && go run ./cmd/gallery -mode ingest ...
cd backend/gizmos && go run ./cmd/comic-indexer -mode refresh ...

# 启动桌面应用
cd desktop && flutter run -d windows

# 启动安卓应用
cd android && flutter run