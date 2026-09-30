package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/joho/godotenv"
)

// schemaMarker 用于定位 Ronin 后端根目录的标志文件（相对该根目录）。
const schemaMarker = "references/db/sqlite.sql"

// DbConfig SQLite 单文件数据库配置（与 Monarch 共用同一文件）。
type DbConfig struct {
	File string
}

var (
	DbConf DbConfig
	// BackendRoot Ronin 后端根目录（backend/），用于解析相对路径与 .env。
	BackendRoot string
)

func init() {
	BackendRoot = findBackendRoot()
	// .env 在 backend/ 下；godotenv 不覆盖已存在的环境变量（Monarch 调用时已注入）。
	_ = godotenv.Load(filepath.Join(BackendRoot, ".env"))

	DbConf.File = strings.TrimSpace(os.Getenv("DB_FILE"))
	if DbConf.File == "" {
		DbConf.File = filepath.Join("data", "monarch.db")
	}
	if !filepath.IsAbs(DbConf.File) {
		DbConf.File = filepath.Join(BackendRoot, DbConf.File)
	}
}

// findBackendRoot 定位 backend/ 目录。
//
// Ops 桌面端以"可执行文件所在目录"为工作目录启动进程（gallery.exe 在
// backend/gizmos/ 下），因此不能只按 CWD 找配置；这里按标志文件在
// 若干候选目录中挑选，保证无论从哪启动都能找到数据库与 .env。
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
	// 兜底：用当前工作目录，由后续的数据库文件检查给出明确报错。
	cwd, _ := os.Getwd()
	return cwd
}

// Validate 校验必要配置项，返回缺失项列表
func Validate() error {
	if strings.TrimSpace(DbConf.File) == "" {
		return fmt.Errorf("缺少必要的环境变量: DB_FILE")
	}
	return nil
}
