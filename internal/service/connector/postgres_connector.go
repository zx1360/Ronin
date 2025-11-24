// db/db.go
package connector

import (
	"context"
	"fmt"
	"log"
	"monarch/internal/config"
	"time"

	"github.com/jackc/pgx/v4/pgxpool"
)

// client 是一个包级别的变量，用于存储 MongoDB 客户端实例
var Pool *pgxpool.Pool

// 初始化 MongoDB 连接
func InitDb(conf config.DbConfig) {
	connStr := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		conf.DbIP,
		conf.DbPort,
		conf.DbUser,
		conf.DbPassword,
		conf.DbName,
	)
	var err error
	if Pool, err = pgxpool.Connect(context.Background(), connStr); err != nil {
		log.Fatalf("无法连接到数据库: %v", err)
	}
	// 尝试 ping 数据库以确保连接有效
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := Pool.Ping(ctx); err != nil {
		log.Fatalf("无法连接到数据库: %v", err)
	}

	log.Println("数据库连接成功！")
}

func CloseDb() {
	if Pool != nil {
		Pool.Close()
	}
}

func GetClient() *pgxpool.Pool {
	if Pool != nil {
		return Pool
	}
	return nil
}
