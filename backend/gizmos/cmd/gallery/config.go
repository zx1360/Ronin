package main

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/joho/godotenv"
	"monarch/internal/config"
)

const schemaMarker = "references/db/sqlite.sql"

func galleryDBConfig() config.DbConfig {
	root := findBackendRoot()
	_ = godotenv.Load(filepath.Join(root, ".env"))
	resolve := func(key, fallback string) string {
		path := strings.TrimSpace(os.Getenv(key))
		if path == "" {
			path = fallback
		}
		if filepath.IsAbs(path) {
			return path
		}
		return filepath.Join(root, path)
	}
	return config.DbConfig{
		File:       resolve("DB_FILE", filepath.Join("data", "monarch.db")),
		SchemaFile: resolve("DB_SCHEMA_FILE", schemaMarker),
	}
}

func findBackendRoot() string {
	candidates := []string{}
	if exe, err := os.Executable(); err == nil {
		dir := filepath.Dir(exe)
		candidates = append(candidates, dir, filepath.Dir(dir))
	}
	if cwd, err := os.Getwd(); err == nil {
		candidates = append(candidates, cwd, filepath.Dir(cwd))
	}
	for _, dir := range candidates {
		if _, err := os.Stat(filepath.Join(dir, schemaMarker)); err == nil {
			if abs, err := filepath.Abs(dir); err == nil {
				return abs
			}
			return dir
		}
	}
	cwd, _ := os.Getwd()
	return cwd
}
