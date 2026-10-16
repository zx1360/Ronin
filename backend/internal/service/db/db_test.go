package db

import (
	"database/sql"
	"path/filepath"
	"testing"

	"monarch/internal/config"
)

func TestConcurrentReadConnectionsRetainOneIdle(t *testing.T) {
	if err := Init(config.DbConfig{File: filepath.Join(t.TempDir(), "db.db"), SchemaFile: "../../../references/db/sqlite.sql"}); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(Close)
	connections := make([]*sql.Conn, 0, 8)
	defer func() {
		for _, conn := range connections {
			conn.Close()
		}
	}()
	for i := 0; i < 8; i++ {
		conn, err := Read().Conn(t.Context())
		if err != nil {
			t.Fatal(err)
		}
		connections = append(connections, conn)
		var cache, fk int
		if err := conn.QueryRowContext(t.Context(), "PRAGMA cache_size").Scan(&cache); err != nil {
			t.Fatal(err)
		}
		if err := conn.QueryRowContext(t.Context(), "PRAGMA foreign_keys").Scan(&fk); err != nil {
			t.Fatal(err)
		}
		if cache != -pageCacheKiB || fk != 1 {
			t.Fatalf("新连接未应用配置: cache=%d foreign_keys=%d", cache, fk)
		}
	}
	if stats := Read().Stats(); stats.InUse != 8 {
		t.Fatalf("并发读取能力被限制: %+v", stats)
	}
	for _, conn := range connections {
		conn.Close()
	}
	if stats := Read().Stats(); stats.Idle != 1 || stats.OpenConnections != 1 {
		t.Fatalf("并发读取后连接没有回收: %+v", stats)
	}
}
