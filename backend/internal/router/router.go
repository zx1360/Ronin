package router

import (
	"log"
	"net/http"
	"os"
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
func SetupRouter() *gin.Engine {
	// 封禁日志写在 static 目录下，随应用目录一起迁移/删除
	util_handler.SetBanLogPath(filepath.Join(config.AppConf.StaticDir, "logs.txt"))

	r := gin.Default()

	// CORS 跨域配置
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "X-API-Key", "Authorization"},
		ExposeHeaders:    []string{"Content-Length", "Content-Disposition"},
		AllowCredentials: false,
	}))

	// 选择性鉴权中间件：漫画相关 + 测试接口 + 网页运维端免验证，其余均需 X-API-Key
	r.Use(selectiveAuth())

	// 静态资源响应
	r.Static("/static", config.AppConf.StaticDir)

	// 网页运维端（ops）：由后端内置 HTTP 服务托管，仅本机可打开
	setupOpsWeb(r)

	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"service": "monarch",
			"message": "Monarch HTTP 服务运行中",
		})
	})

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

		// 网页运维端的本机能力（仅回环可用）：路径定位、gallery 任务生命周期、偏好读写
		opsLocal := api.Group("/ops/local", util_handler.LocalOnly())
		{
			opsLocal.GET("/bootstrap", ops_handler.Bootstrap)
			opsLocal.PUT("/settings", ops_handler.UpdateSettings)
			opsLocal.POST("/reveal", ops_handler.Reveal)
			opsLocal.GET("/tasks", ops_handler.ListTasks)
			opsLocal.POST("/tasks", ops_handler.StartTask)
			opsLocal.GET("/tasks/:task-id", ops_handler.GetTask)
			opsLocal.POST("/tasks/:task-id/stop", ops_handler.StopTask)
		}

		// AI 智能媒体处理层（运维 + 检索 + 组织）
		aiGroup := api.Group("/ai")
		{
			// 运维：状态、队列、入队、重试、全量重生成、中断、模型进程、索引
			aiGroup.GET("/status", ai_handler.Status)
			aiGroup.GET("/capabilities", ai_handler.ListCapabilities)
			aiGroup.GET("/jobs", ai_handler.ListJobs)
			aiGroup.GET("/failures", ai_handler.ListFailures)
			aiGroup.POST("/enqueue", ai_handler.Enqueue)
			aiGroup.POST("/retry", ai_handler.Retry)
			aiGroup.POST("/regenerate", ai_handler.Regenerate)
			aiGroup.POST("/cancel", ai_handler.Cancel)
			aiGroup.POST("/resume", ai_handler.Resume)
			aiGroup.POST("/index/rebuild", ai_handler.RebuildIndex)
			aiGroup.POST("/process/:capability/start", ai_handler.StartModel)
			aiGroup.POST("/process/:capability/stop", ai_handler.StopModel)
			aiGroup.GET("/settings", ai_handler.GetSettings)
			aiGroup.PUT("/settings", ai_handler.UpdateSettings)

			// 交互式对话（NDJSON 流；Android 端聊天页使用）
			aiGroup.POST("/chat", ai_handler.Chat)

			// 近期回顾：后端算确定性统计（+ 可选随机素材）后交本地模型叙述
			aiGroup.POST("/review", ai_handler.Review)
			aiGroup.GET("/review/presets", ai_handler.GetReviewPresets)
			aiGroup.PUT("/review/presets", ai_handler.UpdateReviewPresets)

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
		}
	}

	return r
}

// setupOpsWeb 托管网页运维端静态资源（/ops/），并重定向到目录形式的首页。
//
// 页面与它的本机能力接口一样仅限本机打开：网页端要调用只允许回环的接口，
func setupOpsWeb(r *gin.Engine) {
	webDir := config.OpsConf.WebDir
	if webDir == "" {
		log.Printf("[ops] OPS_WEB_DIR 未配置，网页运维端不可用")
		return
	}
	if info, err := os.Stat(webDir); err != nil || !info.IsDir() {
		log.Printf("[ops] 网页运维端目录不可用（%s），请检查 OPS_WEB_DIR", webDir)
		return
	}

	group := r.Group("/ops", util_handler.LocalOnly())
	group.GET("", func(c *gin.Context) { c.Redirect(http.StatusFound, "/ops/") })
	group.Static("/", webDir)
	log.Printf("[ops] 网页运维端已挂载: /ops/ -> %s", webDir)
}
