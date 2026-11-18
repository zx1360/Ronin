# SQLite

- schema 真源为 [sqlite.sql](references/db/sqlite.sql) 和 [comix.sql](references/db/comix.sql)。自定义 `DB_SCHEMA_FILE` 时两份脚本放同目录。
- Monarch 和 Gallery 共用 `internal/service/db` 的事务初始化。非漫画域加列同时更新 `sqlite.sql` 和 `migrate.go` 的 `addedColumns`。Gallery 的 FULL 提交保护入库后清理源文件。comix init 只执行漫画域脚本，漫画迁移由 Monarch 和 comix 共用。
- 读走 `db.Read`，写走 `db.Exec` 或 `db.Tx`。写池单连接，跨进程竞争走 WAL、BEGIN IMMEDIATE、busy timeout 和重试。多步写入用事务。
- 时间戳存本机时区的定宽毫秒文本。随笔按本地日期统计，打卡日期用 UTC 零点标记日历日。同步行版本由应用写入。
- Repository 测试用临时库。兼容性验收可用 `MONARCH_DB_SRC` 指定只读快照来源。领域语义按需读[用户数据](references/db/user_data.md)、[画廊](references/db/gallery.md)、[漫画](references/db/comix.md)或 [AI](references/db/ai.md)。
