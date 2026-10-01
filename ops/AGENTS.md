# Northstar

`web/` 由 Monarch 在 `/ops/` 托管，仅回环可访问。Vue 3 浏览器 ESM + 原生模块，无构建步骤；不引入 npm、打包器或 CDN。
架构见 `../docs/architecture/northstar.md`。

- `src/main.js`：hash 路由/导航；`api.js`：同源请求与 `assetUrl`；`store.js`：引导/偏好/通知/确认；`ui.js`：共享组件与 `usePolling`。
- 页面在 `src/pages/`，复杂标签页拆到同名目录；模板所需派生值在 setup 中计算，界面使用中文。
- 启动只调用一次 `/API/ops/local/bootstrap` 获取密钥、偏好和路径。密钥只放内存，图片用 `assetUrl`；不写 localStorage/cookie。
- 偏好由服务端 `ops_web.json` 持有，沿用 snake_case 字段，通过 `saveSettings` 局部更新。
- 破坏性操作使用 `confirmAction`（遵守用户关闭确认的偏好）；HTTP 错误、`ok:false`、空数据须有可读反馈。
- 任务、日志、AI 页仅在有活动时轮询；仪表盘按偏好刷新。统一用 `usePolling`，卸载后不得续期或发起请求。
- 大列表分页/加载更多；分组默认折叠，展开后才挂载缩略图；表头吸顶与滚动样式复用 `assets/app.css`。
- API 真源在后端，按 `../backend/references/generated/api/routes.md` 定位处理函数核对结构。
- 验收在 `backend/` 运行 `python tools/smoke_ops_web.py`；可用 `OPS_SMOKE_BASE` 指定隔离实例。
