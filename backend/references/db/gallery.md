# 藏品数据表

> 建表真源：`references/db/sqlite.sql`（本节只描述语义）。类型约定见 `AGENTS_DB.md`。

## media_assets

| 列           | 类型                                                      |
| ------------ | --------------------------------------------------------- |
| id           | TEXT PRIMARY KEY (UUID)                                   |
| created_at   | TEXT NOT NULL DEFAULT 本地时间文本                         |
| updated_at   | TEXT NOT NULL DEFAULT 本地时间文本 (AFTER UPDATE 触发器维护) |
| captured_at  | TEXT NOT NULL                                             |
| file_path    | TEXT NOT NULL                                             |
| thumb_path   | TEXT                                                      |
| preview_path | TEXT                                                      |
| hash         | BLOB NOT NULL UNIQUE                                      |
| size_bytes   | INTEGER NOT NULL DEFAULT 0                                |
| mime_type    | TEXT                                                      |
| is_deleted   | INTEGER NOT NULL DEFAULT 0                                |
| sync_count   | INTEGER NOT NULL DEFAULT 0（由调用方显式 +1，非触发器）    |
| group_id     | TEXT DEFAULT NULL FK→media_assets (ON DELETE SET NULL)    |
| message      | TEXT DEFAULT NULL                                         |
| edit_params  | TEXT DEFAULT NULL（JSON 文本）                             |

### edit_params 契约（Android 编辑 → gizmos execute 处理）

客户端保存编辑参数到 `edit_params`，`gallery execute` 流水线 Phase B 消费
（`edit_params IS NOT NULL AND is_deleted = 0`），处理成功后清除该字段；
无操作编辑（无旋转/无裁切/无剪辑）只清除字段、不搬移文件。

- **图片** `{"type":"image","rotation":0..270,"crop_left/top/right/bottom":int}`
  - 裁切坐标 = **原始图片（未旋转）像素坐标**；后端先旋转、再把坐标换算到
    旋转后坐标系裁剪（Android 端 ImageEditorPage 与之一致）。
- **视频** `{"type":"video","trim_start_sec":float,"trim_end_sec":float,"duration":float}`
  - 时间单位一律为**秒**；`trim_end_sec <= 0` 表示"到结尾"；
  - `trim_start_frame/trim_end_frame/fps` 为旧版遗留字段，仅秒数缺失时后备解析；
  - 后端使用 ffmpeg 输入侧 `-ss` + 重新编码（H.264/AAC）实现帧级准确剪辑。

## tags

| 列          | 类型                                                      |
| ----------- | --------------------------------------------------------- |
| id          | TEXT PRIMARY KEY (UUID)                                   |
| created_at  | TEXT NOT NULL DEFAULT 本地时间文本                         |
| updated_at  | TEXT NOT NULL DEFAULT 本地时间文本 (AFTER UPDATE 触发器维护) |
| name        | TEXT NOT NULL                                             |
| parent_id   | TEXT DEFAULT NULL FK→tags (ON DELETE CASCADE)             |
| full_path   | TEXT（自动计算，格式：父路径/name）                        |
| is_favorite | INTEGER NOT NULL DEFAULT 0（快捷标签标记）                 |

- 唯一约束：(name, parent_id) 不允许同名同级标签（NULL 父级不被 SQLite 视为相等，
  因此同级过滤由 `ensureSiblingNameFree` 显式校验，与原 PG 行为一致）
- **`full_path` 与子孙路径级联由 Go 维护**（`gallery_repo.rebuildTagPaths`）：
  写操作后整体重算全树路径，只更新变化的行
- 删除标签级联删除子孙标签与媒体标签关联
- 标签写操作一律走 `/API/gallery/tags`（服务端权威），客户端本地表仅作缓存

## media_tag_links

| 列       | 类型                                            |
| -------- | ----------------------------------------------- |
| media_id | TEXT NOT NULL FK→media_assets (ON DELETE CASCADE) |
| tag_id   | TEXT NOT NULL FK→tags (ON DELETE CASCADE)         |

- 复合主键：(tag_id, media_id)
- 「标签含子孙」筛选在 Go 侧先把子孙 ID 展开成平铺列表再查
  （SQLite 无法把相关子查询里的递归 CTE 提前求值，写成 `EXISTS(...WITH RECURSIVE)`
  会退化成逐行重算，实测慢三个数量级）
