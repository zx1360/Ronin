# 三端契约

执行：`pwsh -File backend/tools/check_contracts.ps1`；`-Scope backend|android|ops` 可只检查一端。检查只使用临时数据库，无需启动后端。

- `user_data.json`：服务端与本机版本合并、删除竞争、重复提交、日历日与时刻。相同更新时间保留服务端记录；删除与记录同时间时删除优先。
- `ai.json`：聊天默认值、模型候选与轻量进度；进度合并必须保留已有诊断信息。

后端验证实际 SQLite 合并；Android 验证本机合并和游标提交；Ops 验证增量响应的整批应用与进度合并。无效响应不得部分提交或推进游标。

在线编辑使用 `POST /API/user-data/edit/:module`，必须附带 `base_cursor`，值为打开编辑时读取的模块游标。后端在写事务内校验；快照过期返回 HTTP 409、`code: sync_conflict`，整批数据库与附件写入回滚。冲突时保留输入，刷新核对后重新编辑。旧后端没有该路由，拒绝写入，避免网页先升级时退回无保护合并。Android 离线同步继续使用 `sync/:module`，沿用逐行合并。
