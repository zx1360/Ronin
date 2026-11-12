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
4. 在功能目录的 `.drift` 文件维护端上表定义，运行 `dart run build_runner build` 生成代码。
5. 根目录运行 `pwsh -File verify.ps1 -Scope android`。

### 只改 Ops

1. 保持 SFC + Vite 构建、Monarch 同源托管；草稿存 IndexedDB，密钥仅存内存，偏好由服务端持有。
2. 页面请求集中经过 `src/api.js`。
3. 页面操作捕获异常并提示；破坏性操作使用 `confirmAction`，轮询使用 `usePolling`。
4. `pwsh -File verify.ps1 -Scope ops -OpsBase http://127.0.0.1:<隔离端口>`。

## 2. 关键契约陷阱

| 契约 | 不能做的事 | 原因 |
| --- | --- | --- |
| `/API/user-data/sync/*` | 部分写入后再发现坏数据 | 按 updated_at 合并并保留 tombstone；整批校验与事务回滚，成功应用后推进游标 |
| 在线编辑 `base_cursor` | 刷新后默默使用新游标提交旧表单 | 必须保留编辑起点；过期返回 `sync_conflict`，保留输入并核对最新版本 |
| `edit_params` | 自定义另一套旋转/剪裁坐标 | Gallery `execute` 按未旋转原图坐标裁切，再应用逆时针旋转 |
| `sync_count` | 客户端本地自行递增后当服务端值 | “标记已处理”是服务端 `sync_count + 1`，随后清理缓存 |
| Gallery 标签/标注 | 修改本地工作副本却不记录操作 | 本地状态与操作表必须同事务提交，服务端校验后才能清理 |
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

仓库根使用 PowerShell 7，显式选择范围：

```powershell
pwsh -File verify.ps1 -Scope backend
pwsh -File verify.ps1 -Scope android
pwsh -File verify.ps1 -Scope contracts
pwsh -File verify.ps1 -Scope ops -OpsBase http://127.0.0.1:17275
pwsh -File verify.ps1 -Scope all -OpsBase http://127.0.0.1:17275
```

地址必须是已运行的隔离 Monarch 实例。省略 `-OpsBase` 时执行构建、静态检查和测试，并提示跳过浏览器。失败返回非零退出码。

- `backend` 执行 Go build/vet/test、Monarch 与 Gallery 构建和快照校验。首次验收会生成尚未创建的快照。路由导出使用临时目录，独立于 `.env` 和 Ops 构建。
- `android` 执行依赖解析、代码生成、analyze、测试和 debug APK 构建。
- `contracts` 单独运行跨端契约用例。`all` 的三端完整测试已覆盖这些用例。共享样例见 [contracts](../../contracts/README.md)。

Ops 使用 npm ci/build 与原契约测试，浏览器验收用 Python Playwright（复用 comix 的依赖）。开发监听构建在 ops/web 下运行 npm run watch，仍访问 Go 托管产物。

## 5. 当前架构的已知取舍

- 子进程任务状态不持久化：重启后由 CLI 的幂等/孤儿自愈恢复，而不是恢复 Go 内存对象。
- AI 向量不使用专用数据库索引，依赖 Go 内存精确扫描；媒体规模增长时应重新评估。
- 文本 AI 检索使用 `LIKE '%kw%'`，短期简单可靠，文本量增长后再考虑 FTS5/trigram。
- Gallery 持久化离线操作并按序回传，批次校验后清理；Immich 在线直写。
- 双端口不是两套 API：任何端口差异都应只体现在协议和访问边界，不要复制路由实现。
