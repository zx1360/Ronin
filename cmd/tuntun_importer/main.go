package main

import (
	"gizmos/internal/service/config"
	"gizmos/internal/service/db"
)

const (
	sourceDir = "" // 源文件目录
	destDir   = "" // 目标文件目录
)

func main() {
	// 1. 连接数据库
	db.Init(config.DbConf)
	defer db.Close()

}
