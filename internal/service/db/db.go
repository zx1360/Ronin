// 数据库连接
package db

import (
	"context"
	"fmt"
	"log"
	"monarch/internal/config"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Pool 全局 PostgreSQL 连接池
var Pool *pgxpool.Pool

// Init 初始化数据库连接池
func Init(conf config.DbConfig) {
	// TODO: sslmode改为required, 使用CA证书.
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=prefer",
		conf.DbIP,
		conf.DbPort,
		conf.DbUser,
		conf.DbPassword,
		conf.DbName,
	)

	// 配置连接池（可选：自定义连接池参数，提升可控性）
	poolConfig, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		log.Fatalf("解析数据库配置失败: %v", err)
	}
	// 可选：设置连接池参数（根据业务调整）
	poolConfig.MaxConns = 10                               // 最大连接数
	poolConfig.MinConns = 2                                // 最小空闲连接
	poolConfig.MaxConnLifetime = 1 * time.Hour             // 连接最大存活时间（避免长期空闲连接失效）
	poolConfig.MaxConnIdleTime = 30 * time.Minute          // 连接最大空闲时间
	poolConfig.ConnConfig.ConnectTimeout = 5 * time.Second // 连接超时

	// 初始化连接池
	Pool, err = pgxpool.NewWithConfig(context.Background(), poolConfig)
	if err != nil {
		log.Fatalf("创建数据库连接池失败: %v", err)
	}

	// 验证连接
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err = Pool.Ping(ctx); err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}

	log.Println("数据库连接池初始化成功")
}

// Close 关闭连接池
func Close() {
	if Pool != nil {
		Pool.Close()
		log.Println("数据库连接池已关闭")
	}
}

// GetPool 获取连接池实例（非 nil 保障）
func GetPool() *pgxpool.Pool {
	return Pool
}

// 获得默认超时的上下文
func GetDefailtCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 5*time.Second)
}
