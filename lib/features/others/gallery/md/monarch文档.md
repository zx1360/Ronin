# Monarch

## Golang HTTP 服务器（在线 API）

后端程序 monarch：服务端 (HTTP API)  
逻辑：智能分发与同步

---

## API 端点

### 获取批量媒体数据

```
GET /api/gallery/batch?limit={limit}&offset={offset}
```

响应 JSON 格式的一批次的媒体文件信息、全量的标签数据记录以及 `media_tag_link` 表中与响应的媒体文件关联的所有文件-标签关系（如果有）。

**参考查询代码**：
```sql
SELECT * FROM media_assets 
WHERE is_deleted = false 
ORDER BY sync_count ASC, captured_at ASC 
LIMIT ('limit') OFFSET ('offset')
```

---

### 下载原文件

```
GET /api/gallery/{id}/file
```

---

### 下载缩略图

```
GET /api/gallery/{id}/thumb
```

---

### 下载预览图

```
GET /api/gallery/{id}/preview
```

---

### 获取完整标签树

```
GET /api/gallery/tags
```

---

### 推送数据到服务端

```
POST /api/gallery/push
```

根据 App 发来的 JSON 格式的数据表记录数据更新数据库（`media_assets` 的 `file_path` 字段不变）。

**注意**：同步数据到服务端时将每个媒体文件记录中 `sync_count` 字段加一。

---

## 核心特性

- 提供"初次快照 + 增量同步"协议（面向局域网，离线友好）
- 响应文件下载请求
- 通过 Header 实现简单的 API Key 验证

---
