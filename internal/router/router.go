package router

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/handler/comic_handler"
	"monarch/internal/handler/data_handler"
	"monarch/internal/handler/util_handler"
)

func SetupRouter() *gin.Engine {
	// gin.SetMode(gin.ReleaseMode) // 切换到发布模式	(终端打印信息更少)
	r := gin.Default()
	// TODO: 加入Nginx后, 配置信任的代理地址,
	r.SetTrustedProxies([]string{"127.0.0.1"}) // 信任本地代理

	// 静态资源响应
	r.Static("/static", config.AppConf.StaticDir)
	// r.Use(static.Serve("/static/", static.LocalFile(config.AppConf.StaticDir, false)))

	// 前端路由	资源/页面
	r.GET("/", func(ctx *gin.Context) {
		ctx.JSON(http.StatusOK, gin.H{
			"message": "假设是个index.html页面",
		})
	})

	// API路由, 数据/操作
	api := r.Group("/api")
	{
		// 用户数据相关
		userDataGroup := api.Group("/user-data")
		{
			userDataGroup.GET("/sync/:module", data_handler.SyncHandler)
			userDataGroup.POST("/backup/:module", data_handler.BackupHandler)
		}

		// 漫画请求相关
		comicGroup := api.Group("/comic")
		{
			// 漫画元数据	TODO: 客户端写个页面展示当前漫画资源量.
			comicGroup.GET("/meta-info", comic_handler.FetchComicMetadata)
			// 下载整本漫画到本地
			comicGroup.GET("/download/:comic-id", comic_handler.DownloadComic)
			// 在线阅读	(也许后面加入"用户模块"补全阅读进度持久化记录等功能)
			comicGroup.GET("/comic-info", comic_handler.FetchAllComicInfos)
			comicGroup.GET("/comic-info/:comic-id", comic_handler.FetchChaptersWithComicId)
			comicGroup.GET("/chapter-info/:chapter-id", comic_handler.FetchImagesWithChapterId)
		}

		// 媒体浏览相关
		tuntunGroup := api.Group("/tuntun")
		{
			tuntunGroup.GET("/meta-info")
			// 获取批量媒体文件
			tuntunGroup.GET("/fetch-batch")
			// 提交操作
			tuntunGroup.POST("/send-ops")
		}

		// 工具api
		api.GET("/test", util_handler.Test)
	}

	return r
}
