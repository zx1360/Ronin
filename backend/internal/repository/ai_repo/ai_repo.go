// Package ai_repo 提供 ai schema 的数据访问。
//
// 只读写 ai schema 内自有对象；对 gallery.media_assets 仅做只读筛选与外键引用，
// 不修改其任何列或语义。
package ai_repo

import (
	"context"
	"errors"
	"fmt"
	"math"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"monarch/internal/service/db"
)

// 可识别的业务错误。
var (
	ErrSchemaMissing = errors.New("ai schema 未初始化，请先执行 references/db/ai.sql")
	ErrPersonMissing = errors.New("人物不存在")
)

// querier 抽象 *pgxpool.Pool 与 pgx.Tx。
type querier interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}

// schemaReadyOnce 仅用于把"schema 缺失"这一确定性事实缓存下来，避免每次请求都探测。
var schemaKnownMissing bool

// SchemaReady 报告 ai schema 是否已初始化（未初始化时全部 AI 接口返回可读错误）。
func SchemaReady(ctx context.Context) bool {
	if db.GetPool() == nil {
		return false
	}
	if schemaKnownMissing {
		return false
	}
	var ok bool
	err := db.GetPool().QueryRow(ctx, `SELECT to_regclass('ai.jobs') IS NOT NULL`).Scan(&ok)
	if err != nil || !ok {
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

// joinCSV 以逗号拼接（写入 ai.settings 用）。
func joinCSV(items []string) string {
	return strings.Join(items, ",")
}

// withTx 在事务内执行 fn，失败自动回滚。
func withTx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	tx, err := db.GetPool().Begin(ctx)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback(ctx)
	if err := fn(tx); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("提交事务失败: %w", err)
	}
	return nil
}

// DecodeFloat32 把 bytea 还原为 float32 切片（小端，与 Python 侧约定一致）。
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
