package config

import (
	"fmt"
	"os"
	"strings"

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
	_ = godotenv.Load()

	DbConf.DbIP = os.Getenv("DB_IP")
	DbConf.DbPort = os.Getenv("DB_PORT")
	DbConf.DbUser = os.Getenv("DB_USER")
	DbConf.DbPassword = os.Getenv("DB_PASSWORD")
	DbConf.DbName = os.Getenv("DB_NAME")
}

// Validate 校验必要配置项，返回缺失项列表
func Validate() error {
	required := map[string]string{
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

	if len(missing) > 0 {
		return fmt.Errorf("缺少必要的环境变量: %s", strings.Join(missing, ", "))
	}

	return nil
}
