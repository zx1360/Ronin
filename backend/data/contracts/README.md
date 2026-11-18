# 跨端契约

样例 `user_data.json` 覆盖版本合并、删除、重复提交与时间语义。`ai.json` 覆盖对话默认值、模型候选和轻量进度。按需运行 `pwsh -File verify.ps1 -Scope contracts`，单端可用 `pwsh -File backend/tools/check_contracts.ps1 -Scope <backend|android|ops>`。整端测试已包含这些用例。

## 随笔与积微

- `GET /API/user-data/sync/:module?sync_version=2&after=<cursor>` 同快照返回变化行、`tombstones` 和新游标。游标来自服务端递增 revision。省略游标或传 0 读取全量，失效时重新全量合并。数据与游标同批应用，失败保留已提交快照。
- `POST /API/user-data/sync/:module` 与 `backup/:module` 在随笔和积微使用 v2 完整行与显式 tombstone。较新 `updated_at` 获胜，同时间保留服务端记录，删除与记录同时间时删除优先。随笔声明 `essay_schema_version=3` 后另按 `labels_updated_at` 合并关联标签。偏好整体替换。
- Northstar 用 `POST /API/user-data/edit/:module` 携带读取快照的 `base_cursor`。过期返回 409 和 `sync_conflict`，数据库与附件一并回滚。旧后端缺少该入口时保留输入，等待后端升级。
- 同样式同日多 ID 打卡按版本归一并为落败 ID 写 tombstone。仍有更新的关联记录时拒绝删除样式。标签树和引用失败均回滚。合并后重算统计，已存在的附件按不可变文件名保留。详见[用户数据存储](../../references/db/user_data.md)。

尚无偏好备份时，`GET /API/user-data/sync/preferences` 返回 404 和 `preferences_not_backed_up`，客户端保留本机设置并继续完成同步。

## 时迹

`GET /API/user-data/trace/backup` 在无备份时返回 revision 0 和 `snapshot: null`。PUT 提交读取的 revision 与合并后的快照，过期返回 409，成功返回新 revision。快照使用 `format_version: 1`，包含 `scenes`、`items`、`tags`、`sessions`，时刻使用毫秒绝对时间。颜色用 `#RRGGBB`，恢复兼容旧 ARGB 整数。场景删除值为空、`keep`（历史归到「其他」）或 `erase`（删除关联记录）。

## AI

对话和回顾返回 NDJSON，回顾先发 `stats` 再发正文增量。客户端处理 `notice`、`aborted` 及开始流前的 JSON 503。网页合并轻量进度时保留已有诊断和候选模型。回顾预设由服务端整体保存，客户端用返回值更新镜像。
