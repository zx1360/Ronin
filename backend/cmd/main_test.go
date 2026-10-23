package main

import (
	"os"
	"path/filepath"
	"testing"

	"monarch/internal/service/db"
)

func TestStartupFailureClosesDatabase(t *testing.T) {
	backend, err := filepath.Abs("..")
	if err != nil {
		t.Fatal(err)
	}
	root := t.TempDir()
	t.Chdir(root)
	for key, value := range map[string]string{
		"STATIC_DIR": filepath.Join(root, "static"), "GALLERY_DIR": filepath.Join(root, "gallery"),
		"DB_FILE": filepath.Join(root, "test.db"), "DB_SCHEMA_FILE": filepath.Join(backend, "references/db/sqlite.sql"),
		"LOCAL_PORT": "0", "LOCAL_HTTP_PORT": "0", "AI_ENABLED": "false",
	} {
		t.Setenv(key, value)
	}
	data := filepath.Join(root, "static/data")
	if err := os.MkdirAll(data, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(data, "ops_web.json"), []byte("invalid"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := run(t.Context()); err == nil {
		t.Fatal("启动错误未返回")
	}
	if db.Read() != nil {
		t.Fatal("启动失败后数据库未关闭")
	}
}
