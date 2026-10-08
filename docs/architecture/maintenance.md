# 架构维护手册

## 1. 变更分类与最短路径

### 只改 Monarch API/路由

1. 修改 `backend/internal/router`、handler/service/repository。
2. 更新必要的 model、schema/migration。
3. 运行 `references/scripts/generate_refs.ps1` 刷新路由/CLI 快照。
4. 按处理函数读取响应结构，更新 Android DTO/service 和 Northstar 页面。
5. 运行 Go build/vet/test。

### 只改 Android

1. 先确认 API 语义是否已经存在；不要在端上猜字段。
2. 网络配置只改 `NetworkConfigManager`，请求只经 `ApiClient`。
3. 页面逻辑下沉 provider/service；页面保留渲染、导航和选择状态。
4. 修改 Hive 模型前检查 typeId。
5. `flutter analyze`，必要时补 widget/unit test。

### 只改 Ops

1. 保持无构建、同源、无浏览器持久化。
2. 页面请求集中经过 `src/api.js`。
3. 页面级操作使用 `runAction`、`confirmAction` 和 `usePolling`。
4. `python tools/smoke_ops_web.py`。

## 2. 关键契约陷阱

| 契约 | 不能做的事 | 原因 |
| --- | --- | --- |
| `/API/user-data/sync/*` | 部分写入后再发现坏数据 | 它是完整数据集替换，必须先完整解析校验、事务性替换 |
| `edit_params` | 自定义另一套旋转/剪裁坐标 | Gallery `execute` 解释原图坐标并先旋转再裁剪 |
| `sync_count` | 客户端本地自行递增后当服务端值 | “标记已处理”是服务端 `sync_count + 1`，随后清理缓存 |
| Gallery 标签/标注 | 只改 Android `gallery.db` | 服务端是权威，本地只是缓存/写队列 |
| AI 503 | 抛到顶层页面或假造能力列表 | AI 可关闭/未初始化，消费端必须降级 |
| AI 模型名 | 端上硬编码模型 | 候选来自本机 Ollama，模型可增删 |
| NDJSON | 按网络 chunk 而不是按行解析 | 一个事件可能跨多个 chunk |
| CLI 任务 | handler 中同步 `exec.Command` | 需要日志、退出码、杀进程树和内存任务状态 |
| DB 新列 | 只修改 schema 的 `CREATE TABLE` | 既有库不会自动补列，必须走 migrate |
| Ops 偏好 | 在浏览器另存一份 camelCase | 服务端 `ops_web.json` 使用 snake_case，是唯一偏好真源 |

## 3. 推荐的代码阅读顺序

遇到跨端问题时，不要从页面反向猜后端：

```text
路由快照
  -> Go handler
  -> Go service/repository
  -> references/db/*.md + sqlite.sql
  -> Android service/provider 或 Ops api/page
  -> 端上缓存/错误/降级策略
```

## 4. 验证命令

后端：

```powershell
cd D:\products\Ronin\backend
go build ./...
go vet ./...
go test ./...
powershell -ExecutionPolicy Bypass -File .\references\scripts\generate_refs.ps1 -Check
```

Gallery CLI：

```powershell
cd D:\products\Ronin\backend\gizmos
go build ./cmd/gallery
```

Android：

```powershell
cd D:\products\Ronin\android
flutter analyze
```

Ops：

```powershell
cd D:\products\Ronin\backend
python tools/smoke_ops_web.py
```

## 5. 当前架构的已知取舍

- 子进程任务状态不持久化：重启后由 CLI 的幂等/孤儿自愈恢复，而不是恢复 Go 内存对象。
- AI 向量不使用专用数据库索引，依赖 Go 内存精确扫描；媒体规模增长时应重新评估。
- 文本 AI 检索使用 `LIKE '%kw%'`，短期简单可靠，文本量增长后再考虑 FTS5/trigram。
- Gallery 与 Immich 有意采用不同写入策略：一个支持离线合并，一个始终在线直写。
- 双端口不是两套 API：任何端口差异都应只体现在协议和访问边界，不要复制路由实现。
