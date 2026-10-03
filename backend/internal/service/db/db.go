// 数据库连接（单文件 SQLite）
//
// 单写者模型：全部写入走只开一个连接的 writePool（`_txlock=immediate`，
// 事务一开始就取写锁，避免读→写升级时的死锁），读取走可并发的 readPool
// （WAL 日志模式下读写互不阻塞）。跨进程竞争（comix 子进程）由 busy_timeout
// 与 [dbutil.IsBusy] 退避重试兜底。
package db

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite" // 纯 Go 驱动，无需 cgo

	"monarch/internal/config"
	"monarch/internal/dbutil"
)

const (
	// 跨进程写锁等待上限；超出后返回 SQLITE_BUSY 并由 retryWrite 退避重试。
	busyTimeoutMS = 10000
	// 写事务重试次数与退避基数。
	writeRetries = 5
)

var (
	readPool  *sql.DB
	writePool *sql.DB
	dbFile    string
)

// File 返回当前数据库文件的绝对路径（空表示尚未初始化）。
func File() string {
	return dbFile
}

// Init 打开数据库文件、应用 pragma 并执行幂等建表脚本。
func Init(conf config.DbConfig) {
	abs, err := filepath.Abs(conf.File)
	if err != nil {
		log.Fatalf("解析数据库路径失败: %v", err)
	}
	if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
		log.Fatalf("创建数据库目录失败: %v", err)
	}
	dbFile = abs

	base := fmt.Sprintf("file:%s?_pragma=busy_timeout(%d)&_pragma=journal_mode(WAL)"+
		"&_pragma=synchronous(NORMAL)&_pragma=foreign_keys(ON)&_pragma=temp_store(MEMORY)"+
		"&_pragma=cache_size(-65536)", filepath.ToSlash(abs), busyTimeoutMS)

	if writePool, err = sql.Open("sqlite", base+"&_txlock=immediate"); err != nil {
		log.Fatalf("打开数据库（写）失败: %v", err)
	}
	writePool.SetMaxOpenConns(1)
	writePool.SetMaxIdleConns(1)
	writePool.SetConnMaxLifetime(0)

	if readPool, err = sql.Open("sqlite", base); err != nil {
		log.Fatalf("打开数据库（读）失败: %v", err)
	}
	readPool.SetMaxOpenConns(8)
	readPool.SetMaxIdleConns(4)
	readPool.SetConnMaxLifetime(0)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := writePool.PingContext(ctx); err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}

	if err := applySchema(ctx, conf.SchemaFile); err != nil {
		log.Fatalf("初始化数据库结构失败: %v", err)
	}
	if err := ensureColumns(ctx); err != nil {
		log.Fatalf("数据库列迁移失败: %v", err)
	}

	log.Printf("SQLite 数据库就绪: %s", abs)
}

// applySchema 执行幂等建表脚本（与 references/db/sqlite.sql 同源）。
func applySchema(ctx context.Context, schemaFile string) error {
	raw, err := os.ReadFile(schemaFile)
	if err != nil {
		return fmt.Errorf("读取建表脚本 %s 失败: %w", schemaFile, err)
	}
	if _, err := writePool.ExecContext(ctx, string(raw)); err != nil {
		return fmt.Errorf("执行建表脚本失败: %w", err)
	}
	return nil
}

// Close 关闭连接池。
func Close() {
	if writePool != nil {
		_ = writePool.Close()
		writePool = nil
	}
	if readPool != nil {
		_ = readPool.Close()
		readPool = nil
		log.Println("数据库连接已关闭")
	}
}

// Read 返回读连接池（WAL 下可并发读）。
func Read() *sql.DB {
	return readPool
}

// Ping 探测数据库可用性。
func Ping(ctx context.Context) error {
	if writePool == nil {
		return fmt.Errorf("数据库未初始化")
	}
	return writePool.PingContext(ctx)
}

// GetDefaultCtx 返回默认超时（5s）的上下文，适用于单条/少量语句的查询。
func GetDefaultCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 5*time.Second)
}

// GetLongCtx 返回长超时（5min）的上下文，适用于批量写入与全量替换类操作。
func GetLongCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 5*time.Minute)
}

// Exec 执行单条写语句，遇写锁竞争自动退避重试。
func Exec(ctx context.Context, query string, args ...any) (sql.Result, error) {
	var res sql.Result
	err := retryWrite(ctx, func() error {
		var execErr error
		res, execErr = writePool.ExecContext(ctx, query, args...)
		return execErr
	})
	return res, err
}

// Tx 在写事务内执行 fn；失败自动回滚，锁竞争整体重试。
func Tx(ctx context.Context, fn func(tx *sql.Tx) error) error {
	return retryWrite(ctx, func() error {
		tx, err := writePool.BeginTx(ctx, nil)
		if err != nil {
			return err
		}
		defer tx.Rollback() //nolint:errcheck // 提交成功后回滚为无操作
		if err := fn(tx); err != nil {
			return err
		}
		return tx.Commit()
	})
}

// retryWrite 退避重试写锁竞争。
func retryWrite(ctx context.Context, fn func() error) error {
	var err error
	for attempt := 0; attempt < writeRetries; attempt++ {
		if err = fn(); err == nil || !dbutil.IsBusy(err) {
			return err
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(time.Duration(20*(attempt+1)) * time.Millisecond):
		}
	}
	return err
}
