package config

import (
	"errors"
	"os"
)

// Validate 验证必要的配置是否存在
func Validate() error {
	var missing []string

	// 检查网络配置
	if NetConf.LocalPort == "" {
		missing = append(missing, "LOCAL_PORT")
	}

	// 检查静态目录
	if AppConf.StaticDir == "" {
		missing = append(missing, "STATIC_DIR")
	}

	// 检查数据库配置
	if DbConf.DbIP == "" {
		missing = append(missing, "DB_IP")
	}
	if DbConf.DbPort == "" {
		missing = append(missing, "DB_PORT")
	}
	if DbConf.DbUser == "" {
		missing = append(missing, "DB_USER")
	}
	if DbConf.DbPassword == "" {
		missing = append(missing, "DB_PASSWORD")
	}
	if DbConf.DbName == "" {
		missing = append(missing, "DB_NAME")
	}

	if len(missing) > 0 {
		return errors.New("缺少必要的环境变量: " + joinStrings(missing, ", "))
	}

	return nil
}

// joinStrings 简单的字符串连接
func joinStrings(strs []string, sep string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for i := 1; i < len(strs); i++ {
		result += sep + strs[i]
	}
	return result
}

// IsProduction 判断是否为生产环境
func IsProduction() bool {
	env := os.Getenv("GIN_MODE")
	return env == "release"
}
