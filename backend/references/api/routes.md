# Route Snapshot

- GeneratedAt: 2026-05-03T12:57:12Z
- TotalRoutes: 30

| Method | Path | Handler |
| --- | --- | --- |
| GET | / | monarch/internal/router.SetupRouter.func1 |
| GET | /API/comic/chapter-info/:chapter-id | monarch/internal/handler/comic_handler.FetchImagesWithChapterId |
| GET | /API/comic/comic-info | monarch/internal/handler/comic_handler.FetchAllComicInfos |
| GET | /API/comic/comic-info/:comic-id | monarch/internal/handler/comic_handler.FetchChaptersWithComicId |
| GET | /API/comic/download/:comic-id | monarch/internal/handler/comic_handler.DownloadComic |
| GET | /API/comic/meta-info | monarch/internal/handler/comic_handler.FetchComicMetadata |
| GET | /API/gallery/:id/:type | monarch/internal/handler/gallery_handler.FetchMediaAsset |
| GET | /API/gallery/batch | monarch/internal/handler/gallery_handler.FetchBatch |
| POST | /API/gallery/push | monarch/internal/handler/gallery_handler.Push |
| GET | /API/gallery/tags | monarch/internal/handler/gallery_handler.FetchAllTags |
| GET | /API/ops/overview | monarch/internal/handler/util_handler.SystemOverview |
| GET | /API/test | monarch/internal/handler/util_handler.Test |
| POST | /API/user-data/backup/:module | monarch/internal/handler/data_handler.BackupHandler |
| GET | /API/user-data/sync/:module | monarch/internal/handler/data_handler.SyncHandler |
| DELETE | /api | monarch/internal/router.registerImmichProxyRoutes.func1 |
| GET | /api | monarch/internal/router.registerImmichProxyRoutes.func1 |
| HEAD | /api | monarch/internal/router.registerImmichProxyRoutes.func1 |
| OPTIONS | /api | monarch/internal/router.registerImmichProxyRoutes.func1 |
| PATCH | /api | monarch/internal/router.registerImmichProxyRoutes.func1 |
| POST | /api | monarch/internal/router.registerImmichProxyRoutes.func1 |
| PUT | /api | monarch/internal/router.registerImmichProxyRoutes.func1 |
| DELETE | /api/*proxyPath | monarch/internal/router.registerImmichProxyRoutes.func1 |
| GET | /api/*proxyPath | monarch/internal/router.registerImmichProxyRoutes.func1 |
| HEAD | /api/*proxyPath | monarch/internal/router.registerImmichProxyRoutes.func1 |
| OPTIONS | /api/*proxyPath | monarch/internal/router.registerImmichProxyRoutes.func1 |
| PATCH | /api/*proxyPath | monarch/internal/router.registerImmichProxyRoutes.func1 |
| POST | /api/*proxyPath | monarch/internal/router.registerImmichProxyRoutes.func1 |
| PUT | /api/*proxyPath | monarch/internal/router.registerImmichProxyRoutes.func1 |
| GET | /static/*filepath | github.com/gin-gonic/gin.(*RouterGroup).createStaticHandler.func1 |
| HEAD | /static/*filepath | github.com/gin-gonic/gin.(*RouterGroup).createStaticHandler.func1 |
