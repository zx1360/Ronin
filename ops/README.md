# Northstar

Ronin 的本机个人数据与运维端：随笔、积微打卡和 Monarch 网页管理面板。源码在 `web/`，
执行 `npm.cmd ci --prefix ops/web`、`npm.cmd run build --prefix ops/web`（仓库根目录）后，
由 Monarch 托管 `ops/web/dist/`。已有 `OPS_WEB_DIR` 配置需指向该目录；正式使用无需 Node。
开发使用 `npm run watch` 监听构建，再在 Monarch 页面刷新，无独立开发服务器。
统一验收：`pwsh -File verify.ps1 -Scope ops -OpsBase http://127.0.0.1:<隔离端口>`。

访问方式（仅本机可打开，两个端口接口一致）：

- `http://127.0.0.1:7275/ops/`（本机浏览器用，无证书警告）
- `https://127.0.0.1:7274/ops/`（自签证书，首次需信任一次）

负责 Gallery CLI 任务、漫画库与爬虫任务、AI 媒体处理运维、服务状态与日志查看。
网页端做不到的本机操作（资源管理器定位、任务进程、偏好持久化）由后端
`/API/ops/local/*` 代理，且只接受回环地址。

开发约定与架构说明见 [AGENTS.md](AGENTS.md)。
