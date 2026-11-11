package db

import (
	"database/sql"
	"os"
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

func TestSharedInitializationPreservesLegacyData(t *testing.T) {
	conf := config.DbConfig{File: filepath.Join(t.TempDir(), "legacy.db"), SchemaFile: "../../../references/db/sqlite.sql"}
	if err := Init(conf); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(Close)
	if _, err := Exec(t.Context(), `INSERT INTO essay_articles(id,date,content) VALUES('kept','2026-01-01','原文'); PRAGMA user_version=42;`); err != nil {
		t.Fatal(err)
	}
	for _, column := range addedColumns {
		if _, err := Exec(t.Context(), "ALTER TABLE "+column.table+" DROP COLUMN "+column.name); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := Exec(t.Context(), `CREATE TRIGGER trg_essay_articles_updated_at AFTER UPDATE ON essay_articles BEGIN SELECT 1; END;`); err != nil {
		t.Fatal(err)
	}
	Close()
	for _, initialize := range []func(config.DbConfig) error{InitGallery, Init} {
		if err := initialize(conf); err != nil {
			t.Fatal(err)
		}
		for _, column := range addedColumns {
			var count int
			if err := Read().QueryRowContext(t.Context(), "SELECT count(*) FROM pragma_table_info(?) WHERE name=?", column.table, column.name).Scan(&count); err != nil || count != 1 {
				t.Fatalf("缺少 %s.%s: %v", column.table, column.name, err)
			}
		}
		var content string
		var version, triggers int
		if err := Read().QueryRowContext(t.Context(), "SELECT content FROM essay_articles WHERE id='kept'").Scan(&content); err != nil || content != "原文" {
			t.Fatalf("原文丢失: %q %v", content, err)
		}
		if err := Read().QueryRowContext(t.Context(), "PRAGMA user_version").Scan(&version); err != nil || version != 42 {
			t.Fatalf("不得重置库版本: %d %v", version, err)
		}
		if err := Read().QueryRowContext(t.Context(), "SELECT count(*) FROM sqlite_master WHERE name='trg_essay_articles_updated_at'").Scan(&triggers); err != nil || triggers != 0 {
			t.Fatalf("旧触发器未移除: %v", err)
		}
		Close()
	}
}

func TestInitializationRollsBackSchemaAndColumns(t *testing.T) {
	dir := t.TempDir()
	conf := config.DbConfig{File: filepath.Join(dir, "rollback.db"), SchemaFile: "../../../references/db/sqlite.sql"}
	if err := Init(conf); err != nil {
		t.Fatal(err)
	}
	if _, err := Exec(t.Context(), "ALTER TABLE essay_articles DROP COLUMN title"); err != nil {
		t.Fatal(err)
	}
	Close()
	conf.SchemaFile = filepath.Join(dir, "sqlite.sql")
	if err := os.WriteFile(conf.SchemaFile, []byte("CREATE TABLE should_rollback(id TEXT);"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := Init(conf); err == nil {
		t.Fatal("缺少漫画 schema 应失败")
	}
	raw, err := sql.Open("sqlite", conf.File)
	if err != nil {
		t.Fatal(err)
	}
	defer raw.Close()
	var count int
	if err := raw.QueryRow("SELECT count(*) FROM sqlite_master WHERE name='should_rollback'").Scan(&count); err != nil || count != 0 {
		t.Fatalf("建表未回滚: %v", err)
	}
	if err := raw.QueryRow("SELECT count(*) FROM pragma_table_info('essay_articles') WHERE name='title'").Scan(&count); err != nil || count != 0 {
		t.Fatalf("补列未回滚: %v", err)
	}
}
