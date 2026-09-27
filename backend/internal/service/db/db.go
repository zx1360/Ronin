// Package db 提供 Monarch 的单文件 SQLite 数据访问层。
//
// 并发模型（单写者 + WAL）：
//   - 写池上限 1 条连接，所有写入在进程内天然串行，不需要 SQLite 级写锁竞争；
//     连接带 `_txlock=immediate`，事务一开始就取写锁，避免"读事务升级为写"的死锁。
//   - 读池独立，WAL 下读不阻塞写；写事务也不会被读拖住。
//   - 外部写者（comix CLI 子进程）造成的 SQLITE_BUSY 由 busy_timeout 兜底，
//     事务层再包一层有限重试。
//
// 时间列统一为 TEXT，格式见 model.TimeFormat（UTC、毫秒、定宽，可按字典序比较）。
package db

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	sqlite "modernc.org/sqlite"
)

// 运行期连接数上限：写池固定 1（单写者），读池按个人机规模给足并行查询。
const (
	writeConns = 1
	readConns  = 4
	// busyTimeoutMS 是 SQLite 自身的等锁时间，覆盖 comix CLI 等外部写者的短事务。
	busyTimeoutMS = 10000
	// 事务重试：仅针对 SQLITE_BUSY/LOCKED，退避后重试。
	txRetries    = 6
	txRetryDelay = 40 * time.Millisecond
)

var (
	writeDB *sql.DB
	readDB  *sql.DB
	dbPath  string
)

// Open 打开（必要时创建）数据库文件并应用 schema。
func Open(path string) error {
	if strings.TrimSpace(path) == "" {
		return errors.New("数据库路径为空")
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return fmt.Errorf("解析数据库路径失败: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
		return fmt.Errorf("创建数据库目录失败: %w", err)
	}

	dsn := buildDSN(abs, true)
	writeDB, err = sql.Open("sqlite", dsn)
	if err != nil {
		return fmt.Errorf("打开写连接失败: %w", err)
	}
	writeDB.SetMaxOpenConns(writeConns)
	writeDB.SetMaxIdleConns(writeConns)
	writeDB.SetConnMaxLifetime(0)

	readDB, err = sql.Open("sqlite", buildDSN(abs, false))
	if err != nil {
		return fmt.Errorf("打开读连接失败: %w", err)
	}
	readDB.SetMaxOpenConns(readConns)
	readDB.SetMaxIdleConns(readConns)
	readDB.SetConnMaxLifetime(0)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := writeDB.PingContext(ctx); err != nil {
		return fmt.Errorf("数据库不可用: %w", err)
	}
	if err := ApplySchema(ctx, writeDB); err != nil {
		return fmt.Errorf("应用数据库结构失败: %w", err)
	}
	dbPath = abs
	log.Printf("SQLite 就绪: %s", abs)
	return nil
}

// buildDSN 生成 sqlite DSN。pragmas 必须随连接下发（除 journal_mode 外都是连接级的）。
func buildDSN(absPath string, writer bool) string {
	pragmas := []string{
		"journal_mode(WAL)",
		fmt.Sprintf("busy_timeout(%d)", busyTimeoutMS),
		"foreign_keys(1)",
		"synchronous(NORMAL)",
	}
	q := url.Values{}
	for _, p := range pragmas {
		q.Add("_pragma", p)
	}
	if writer {
		q.Set("_txlock", "immediate")
	}
	// Windows 路径走 file: URI 时必须用正斜杠，否则盘符会被当成 authority。
	return "file:" + filepath.ToSlash(absPath) + "?" + q.Encode()
}

// Close 关闭连接池。
func Close() {
	if readDB != nil {
		_ = readDB.Close()
	}
	if writeDB != nil {
		_ = writeDB.Close()
	}
	log.Println("SQLite 连接已关闭")
}

// R 返回读连接池（查询用）。
func R() *sql.DB { return readDB }

// W 返回写连接池（写入与事务用，上限 1 条连接）。
func W() *sql.DB { return writeDB }

// Path 返回当前数据库文件路径（未打开时为空）。
func Path() string { return dbPath }

// ChildEnv 返回传给子进程的环境变量：把 DB_PATH 固定为已打开的绝对路径。
//
// 必须这么做：子进程的启动目录由它自己决定（gallery CLI 在 gizmos/、comix 在
// gizmos/comix/），而 DB_PATH 默认是相对 .env 所在目录的相对路径——原样继承会让
// 子进程按自己的工作目录去解析，连到别的库或直接找不到文件。
func ChildEnv() []string {
	env := os.Environ()
	if dbPath == "" {
		return env
	}
	out := make([]string, 0, len(env)+1)
	for _, kv := range env {
		if strings.HasPrefix(kv, "DB_PATH=") {
			continue
		}
		out = append(out, kv)
	}
	return append(out, "DB_PATH="+dbPath)
}

// GetDefaultCtx 返回默认超时（5s）的上下文，适用于单条/少量语句。
func GetDefaultCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 5*time.Second)
}

// GetLongCtx 返回长超时（5min）的上下文，适用于批量写入与全量替换类操作。
func GetLongCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 5*time.Minute)
}

// Tx 在写池上执行一个事务；失败自动回滚，遇 SQLITE_BUSY/LOCKED 退避重试。
func Tx(ctx context.Context, fn func(tx *sql.Tx) error) error {
	var lastErr error
	for attempt := 0; attempt < txRetries; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(txRetryDelay * time.Duration(attempt)):
			}
		}
		tx, err := writeDB.BeginTx(ctx, nil)
		if err != nil {
			if IsBusy(err) {
				lastErr = err
				continue
			}
			return fmt.Errorf("开始事务失败: %w", err)
		}
		if err := fn(tx); err != nil {
			_ = tx.Rollback()
			if IsBusy(err) {
				lastErr = err
				continue
			}
			return err
		}
		if err := tx.Commit(); err != nil {
			// SQLite 的 COMMIT 可能返回 SQLITE_BUSY 而事务仍在进行中，
			// 因此重试前必须显式回滚，避免把未提交的写入带到下一次尝试。
			_ = tx.Rollback()
			if IsBusy(err) {
				lastErr = err
				continue
			}
			return fmt.Errorf("提交事务失败: %w", err)
		}
		return nil
	}
	return fmt.Errorf("数据库繁忙，重试 %d 次后仍失败: %w", txRetries, lastErr)
}

// ---------------------------------------------------------------------------
// SQLite 错误分类：modernc 的 *sqlite.Error.Code() 返回扩展结果码，
// 仓库层据此把唯一约束/外键冲突映射成对外的 409/400。
// ---------------------------------------------------------------------------

const (
	codeBusy       = 5    // SQLITE_BUSY
	codeLocked     = 6    // SQLITE_LOCKED
	codeUnique     = 2067 // SQLITE_CONSTRAINT_UNIQUE
	codePrimaryKey = 1555 // SQLITE_CONSTRAINT_PRIMARYKEY
	codeForeignKey = 787  // SQLITE_CONSTRAINT_FOREIGNKEY
	codeNotNull    = 1299 // SQLITE_CONSTRAINT_NOTNULL
)

func sqliteCode(err error) (int, bool) {
	var se *sqlite.Error
	if errors.As(err, &se) {
		return se.Code(), true
	}
	return 0, false
}

// IsBusy 判断是否为锁竞争导致的失败。
func IsBusy(err error) bool {
	code, ok := sqliteCode(err)
	if !ok {
		return false
	}
	return code == codeBusy || code == codeLocked ||
		code&0xff == codeBusy || code&0xff == codeLocked
}

// IsUniqueViolation 判断是否为唯一约束冲突（含主键冲突）。
func IsUniqueViolation(err error) bool {
	code, ok := sqliteCode(err)
	if !ok {
		return false
	}
	return code == codeUnique || code == codePrimaryKey
}

// IsForeignKeyViolation 判断是否为外键约束冲突。
func IsForeignKeyViolation(err error) bool {
	code, ok := sqliteCode(err)
	return ok && code == codeForeignKey
}
