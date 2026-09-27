# 藏品数据表（gallery）

> 表结构以 `internal/service/db/schema.sql` 为唯一真相源，`references/db/schema.sql` 是它的生成副本。
> 时间列统一 TEXT（`2006-01-02T15:04:05.000Z`，UTC 定宽，字典序即时序），布尔列 INTEGER 0/1，
> 数组列 JSON 文本，UUID 存 TEXT；`updated_at` 由 Go 侧显式写入（没有触发器）。

## gallery_media_assets

| 列           | 类型                                          |
| ------------ | --------------------------------------------- |
| id           | TEXT PRIMARY KEY (UUID)                       |
| created_at   | TEXT NOT NULL                                 |
| updated_at   | TEXT NOT NULL（每次 UPDATE 必须显式写入）      |
| captured_at  | TEXT NOT NULL                                 |
| file_path    | TEXT NOT NULL                                 |
| thumb_path   | TEXT                                          |
| preview_path | TEXT                                          |
| hash         | BLOB NOT NULL UNIQUE（SHA-256）               |
| size_bytes   | INTEGER NOT NULL DEFAULT 0                    |
| mime_type    | TEXT                                          |
| is_deleted   | INTEGER NOT NULL DEFAULT 0                    |
| sync_count   | INTEGER NOT NULL DEFAULT 0（批次处理游标）     |
| group_id     | TEXT FK→gallery_media_assets ON DELETE SET NULL |
| message      | TEXT                                          |
| edit_params  | TEXT（JSON）                                  |

索引：`(is_deleted, sync_count, captured_at)`、`updated_at`、`captured_at`、`group_id`、`mime_type`。

### 派生档目录约定

原始文件在 `<GALLERY_DIR>/Media/`，派生档各自独立目录，入库/刷新由 gizmos 维护：

| 目录 | 内容 | 尺寸 |
| ---- | ---- | ---- |
| `Thumbs/` | 中心裁剪方图 | 边长 256 |
| `Preview/` | 保持比例的预览图，`preview_path` 指向它 | 最大边 256 |
| `AI/` | **AI 专用派生档**，按需生成并缓存；路径由 `file_path` 确定性推导，不入库 | 长边 1024 |

`Preview` 的语义与用途不变（浏览用）；face/ocr/vlm 一律读 `AI/`，phash/embed 仍读 `Preview/`。

### edit_params 契约（客户端编辑 → gizmos execute 处理）

客户端保存编辑参数到 `edit_params`，`gallery execute` 流水线 Phase B 消费
（`edit_params IS NOT NULL AND is_deleted = 0`），处理成功后清除该字段；
无操作编辑（无旋转/无裁切/无剪辑）只清除字段、不搬移文件。

- **图片** `{"type":"image","rotation":0..270,"crop_left/top/right/bottom":int}`
  - 裁切坐标 = **原始图片（未旋转）像素坐标**；后端先旋转、再把坐标换算到
    旋转后坐标系裁剪（前端 ImageEditorPage 与之一致）。
- **视频** `{"type":"video","trim_start_sec":float,"trim_end_sec":float,"duration":float}`
  - 时间单位一律为**秒**；`trim_end_sec <= 0` 表示"到结尾"；
  - `trim_start_frame/trim_end_frame/fps` 为旧版遗留字段，仅秒数缺失时后备解析；
  - 后端使用 ffmpeg 输入侧 `-ss` + 重新编码（H.264/AAC）实现帧级准确剪辑。

## gallery_tags

| 列          | 类型                                          |
| ----------- | --------------------------------------------- |
| id          | TEXT PRIMARY KEY (UUID)                       |
| created_at  | TEXT NOT NULL                                 |
| updated_at  | TEXT NOT NULL                                 |
| name        | TEXT NOT NULL                                 |
| parent_id   | TEXT FK→gallery_tags ON DELETE CASCADE        |
| full_path   | TEXT NOT NULL DEFAULT ''                      |
| is_favorite | INTEGER NOT NULL DEFAULT 0                    |

- 唯一约束：`(name, parent_id)` 不允许同名同级标签。
- **`full_path` 由 Go 侧维护**（原 PostgreSQL 触发器已上移到 `gallery_repo`）：
  建标签时显式写出；改名或改父级时用一条递归 CTE 取出子树并按深度顺序重算全部子孙。
- 删除标签靠外键级联删除子孙标签与媒体标签关联。
- 标签写操作一律走 `/API/gallery/tags`（服务端权威），客户端本地表仅作缓存。

## gallery_media_tag_links

| 列       | 类型                                              |
| -------- | ------------------------------------------------- |
| media_id | TEXT NOT NULL FK→gallery_media_assets ON DELETE CASCADE |
| tag_id   | TEXT NOT NULL FK→gallery_tags ON DELETE CASCADE   |

- 复合主键 `(tag_id, media_id)`；另建 `media_id` 索引。
