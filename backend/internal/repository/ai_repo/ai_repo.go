// Package ai_repo 提供 AI 处理层的数据访问。
//
// 只读写 ai 侧自有表；对 media_assets 仅做只读筛选与外键引用，不修改其任何列
// 或语义。`vlm_tags` 是 media_ai_tags 关系表，不是 media_ai 的列。
package ai_repo

import (
	"context"
	"database/sql"
	"errors"
	"math"
	"strings"

	"monarch/internal/service/db"
)

// 可识别的业务错误。
var (
	ErrSchemaMissing = errors.New("AI 数据表未初始化，请确认已执行 references/db/sqlite.sql")
	ErrPersonMissing = errors.New("人物不存在")
)

// querier 抽象 *sql.Tx 与 *sql.DB。
type querier interface {
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// schemaReadyChecked 仅用于把"表缺失"这一确定性事实缓存下来，避免每次请求都探测。
var (
	schemaReadyChecked bool
	schemaKnownMissing bool
)

// SchemaReady 报告 AI 侧数据表是否已初始化（未初始化时全部 AI 接口返回可读错误）。
func SchemaReady(ctx context.Context) bool {
	if db.Read() == nil {
		return false
	}
	if schemaReadyChecked {
		return !schemaKnownMissing
	}
	var n int
	err := db.Read().QueryRowContext(ctx,
		`SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'jobs'`).Scan(&n)
	schemaReadyChecked = true
	if err != nil || n == 0 {
		schemaKnownMissing = true
		return false
	}
	return true
}

// ensureSchema 在每个写入口做一次轻量校验，给出明确错误而不是裸 SQL 报错。
func ensureSchema(ctx context.Context) error {
	if !SchemaReady(ctx) {
		return ErrSchemaMissing
	}
	return nil
}

// SplitAndTrim 按逗号切分并去除空白项。
func SplitAndTrim(raw string) []string {
	var out []string
	for _, part := range strings.Split(raw, ",") {
		if part = strings.TrimSpace(part); part != "" {
			out = append(out, part)
		}
	}
	return out
}

// placeholders 生成 n 个 `?`（空集合返回 NULL，使 IN 子句恒为空集）。
func placeholders(n int) string {
	if n <= 0 {
		return "NULL"
	}
	return strings.TrimSuffix(strings.Repeat("?,", n), ",")
}

// joinValues 以逗号拼接占位符组（调用方负责转义）。
func joinValues(values []string) string {
	return strings.Join(values, ", ")
}

// DecodeFloat32 把 BLOB 还原为 float32 切片（小端，与 Python 侧约定一致）。
func DecodeFloat32(raw []byte) []float32 {
	if len(raw)%4 != 0 {
		return nil
	}
	out := make([]float32, len(raw)/4)
	for i := range out {
		bits := uint32(raw[i*4]) | uint32(raw[i*4+1])<<8 |
			uint32(raw[i*4+2])<<16 | uint32(raw[i*4+3])<<24
		out[i] = math.Float32frombits(bits)
	}
	return out
}
