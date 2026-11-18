# Northstar

- Vue 页面在 `web/src/pages/`。同源请求和媒体地址走 `api.js`，bootstrap 密钥存内存。偏好和确认走 `store.js`。
- 在线编辑携带读取时的 `base_cursor`。随笔草稿与图片存 IndexedDB，正式写入确认后清理草稿。
- 自动刷新复用 `usePolling`。任务和 AI 按活动状态续期，页面卸载时取消。
- 浏览器专项用 `python backend/tools/smoke_ops_web.py --base <隔离地址> --case <persons|polling|essay|errors>`。需要全页冒烟时通过 `verify.ps1 -Scope ops -OpsBase <隔离地址>` 执行。
