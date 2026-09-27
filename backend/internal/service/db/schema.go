package db

import (
	"context"
	"database/sql"
	_ "embed"
	"fmt"
)

// schemaSQL 是 SQLite 结构的唯一真相源；references/db/schema.sql 是它的生成副本。
//
//go:embed schema.sql
var schemaSQL string

// schemaVersion 写入 PRAGMA user_version，仅作"这份库由哪个版本的结构建出"的标记。
const schemaVersion = 1

// ApplySchema 幂等地应用全部表与索引（可重复执行）。
func ApplySchema(ctx context.Context, conn *sql.DB) error {
	if _, err := conn.ExecContext(ctx, schemaSQL); err != nil {
		return fmt.Errorf("执行 schema.sql 失败: %w", err)
	}
	if _, err := conn.ExecContext(ctx, fmt.Sprintf("PRAGMA user_version = %d", schemaVersion)); err != nil {
		return fmt.Errorf("写入 user_version 失败: %w", err)
	}
	return nil
}
