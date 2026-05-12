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
