package router

import (
	"net/http"
	"path/filepath"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"monarch/internal/config"
	"monarch/internal/handler/ai_handler"
	"monarch/internal/handler/comic_handler"
	"monarch/internal/handler/comix_handler"
	"monarch/internal/handler/data_handler"
	"monarch/internal/handler/gallery_handler"
	"monarch/internal/handler/ops_handler"
	"monarch/internal/handler/util_handler"
)

// SetupRouter 构建全部路由与中间件。
//
// 同一个 router 会被挂到两个监听上：生产模式的 LAN HTTPS 监听（需 X-API-Key）
// 与只绑回环的 HTTP 监听（ops 网页应用与本机能力）。回环请求由 APIKeyAuth 直接
// 放行，因此浏览器无需也无法携带 API Key。
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

	// 选择性鉴权中间件：回环请求与漫画相关/测试接口免验证，其余均需 X-API-Key。
	// 本地开发模式完全不鉴权（手机端需要直连局域网地址调试）。
	if !config.IsLocalMode {
		r.Use(selectiveAuth())
	}

	// 静态资源响应
	r.Static("/static", config.AppConf.StaticDir)

	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"service": "monarch",
			"message": "Monarch HTTP 服务运行中",
			"ops":     "/ops/",
		})
	})

	// ops 网页应用（仅回环可访问）
	registerOpsRoutes(r)

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

		// comix 漫画爬虫管理（异步任务由服务端管理生命周期）
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

		// AI 智能媒体处理层（运维 + 检索 + 组织）
		aiGroup := api.Group("/ai")
		{
			// 运维：状态、队列、入队、重试、中断、模型进程、索引
			aiGroup.GET("/status", ai_handler.Status)
			aiGroup.GET("/capabilities", ai_handler.Capabilities)
			aiGroup.GET("/jobs", ai_handler.ListJobs)
			aiGroup.POST("/enqueue", ai_handler.Enqueue)
			aiGroup.POST("/retry", ai_handler.Retry)
			aiGroup.POST("/cancel", ai_handler.Cancel)
			aiGroup.POST("/resume", ai_handler.Resume)
			aiGroup.POST("/index/rebuild", ai_handler.RebuildIndex)
			aiGroup.POST("/process/:capability/start", ai_handler.StartModel)
			aiGroup.POST("/process/:capability/stop", ai_handler.StopModel)

			// 交互式对话（NDJSON 流；对话页使用）
			aiGroup.POST("/chat", ai_handler.Chat)

			// 检索：文本搜图 / 以图搜图 / 组合筛选
			aiGroup.GET("/search", ai_handler.Search)
			aiGroup.POST("/search/image", ai_handler.SearchByImage)
			aiGroup.GET("/similar/:id", ai_handler.Similar)
			aiGroup.GET("/media/:id", ai_handler.MediaDetail)
			aiGroup.GET("/duplicates", ai_handler.Duplicates)
			aiGroup.POST("/duplicates/ignore", ai_handler.IgnoreDuplicates)
			aiGroup.POST("/duplicates/unignore", ai_handler.UnignoreDuplicates)
			aiGroup.GET("/duplicates/ignored", ai_handler.ListIgnoredDuplicates)
			aiGroup.GET("/tags", ai_handler.ListVLMTags)

			// 组织：人物分组
			aiGroup.GET("/persons", ai_handler.ListPersons)
			aiGroup.GET("/persons/:id/faces", ai_handler.ListPersonFaces)
			aiGroup.PATCH("/persons/:id", ai_handler.UpdatePerson)
			aiGroup.DELETE("/persons/:id", ai_handler.DeletePerson)
			aiGroup.POST("/persons/merge", ai_handler.MergePersons)
			aiGroup.POST("/faces/assign", ai_handler.AssignFaces)
			aiGroup.POST("/recluster", ai_handler.Recluster)

			// 近期回顾：后端算确定性统计，再由本地模型生成叙述
			aiGroup.GET("/review/presets", ai_handler.ListReviewPresets)
			aiGroup.POST("/review/presets", ai_handler.UpsertReviewPreset)
			aiGroup.DELETE("/review/presets/:id", ai_handler.DeleteReviewPreset)
			aiGroup.POST("/review", ai_handler.GenerateReview)
		}
	}

	return r
}

// registerOpsRoutes 挂载 ops 网页应用与本机能力接口（进程、任务、路径、配置）。
//
// 页面本身与本机能力接口都只对本机开放：这些接口能启动进程、读写本机文件，
// 而 LAN 侧的客户端用不到运维台（页面还会因回环限制而取不到任何数据）。
func registerOpsRoutes(r *gin.Engine) {
	opsDir := config.ResolveOpsDir()
	page := r.Group("", util_handler.RequireLoopback())
	if opsDir != "" {
		// 页面本身是静态文件，不做构建，直接由服务端托管
		page.Static("/ops", opsDir)
		page.GET("/ops", func(c *gin.Context) { c.Redirect(http.StatusFound, "/ops/") })
	} else {
		page.GET("/ops", func(c *gin.Context) {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "未找到 ops 网页目录（设置 app.ops_dir）"})
		})
	}

	g := r.Group("/API/ops", util_handler.RequireLoopback())
	{
		g.GET("/overview", ops_handler.SystemOverview)
		g.GET("/capabilities", ops_handler.Capabilities)
		g.GET("/dependencies", ops_handler.Dependencies)
		g.GET("/fs", ops_handler.ListDirectories)
		g.POST("/reveal", ops_handler.Reveal)
		g.GET("/preferences", ops_handler.GetPreferences)
		g.PUT("/preferences", ops_handler.UpdatePreferences)

		g.POST("/gallery/tasks", ops_handler.RunGallery)
		g.GET("/gallery/tasks", ops_handler.ListGalleryTasks)
		g.GET("/gallery/tasks/:task-id", ops_handler.GetGalleryTask)
		g.POST("/gallery/tasks/:task-id/stop", ops_handler.StopGalleryTask)
	}

	// 运行时配置读写同样只对本机开放
	s := r.Group("/API/settings", util_handler.RequireLoopback())
	{
		s.GET("", ops_handler.GetSettings)
		s.PUT("", ops_handler.UpdateSettings)
	}
}
