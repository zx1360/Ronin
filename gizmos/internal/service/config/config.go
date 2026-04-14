package config

import (
	"os"

	"github.com/joho/godotenv"
)

// 数据库配置
type DbConfig struct {
	DbIP       string
	DbPort     string
	DbUser     string
	DbPassword string
	DbName     string
}

var (
	DbConf DbConfig
)

func init() {
	godotenv.Load()

	// 数据库连接配置
	DbConf.DbIP = os.Getenv("DB_IP")
	DbConf.DbPort = os.Getenv("DB_PORT")
	DbConf.DbUser = os.Getenv("DB_USER")
	DbConf.DbPassword = os.Getenv("DB_PASSWORD")
	DbConf.DbName = os.Getenv("DB_NAME")
}
