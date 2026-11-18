# Northstar

- Vue SFC 在 `web/src/`，由 Monarch 托管 `web/dist/`。同源请求及媒体地址走 `api.js`，bootstrap 密钥存内存，偏好和操作确认走 `store.js`。
- 随笔和积微沿用 user-data v2，在线编辑提交 `base_cursor`。随笔草稿与图片存 IndexedDB，保存成功后才清草稿。
- 自动刷新复用 `usePolling`，任务和 AI 进度按活动状态续期，页面卸载时取消。验收用 `pwsh -File verify.ps1 -Scope ops`，浏览器冒烟用 `-OpsBase`。
