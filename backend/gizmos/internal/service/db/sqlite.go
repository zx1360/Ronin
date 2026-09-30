// 数据库连接（单文件 SQLite）
//
// 与 Monarch 共用同一个数据库文件与表结构（结构由 Monarch 启动时执行
// references/db/sqlite.sql 建立）。gizmos 是批处理 CLI：写入走单连接池
// （`_txlock=immediate`），读取走可并发的连接池。
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

	"gizmos/internal/service/config"
)

const busyTimeoutMS = 10000

var (
	readPool  *sql.DB
	writePool *sql.DB
)

// Init 打开数据库文件并应用 pragma。
func Init(conf config.DbConfig) {
	abs, err := filepath.Abs(conf.File)
	if err != nil {
		log.Fatalf("解析数据库路径失败: %v", err)
	}
	if _, statErr := os.Stat(abs); statErr != nil {
		log.Fatalf("数据库文件不存在: %s（请先启动一次 Monarch 以初始化）", abs)
	}

	base := fmt.Sprintf("file:%s?_pragma=busy_timeout(%d)&_pragma=journal_mode(WAL)"+
		"&_pragma=synchronous(NORMAL)&_pragma=foreign_keys(ON)&_pragma=temp_store(MEMORY)"+
		"&_pragma=cache_size(-65536)", filepath.ToSlash(abs), busyTimeoutMS)

	if writePool, err = sql.Open("sqlite", base+"&_txlock=immediate"); err != nil {
		log.Fatalf("打开数据库（写）失败: %v", err)
	}
	writePool.SetMaxOpenConns(1)

	if readPool, err = sql.Open("sqlite", base); err != nil {
		log.Fatalf("打开数据库（读）失败: %v", err)
	}
	readPool.SetMaxOpenConns(8)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := writePool.PingContext(ctx); err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}
	log.Printf("SQLite 数据库就绪: %s", abs)
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
	}
}

// Read 返回读连接池。
func Read() *sql.DB { return readPool }

// Write 返回写连接池（固定单连接）。
func Write() *sql.DB { return writePool }

// GetDefaultCtx 获得默认超时的上下文。
func GetDefaultCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 5*time.Second)
}

// GetLongCtx 获得长超时的上下文，用以批量插入。
func GetLongCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 10*time.Minute)
}
