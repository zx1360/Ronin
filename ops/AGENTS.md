# Northstar

`web/` 是 Vue SFC + Vite 源码。Monarch 将 `web/dist/` 挂载在 `/ops/`，网页及 `/API/ops/local/*` 仅允许回环访问。Northstar 负责本机随笔、打卡和后端运维，数据写入及本机进程由 Monarch 处理。

- 页面在 `web/src/pages/`；同源请求和媒体地址复用 `api.js`，偏好及破坏性操作确认复用 `store.js`。启动时从 `/API/ops/local/bootstrap` 获取密钥，仅在内存中保存。
- 随笔和打卡沿用 user-data 增量协议。随笔草稿及其图片存于浏览器 IndexedDB，正式原文保留至保存成功。
- 使用 `usePolling`，离开页面后停止续期。任务、日志和 AI 页面仅按活动状态轮询，仪表盘按偏好刷新。
- API 真源在 `../backend/internal/router/`。在仓库根目录运行 `pwsh -File verify.ps1 -Scope ops`，浏览器验收通过 `-OpsBase` 指定隔离实例。
