package router

import (
	"net/http"
	"path/filepath"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/handler/comic_handler"
	"monarch/internal/handler/data_handler"
	"monarch/internal/handler/gallery_handler"
	"monarch/internal/handler/util_handler"
)

func SetupRouter() *gin.Engine {
	// 设置频控日志路径为 static 目录
	util_handler.SetBanLogPath(filepath.Join(config.AppConf.StaticDir, "logs.txt"))

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

	// 选择性鉴权中间件：漫画相关 + 测试接口免验证，其余均需 X-API-Key
	if !config.IsLocalMode {
		r.Use(selectiveAuth())
	}

	// 静态资源响应
	r.Static("/static", config.AppConf.StaticDir)

	// 前端路由	资源/页面
	r.GET("/", func(ctx *gin.Context) {
		ctx.JSON(http.StatusOK, gin.H{
			"message": "假设是个index.html页面",
		})
	})

	// Immich 代理路由
	registerImmichProxyRoutes(r)

	// API路由, 数据/操作
	api := r.Group("/API")
	{
		// 用户数据相关
		userDataGroup := api.Group("/user-data")
		{
			userDataGroup.GET("/sync/:module", data_handler.SyncHandler)
			userDataGroup.POST("/backup/:module", data_handler.BackupHandler)
			userDataGroup.POST("/check-images/:module", data_handler.CheckImagesHandler)
		}

		// 漫画请求相关（免鉴权，由 selectiveAuth 放行）
		comicGroup := api.Group("/comic")
		{
			// 漫画元数据
			comicGroup.GET("/meta-info", comic_handler.FetchComicMetadata)
			// 漫画列表 & 详情
			comicGroup.GET("/comic-info", comic_handler.FetchAllComicInfos)
			comicGroup.GET("/comic-info/:comic-id", comic_handler.FetchChaptersWithComicId)
			comicGroup.PUT("/comic-info/:comic-id", comic_handler.UpdateComic)
			comicGroup.DELETE("/comic-info/:comic-id", comic_handler.DeleteComic)
			// 章节详情
			comicGroup.GET("/chapter-info/:chapter-id", comic_handler.FetchImagesWithChapterId)
			// 下载整本漫画到本地
			comicGroup.GET("/download/:comic-id", comic_handler.DownloadComic)
			// 同步已读状态
			comicGroup.POST("/sync-readed", comic_handler.SyncReadedStatus)
		}

		// 媒体浏览相关
		galleryGroup := api.Group("/gallery")
		{
			// 获取一批次的媒体资产 + 全量标签 + 对应的标签关联
			galleryGroup.GET("/batch", gallery_handler.FetchBatch)
			// 获取完整标签树
			galleryGroup.GET("/tags", gallery_handler.FetchAllTags)
			// 获取服务端媒体库总览统计
			galleryGroup.GET("/overview", gallery_handler.FetchOverview)
			// 下载文件接口
			galleryGroup.GET("/:id/:type", gallery_handler.FetchMediaAsset)
			// 客户端推送数据
			galleryGroup.POST("/push", gallery_handler.Push)
		}

		// 工具api
		api.GET("/test", util_handler.Test) // 免鉴权
		api.GET("/ops/overview", util_handler.SystemOverview)
	}

	return r
}
