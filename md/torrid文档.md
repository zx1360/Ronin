# Torrid

## Flutter App（离线优先）

前端应用：Flutter + sqflite  
逻辑：闭环的资源管理与交互

---

## Local Data Structure (sqflite)

### 本地数据表结构

| 表名 | 说明 |
|------|------|
| `media_assets` | 镜像服务端的 `media_assets` 表（轻量级元数据） |
| `tags` | 存储标签记录（初始为从服务端获取的初始值） |
| `media_tag_links` | 存储媒体与标签的关联记录（从服务端增量获取写入） |

> **注意**：表约束与服务端的对应表保持一致。由于客户端本地的表数据量级远小于服务端，可不必过于在意性能优化。

---

## The "Review Cycle"（核心业务闭环）

### 1. Fetch（获取）

用户点击"加载新一批"（可自指定数量）。App 请求 monarch，将获取到的 JSON 数据按逻辑存储到本地 sqflite（基本是原数据表的镜像）。

### 2. Cache（缓存）

App 下载这批文件的缩略图 + 预览图存入本地存储（外部应用私有目录下的 `/gallery/yyyy-mm/...`）。

### 3. Review（审阅）

用户滑动阅览、打标签、标记删除。

### 4. Bundling（捆绑）

用户长按选 A, B, C → 设 A 为主：
- **逻辑**：更新 B, C 的 `group_id = A.id`
- **UI 表现**：隐藏 B, C，只显示 A（带堆叠图标）

### 5. Tagging（打标签）

对 A 打标签：
- **建议逻辑**：标签仅关联 A，但搜索时 B, C 视为隐式包含

### 6. Push（推送）

App 将经过操作的文件记录和 `media_tag_links` 表中与这些文件记录关联的文件-标签关联记录以及全量标签记录转为 JSON 上传服务端。

### 7. Cleanup（空间闭环）

当 monarch 确认同步成功后，App 自动删除上传数据中相关的媒体文件的缩略图和预览图以及相关数据表中的相关数据记录，为下一批文件腾出手机空间。

---

## 数据同步追加详细说明

### 客户端向服务端获取文件信息

响应包含：
- 指定量的文件信息记录
- 全量 `tags` 信息记录
- 与响应中含有的文件信息关联的所有 `media_tag` 信息记录

### 客户端向服务端提交信息

服务端处理逻辑：
- **文件信息记录**：采用这些数据对服务端数据库对应记录（除了 `file_path` 字段）进行更新
- **Tags**：删除原先所有的，以现在这些新数据为根据全部写入
- **Media_tag 记录数据**：服务端数据库 `media_tag` 表中含有新传入 media 记录的 ID 的全部删除，然后再写入现在传入的 `media_tag` 信息

### 更详细的说明

1. 用户有可能对文件进行多轮次的下载，可能在 App 连续拉取好几批
2. 客户端上传时 URL 中 `offset` 值为本地记录中存在的文件记录条数
3. 服务端通过类似以下 SQL 确保能连续增量拉取：
   ```sql
   SELECT * FROM media_assets 
   WHERE is_deleted = false 
   ORDER BY sync_count ASC, captured_at ASC 
   LIMIT ('limit') OFFSET ('offset')
   ```
4. 客户端向服务端增量覆盖

---

## UI/UX

> 追求友好交互，画面简约美观

### Review Mode

类似相册流或卡片堆叠。

### 详细信息

通过插件实现基本的缩放等操作，修改双击操作为查看文件详细信息。

---

## 技术要点

- 本地轻量数据库（sqflite），有关数据库保持与服务端数据库表结构一致
- 首次在局域网拉取快照（数据 + 缩略图/预览图）
- 后续增量同步，支持离线队列与重试
- 所有的打标签/标记删除等操作在本地离线实现，记录于与服务端数据表结构相同的 sqflite 中
- 同步时增量上传，之后删除上传的 sqflite 中相关记录，这一步确保原子性
- 与 monarch 的 HTTP 服务器对应的 API

---

## API 响应数据格式示例

**Endpoint**: `/api/gallery/batch`

```json
{
  "media_assets": [
    {
      "id": "71ab794a-25cf-46a7-a3b8-622e37474e5d",
      "created_at": "2026-01-28T19:40:16.961975+08:00",
      "updated_at": "2026-01-28T19:40:16.961975+08:00",
      "captured_at": "2008-08-29T14:10:56+08:00",
      "file_path": "2008-08\\Super Sonico超级索尼子壁纸.jpg",
      "thumb_path": "2008-08\\Super Sonico超级索尼子壁纸_thumb.jpg",
      "preview_path": "2008-08\\Super Sonico超级索尼子壁纸_preview.jpg",
      "hash": "9xy9SF4oUH/E3CpFOU26qnJU4rcEClHEFMo5go9Lyus=",
      "size_bytes": 1942070,
      "mime_type": "image/jpeg",
      "is_deleted": false,
      "sync_count": 0,
      "group_id": null
    }
    ...
  ],
  "tags": null,
  "media_tag_links": null
}
```

> 注：`tags` 和 `media_tag_links` 值可能初始为空，不为空则为 JSON 格式的数据表中的数据的列表。

---
