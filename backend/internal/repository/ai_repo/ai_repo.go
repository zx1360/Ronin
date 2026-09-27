// Package ai_repo 提供 AI 处理层（ai_* 表）的数据访问。
//
// 只读写 ai_* 自有表；对 gallery_media_assets 仅做只读筛选与外键引用，
// 不修改其任何列或语义。
package ai_repo

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"math"
	"strings"

	"monarch/internal/service/db"
)

// 可识别的业务错误。
var (
	ErrSchemaMissing = errors.New("AI 数据表未就绪")
	ErrPersonMissing = errors.New("人物不存在")
)

// execer 抽象 *sql.DB 与 *sql.Tx 的执行能力。
type execer interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// SchemaReady 报告 AI 数据表是否已就绪（未就绪时全部 AI 接口返回可读错误）。
//
// ApplySchema 在启动时建表，因此这里只做一次廉价探测；刻意不缓存否定结果，
// 以免重建数据库后必须重启进程才能恢复。
func SchemaReady(ctx context.Context) bool {
	if db.R() == nil {
		return false
	}
	var one int
	err := db.R().QueryRowContext(ctx,
		`SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ai_jobs'`).Scan(&one)
	return err == nil
}

// ensureSchema 在写入口做一次轻量校验，给出明确错误而不是裸 SQL 报错。
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

// placeholders 生成 n 个 "?" 占位符；n <= 0 返回空串，调用方需自行跳过该条件。
func placeholders(n int) string {
	if n <= 0 {
		return ""
	}
	return strings.TrimSuffix(strings.Repeat("?,", n), ",")
}

// anyArgs 把切片展开成 IN 子句参数。
func anyArgs[T any](items []T) []any {
	out := make([]any, len(items))
	for i, v := range items {
		out[i] = v
	}
	return out
}

// encodeJSONArray 序列化 JSON 数组列；nil 切片写成 []，
// 避免 SQLite 侧的 json_each 读到 null 而报错。
func encodeJSONArray[T any](items []T) (string, error) {
	if items == nil {
		return "[]", nil
	}
	raw, err := json.Marshal(items)
	if err != nil {
		return "", err
	}
	return string(raw), nil
}

// decodeJSONArray 解析 JSON 数组列；空文本与 null 都视为空数组。
func decodeJSONArray[T any](raw string) ([]T, error) {
	if strings.TrimSpace(raw) == "" || strings.TrimSpace(raw) == "null" {
		return []T{}, nil
	}
	var out []T
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return nil, err
	}
	if out == nil {
		out = []T{}
	}
	return out, nil
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
