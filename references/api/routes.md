# Route Snapshot

- GeneratedAt: 2026-04-19T22:55:04Z
- TotalRoutes: 16

| Method | Path | Handler |
| --- | --- | --- |
| GET | / | monarch/internal/router.SetupRouter.func1 |
| GET | /api/comic/chapter-info/:chapter-id | monarch/internal/handler/comic_handler.FetchImagesWithChapterId |
| GET | /api/comic/comic-info | monarch/internal/handler/comic_handler.FetchAllComicInfos |
| GET | /api/comic/comic-info/:comic-id | monarch/internal/handler/comic_handler.FetchChaptersWithComicId |
| GET | /api/comic/download/:comic-id | monarch/internal/handler/comic_handler.DownloadComic |
| GET | /api/comic/meta-info | monarch/internal/handler/comic_handler.FetchComicMetadata |
| GET | /api/gallery/:id/:type | monarch/internal/handler/gallery_handler.FetchMediaAsset |
| GET | /api/gallery/batch | monarch/internal/handler/gallery_handler.FetchBatch |
| POST | /api/gallery/push | monarch/internal/handler/gallery_handler.Push |
| GET | /api/gallery/tags | monarch/internal/handler/gallery_handler.FetchAllTags |
| GET | /api/ops/overview | monarch/internal/handler/util_handler.SystemOverview |
| GET | /api/test | monarch/internal/handler/util_handler.Test |
| POST | /api/user-data/backup/:module | monarch/internal/handler/data_handler.BackupHandler |
| GET | /api/user-data/sync/:module | monarch/internal/handler/data_handler.SyncHandler |
| GET | /static/*filepath | github.com/gin-gonic/gin.(*RouterGroup).createStaticHandler.func1 |
| HEAD | /static/*filepath | github.com/gin-gonic/gin.(*RouterGroup).createStaticHandler.func1 |
