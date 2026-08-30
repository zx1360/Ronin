# 藏品数据表 (gallery schema)

## media_assets

| 列           | 类型                                                      |
| ------------ | --------------------------------------------------------- |
| id           | UUID PRIMARY KEY                                          |
| created_at   | TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP            |
| updated_at   | TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP (自动更新) |
| captured_at  | TIMESTAMPTZ NOT NULL                                      |
| file_path    | TEXT NOT NULL                                             |
| thumb_path   | TEXT                                                      |
| preview_path | TEXT                                                      |
| hash         | BYTEA NOT NULL UNIQUE                                     |
| size_bytes   | BIGINT NOT NULL DEFAULT 0                                 |
| mime_type    | TEXT                                                      |
| is_deleted   | BOOLEAN NOT NULL DEFAULT FALSE                            |
| sync_count   | INTEGER NOT NULL DEFAULT 0 (每次 UPDATE 自动 +1)          |
| group_id     | UUID DEFAULT NULL FK→media_assets                         |
| message      | TEXT DEFAULT NULL                                         |
| edit_params  | JSONB DEFAULT NULL                                        |

### edit_params 契约（Android 编辑 → gizmos execute 处理）

客户端保存编辑参数到 `edit_params`，`gallery execute` 流水线 Phase B 消费
（`edit_params IS NOT NULL AND is_deleted = false`），处理成功后清除该字段；
无操作编辑（无旋转/无裁切/无剪辑）只清除字段、不搬移文件。

- **图片** `{"type":"image","rotation":0..270,"crop_left/top/right/bottom":int}`
  - 裁切坐标 = **原始图片（未旋转）像素坐标**；后端先旋转、再把坐标换算到
    旋转后坐标系裁剪（Android 端 ImageEditorPage 与之一致）。
- **视频** `{"type":"video","trim_start_sec":float,"trim_end_sec":float,"duration":float}`
  - 时间单位一律为**秒**；`trim_end_sec <= 0` 表示"到结尾"；
  - `trim_start_frame/trim_end_frame/fps` 为旧版遗留字段，仅秒数缺失时后备解析；
  - 后端使用 ffmpeg 输入侧 `-ss` + 重新编码（H.264/AAC）实现帧级准确剪辑。

## tags

| 列         | 类型                                                      |
| ---------- | --------------------------------------------------------- |
| id         | UUID PRIMARY KEY                                          |
| created_at | TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP            |
| updated_at | TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP (自动更新) |
| name       | TEXT NOT NULL                                             |
| parent_id  | UUID DEFAULT NULL FK→tags                                 |
| full_path  | TEXT (自动计算，格式：父路径/name)                        |

- 唯一约束：(name, parent_id) 不允许同名同级标签

## media_tag_links

| 列       | 类型                          |
| -------- | ----------------------------- |
| media_id | UUID NOT NULL FK→media_assets |
| tag_id   | UUID NOT NULL FK→tags         |

- 复合主键：(tag_id, media_id)
