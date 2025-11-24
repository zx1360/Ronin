package router

import (
	"monarch/internal/config"
	"monarch/internal/handler/data"
	"monarch/internal/handler/util"
	"net/http"

	"github.com/gin-contrib/static"
	"github.com/gin-gonic/gin"
)

func SetupRouter() *gin.Engine {
	// gin.SetMode(gin.ReleaseMode) // 切换到发布模式	(终端打印信息更少)
	r := gin.Default()
	// TODO: 加入Nginx后, 配置信任的代理地址,
	r.SetTrustedProxies([]string{"127.0.0.1"}) // 信任本地代理

	// 静态资源响应
	r.Static("/static", config.AppConf.StaticDir)
	r.Use(static.Serve("/static/", static.LocalFile(config.AppConf.StaticDir, false)))

	// 前端路由	资源/页面
	r.GET("/", func(ctx *gin.Context) {
		ctx.JSON(http.StatusOK, gin.H{
			"message": "Gin",
		})
	})

	// API路由, 数据/操作
	api := r.Group("/api")
	{
		// 用户数据相关
		userDataGroup := api.Group("/user-data")
		{
			userDataGroup.GET("/sync/:module_name", data.SyncData)
			userDataGroup.POST("/backup/:module_name", data.BackupData)
		}

		// 工具api
		api.GET("/test", util.Test)
	}

	return r
}
