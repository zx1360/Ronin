package main

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/joho/godotenv"
)

const schemaMarker = "references/db/sqlite.sql"

func galleryDBFile() string {
	if file := strings.TrimSpace(os.Getenv("DB_FILE")); filepath.IsAbs(file) {
		return file
	}
	root := findBackendRoot()
	_ = godotenv.Load(filepath.Join(root, ".env"))
	file := strings.TrimSpace(os.Getenv("DB_FILE"))
	if file == "" {
		file = filepath.Join("data", "monarch.db")
	}
	if filepath.IsAbs(file) {
		return file
	}
	return filepath.Join(root, file)
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
