# Northstar 本机数据与运维端架构

## 1. 它不是独立服务

Northstar 源码在 `ops/web/`，由 Monarch 的 [setupOpsWeb](../../backend/internal/router/router.go) 直接托管：

- `/ops/` 页面静态资源。
- `/API/ops/local/*` 本机能力接口。
- 页面与 API 同源，因此没有独立 dev server、构建产物或 npm 依赖链。
- 生产入口推荐 `http://127.0.0.1:7275/ops/`；HTTPS 入口使用 7274。

## 2. 前端组成

```text
index.html
  └─ src/main.js
      ├─ src/store.js       全局状态、bootstrap、hash 路由、toast、confirm
      ├─ src/api.js         fetch、API key、错误归一化、assetUrl
      ├─ src/ui.js          共享 UI 与 usePolling
      ├─ src/utils.js       格式化
      └─ pages/*.js         页面
          ├─ ai/*.js
          └─ comix/*.js
```

Vue 3 使用仓库内 `vendor/vue.esm-browser.prod.js`，通过 `vue.js` 转出；模板由浏览器运行时编译，不要引入 npm/打包器/CDN。

## 3. 启动与鉴权

```mermaid
sequenceDiagram
    participant B as Browser
    participant W as /ops/
    participant M as Monarch
    participant S as store.js

    B->>W: 打开同源页面
    W->>M: GET /API/ops/local/bootstrap
    M-->>S: apiKey + settings + paths + cli + deps
    S->>S: setApiKey，仅保存在内存
    S-->>B: ready=true，渲染当前 hash 页面
    B->>M: 后续 /API 请求带 X-API-Key
```

bootstrap 本身依赖回环限制，不需要先有 API key；服务端下发的 key 不写 localStorage、cookie 或用户目录。图片资源使用 `assetUrl()` 添加查询参数。

## 4. 页面职责

| Hash 路由 | 页面 | 责任 |
| --- | --- | --- |
| `#/dashboard` | 工作台 | 服务、数据库、存储和依赖状态 |
| `#/booklet` | 积微 | 每日打卡、样式、日历和历史 |
| `#/essay` | 随笔 | 写作、层级标签、搜索、回读、统计和本机草稿 |
| `#/ai` | AI 媒体处理 | 队列、失败、模型、检索、人物、重复、暂停/继续 |
| `#/comix` | 漫画资源 | 站点、漫画库、下载、追更、删除、孤儿回收 |
| `#/tasks` | 任务中心 | Gallery/comix 状态、结果、日志与中断；媒体库维护单独标签页 |
| `#/logs` | 兼容入口 | 解析为任务中心 |
| `#/settings` | 设置 | 界面偏好、连接信息与服务路径 |
| `#/help` | 使用说明 | 操作入口、数据归属、同步与备份 |

`main.js` 的 `routes` 数组是导航顺序和 hash 路由真源，不使用 Vue Router。

## 5. 状态与轮询

[store.js](../../ops/web/src/store.js) 持有单一响应式全局状态：

- `bootstrap()` 用服务端值覆盖默认 settings、paths、cli、deps。
- `saveSettings()` 以 snake_case 局部更新，成功后同步内存镜像。
- `confirmAction()` 由 `confirm_destructive` 控制破坏性操作二次确认。
- 页面操作捕获异常并提示 toast；AI 页通过自身的 `run()` 同时管理忙状态与刷新。

任务、日志与 AI 页在有活动时轮询；任务/日志通常 2 秒，AI 使用偏好间隔。仪表盘在页面可见时按偏好刷新。组件卸载后不得续期轮询。

AI 进入页面先展示 `/API/ai/progress`，随后补齐诊断与配置；活动期间只轮询进度，队列清空后重取统计。轻量进度与已有诊断按字段合并，避免覆盖模型候选和就绪信息。仪表盘目录用量首次返回待统计状态，按需异步扫描完成后展示。

个人数据页只在进入页面、手动刷新或写入后请求，不轮询；`pages/user-data.js` 统一增量合并与图片上传。随笔草稿连同图片保存在浏览器 IndexedDB，编辑时保留正式原文，冲突时保留草稿。

在线写入使用 `/API/user-data/edit/:module` 并附带 `base_cursor`，后端在事务内校验读取快照，过期则整批拒绝并回滚附件；缺少新路由的旧后端不能写入。打卡及标签编辑保留打开表单时的游标；刷新不替换尚未保存的打卡输入和样式快照。离开未保存的打卡表单经过共享导航守卫；关闭浏览器触发原生提醒。

## 6. 破坏性操作边界

删除漫画、软删除媒体、全量 AI 重生成、重聚类和中断任务都必须：

1. 先通过 `confirmAction()`。
2. 调用对应 API。
3. 对 `ok:false`、HTTP 错误、空列表和字段缺失给可读反馈。
4. 成功后刷新受影响的列表/状态，而不是只修改一个局部计数。

大数据量页面使用分页/加载更多和折叠分组，不能把任务队列、重复分组或已删除媒体一次性渲染到 DOM。

## 7. 修改 Northstar 的验证

无需构建；启动 Monarch 后打开页面逐页验证：

```powershell
python tools/smoke_ops_web.py
```

修改 API 后先核对 [routes.md](../../backend/references/generated/api/routes.md) 和 Go handler，再刷新页面；不应为页面另建一份接口文档或字段命名体系。
