package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/joho/godotenv"
)

// DbConfig 数据库配置：单文件 SQLite（与 monarch 共用同一库）。
type DbConfig struct {
	DbPath string
}

var (
	DbConf DbConfig
)

func init() {
	_ = godotenv.Load()

	DbConf.DbPath = resolveDbPath()
}

// resolveDbPath 解析 SQLite 库路径：DB_PATH 优先（相对当前工作目录）；
// 否则优先 backend/data/monarch.db，回退 ../data/monarch.db（gallery CLI 在 gizmos/ 下独立运行）。
func resolveDbPath() string {
	if path := strings.TrimSpace(os.Getenv("DB_PATH")); path != "" {
		return path
	}
	for _, candidate := range []string{
		filepath.Join("data", "monarch.db"),
		filepath.Join("..", "data", "monarch.db"),
	} {
		if fi, err := os.Stat(candidate); err == nil && !fi.IsDir() {
			return candidate
		}
	}
	return filepath.Join("data", "monarch.db")
}

// Validate 校验必要配置项：数据库文件必须已存在，
// gallery CLI 不得在自身目录旁静默新建空库。
func Validate() error {
	path := strings.TrimSpace(DbConf.DbPath)
	if path == "" {
		return fmt.Errorf("DB_PATH 未配置")
	}
	fi, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("数据库文件不可用: %s (%v)", path, err)
	}
	if fi.IsDir() {
		return fmt.Errorf("数据库路径是目录: %s", path)
	}
	return nil
}
