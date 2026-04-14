package router

import (
	"net/http"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/handler/comic_handler"
	"monarch/internal/handler/data_handler"
	"monarch/internal/handler/gallery_handler"
	"monarch/internal/handler/util_handler"
)

func SetupRouter() *gin.Engine {
	// gin.SetMode(gin.ReleaseMode) // 切换到发布模式	(终端打印信息更少)
	r := gin.Default()

	// CORS 跨域配置（HTTPS自签证书场景）
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "X-API-Key", "Authorization"},
		ExposeHeaders:    []string{"Content-Length", "Content-Disposition"},
		AllowCredentials: false,
	}))

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
	if !config.IsLocalMode {
		api.Use(util_handler.APIKeyAuth())
	}
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
		galleryGroup := api.Group("/gallery")
		{
			// 获取一批次的媒体资产 + 全量标签 + 对应的标签关联
			galleryGroup.GET("/batch", gallery_handler.FetchBatch)
			// 获取完整标签树
			galleryGroup.GET("/tags", gallery_handler.FetchAllTags)
			// 下载文件接口
			galleryGroup.GET("/:id/:type", gallery_handler.FetchMediaAsset)
			// 客户端推送数据
			galleryGroup.POST("/push", gallery_handler.Push)
		}

		// 库存页相关
		_ = api.Group("/library")
		{

		}

		// 工具api
		api.GET("/test", util_handler.Test)
		api.GET("/ops/overview", util_handler.SystemOverview)
	}

	return r
}
