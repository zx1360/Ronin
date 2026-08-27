package config

import (
	"fmt"
	"os"
	"strings"

	"github.com/joho/godotenv"
)

// 应用配置数据类
type AppConfig struct {
	StaticDir  string
	GalleryDir string
	ComicDir   string
}

// 网络配置
type NetConfig struct {
	LocalPort      string
	LocalDebugPort string
}

// 数据库配置
type DbConfig struct {
	DbIP       string
	DbPort     string
	DbUser     string
	DbPassword string
	DbName     string
}

// comix 爬虫集成配置（子进程调用 python -m comix.cli）
type ComixConfig struct {
	Python string // python 可执行文件（默认 "python"）
	Root   string // comix 项目根目录（依赖 .env 与 util 包，必须设置）
}

// 运行模式
var IsLocalMode bool

// 向外暴露数据对象
var (
	AppConf AppConfig
	NetConf NetConfig
	DbConf  DbConfig
	ComixConf ComixConfig
)

// 配置加载
func Load() error {
	// 尝试从 .env 文件加载环境变量（文件不存在时不报错）
	_ = godotenv.Load()

	// 应用配置
	AppConf.StaticDir = os.Getenv("STATIC_DIR")
	AppConf.GalleryDir = os.Getenv("GALLERY_DIR")
	AppConf.ComicDir = os.Getenv("COMIC_DIR")

	// 网络配置
	NetConf.LocalPort = os.Getenv("LOCAL_PORT")
	NetConf.LocalDebugPort = os.Getenv("LOCAL_DEBUG_PORT")

	// 数据库连接配置
	DbConf.DbIP = os.Getenv("DB_IP")
	DbConf.DbPort = os.Getenv("DB_PORT")
	DbConf.DbUser = os.Getenv("DB_USER")
	DbConf.DbPassword = os.Getenv("DB_PASSWORD")
	DbConf.DbName = os.Getenv("DB_NAME")

	// comix 爬虫集成配置（可选；未配置时相关 API 返回明确错误）
	ComixConf.Python = os.Getenv("COMIX_PYTHON")
	if strings.TrimSpace(ComixConf.Python) == "" {
		ComixConf.Python = "python"
	}
	ComixConf.Root = os.Getenv("COMIX_ROOT")

	return Validate()
}

// Validate 校验必要配置项，返回缺失项列表
func Validate() error {
	required := map[string]string{
		"STATIC_DIR":  AppConf.StaticDir,
		"GALLERY_DIR": AppConf.GalleryDir,
		"COMIC_DIR":   AppConf.ComicDir,
		"LOCAL_PORT":  NetConf.LocalPort,
		"DB_IP":       DbConf.DbIP,
		"DB_PORT":     DbConf.DbPort,
		"DB_USER":     DbConf.DbUser,
		"DB_PASSWORD": DbConf.DbPassword,
		"DB_NAME":     DbConf.DbName,
	}

	var missing []string
	for key, val := range required {
		if strings.TrimSpace(val) == "" {
			missing = append(missing, key)
		}
	}

	// LOCAL_DEBUG_PORT 仅在 local 模式需要
	if IsLocalMode && strings.TrimSpace(NetConf.LocalDebugPort) == "" {
		missing = append(missing, "LOCAL_DEBUG_PORT")
	}

	if len(missing) > 0 {
		return fmt.Errorf("缺少必要的环境变量: %s", strings.Join(missing, ", "))
	}

	return nil
}
