package router

import (
	"net/http"
	"path/filepath"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/handler/comic_handler"
	"monarch/internal/handler/comix_handler"
	"monarch/internal/handler/data_handler"
	"monarch/internal/handler/gallery_handler"
	"monarch/internal/handler/util_handler"
)

// SetupRouter 构建全部路由与中间件。
func SetupRouter() *gin.Engine {
	// 封禁日志写在 static 目录下，随应用目录一起迁移/删除
	util_handler.SetBanLogPath(filepath.Join(config.AppConf.StaticDir, "logs.txt"))

	r := gin.Default()

	// CORS 跨域配置（HTTPS 自签证书场景）
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

	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"service": "monarch",
			"message": "Monarch HTTP 服务运行中",
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

		// comix 漫画爬虫管理（需鉴权；异步任务由服务端管理生命周期）
		comixGroup := api.Group("/comix")
		{
			// 配置与只读查询（同步）
			comixGroup.GET("/config", comix_handler.GetConfig)
			comixGroup.POST("/init", comix_handler.Init)
			comixGroup.GET("/sites", comix_handler.Sites)
			comixGroup.GET("/list", comix_handler.List)
			comixGroup.GET("/chapters/:comic-id", comix_handler.Chapters)
			// 爬虫操作（异步任务）
			comixGroup.POST("/download-url", comix_handler.DownloadURL)
			comixGroup.POST("/download", comix_handler.Download)
			comixGroup.POST("/update-check", comix_handler.UpdateCheck)
			comixGroup.POST("/delete", comix_handler.Delete)
			comixGroup.POST("/clean", comix_handler.Clean)
			// 任务生命周期
			comixGroup.GET("/tasks", comix_handler.ListTasks)
			comixGroup.GET("/tasks/:task-id", comix_handler.GetTask)
			comixGroup.POST("/tasks/:task-id/stop", comix_handler.StopTask)
		}

		// 媒体浏览相关
		galleryGroup := api.Group("/gallery")
		{
			// 标签树与标签写操作（服务端权威）
			galleryGroup.GET("/tags", gallery_handler.FetchAllTags)
			galleryGroup.POST("/tags", gallery_handler.CreateTag)
			galleryGroup.PUT("/tags/:id", gallery_handler.UpdateTag)
			galleryGroup.DELETE("/tags/:id", gallery_handler.DeleteTag)
			// 媒体查询与媒体标注/标签关系操作
			galleryGroup.GET("/media", gallery_handler.QueryMedia)
			galleryGroup.PATCH("/media", gallery_handler.PatchMedia)
			galleryGroup.POST("/media/tags", gallery_handler.BatchMediaTags)
			galleryGroup.PUT("/media/:id/tags", gallery_handler.SetMediaTags)
			// 获取一批次的媒体资产 + 全量标签 + 对应的标签关联（客户端本地缓存下载）
			galleryGroup.GET("/batch", gallery_handler.FetchBatch)
			// 获取服务端媒体库总览统计
			galleryGroup.GET("/overview", gallery_handler.FetchOverview)
			// 下载文件接口
			galleryGroup.GET("/:id/:type", gallery_handler.FetchMediaAsset)
		}

		// 工具api
		api.GET("/test", util_handler.Test) // 免鉴权
		api.GET("/ops/overview", util_handler.SystemOverview)
	}

	return r
}
