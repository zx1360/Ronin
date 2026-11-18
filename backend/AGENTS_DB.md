# SQLite

- schema 真源为 `references/db/sqlite.sql` 和 `references/db/comix.sql`。自定义 `DB_SCHEMA_FILE` 时，两份脚本放同一目录。
- Monarch 和 Gallery 共用 `internal/service/db` 的事务初始化。非漫画域加列同时更新 `sqlite.sql` 和 `migrate.go` 的 `addedColumns`。Gallery 的 FULL 提交保护入库后清理源文件。comix init 只执行漫画域的共享脚本，漫画域结构迁移须由双方共用。
- Go 写池单连接，WAL、BEGIN IMMEDIATE、busy timeout 和重试用于跨进程竞争。多步写入用事务。
- 时间戳是本机时区定宽毫秒文本。随笔按本地日期统计。打卡日期列以 UTC 零点表示日历日。同步表由应用写入版本，避免用触发器改写。
- Repository 验收默认使用临时库，`MONARCH_DB_SRC` 可指定只读快照源。AI 缺产物统计依赖 `media_assets(is_deleted, id)` 覆盖索引，只在诊断接口按需执行。
