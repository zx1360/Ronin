# monarch

## Golang HTTP服务器(gin框架, 在线API)

后端程序 monarch：服务端 (HTTP API)
逻辑：智能分发与同步。

- GET /api/gallery/batch?limit={limit}&offset={offset} 响应json格式的一批次的媒体文件信息和全量的标签数据记录以及media_tag_link表中与响应的媒体文件关联的所有文件-标签关系(如果有)
  - 参考query查询代码(SELECT * FROM media_assets WHERE is_deleted = false order by sync_count asc, captured_at asc LIMIT ('limit') offset ('offset')。)
- GET /api/gallery/{id}/file 下载原文件
- GET /api/gallery/{id}/thumb 下载缩略图
- GET /api/gallery/{id}/preview 下载预览图
- GET /api/gallery/tags 获取完整标签树
- POST /api/gallery/push  根据app发来的json格式的数据表记录数据更新数据库.(media_assets的file_path字段不变), 同步数据到服务端时将每个媒体文件记录中sync_count字段加一.
- 响应文件下载请求.

- 提供“初次快照 + 增量同步”协议（面向局域网，离线友好）
- 通过header实现简单的api key验证.
