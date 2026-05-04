package config

import (
	"os"

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

// 运行模式
var IsLocalMode bool

// 向外暴露数据对象
var (
	AppConf AppConfig
	NetConf NetConfig
	DbConf  DbConfig
)

// 配置加载
func Load() error {
	// 尝试从 .env 文件加载环境变量
	godotenv.Load()

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

	return nil
}
