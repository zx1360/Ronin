# 藏品数据表 (gallery schema)

## 建表

### media_assets

```postgresql
CREATE TABLE IF NOT EXISTS media_assets (
    ID UUID PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    captured_at TIMESTAMPTZ NOT NULL,
    file_path TEXT NOT NULL,
    thumb_path TEXT,
    preview_path TEXT,
    hash BYTEA NOT NULL UNIQUE,
    size_bytes BIGINT NOT NULL DEFAULT 0,
    mime_type TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    sync_count INTEGER NOT NULL DEFAULT 0,
    group_id UUID DEFAULT NULL,
    message TEXT DEFAULT NULL,
    CONSTRAINT fk_group_id FOREIGN KEY (group_id) REFERENCES media_assets (ID) ON DELETE SET NULL
);
```

### 索引

```postgresql
CREATE INDEX IF NOT EXISTS idx_media_assets_sync_captured ON media_assets (is_deleted, sync_count, captured_at);
CREATE INDEX IF NOT EXISTS idx_media_assets_updated_at ON media_assets (updated_at);
CREATE INDEX IF NOT EXISTS idx_media_assets_group_id ON media_assets (group_id);
CREATE INDEX IF NOT EXISTS idx_media_assets_mime_type ON media_assets (mime_type);
```

### tags

```postgresql
CREATE TABLE IF NOT EXISTS tags (
    ID UUID PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NAME TEXT NOT NULL,
    parent_id UUID,
    full_path TEXT,
    CONSTRAINT fk_parent_id FOREIGN KEY (parent_id) REFERENCES tags (ID) ON DELETE CASCADE,
    CONSTRAINT uk_tag_name_parent UNIQUE (NAME, parent_id)
);
```

### 索引

```postgresql
CREATE INDEX IF NOT EXISTS idx_tags_parent_id ON tags (parent_id);
CREATE INDEX IF NOT EXISTS idx_tags_full_path ON tags (full_path);
```

### media_tag_links

```postgresql
CREATE TABLE IF NOT EXISTS media_tag_links (
    media_id UUID,
    tag_id UUID,
    PRIMARY KEY (tag_id, media_id),
    CONSTRAINT fk_media_id FOREIGN KEY (media_id) REFERENCES media_assets (ID) ON DELETE CASCADE,
    CONSTRAINT fk_tag_id FOREIGN KEY (tag_id) REFERENCES tags (ID) ON DELETE CASCADE
);
```

### 索引

```postgresql
CREATE INDEX IF NOT EXISTS idx_media_tag_links_media_id ON media_tag_links (media_id);
```

## 触发器

### 自增同步次数

```postgresql
CREATE OR REPLACE FUNCTION increment_sync_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NOT (OLD.sync_count IS DISTINCT FROM NEW.sync_count) THEN
            NEW.sync_count = OLD.sync_count + 1;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_media_assets_sync_count ON media_assets;
CREATE TRIGGER trigger_media_assets_sync_count
    BEFORE UPDATE ON media_assets
    FOR EACH ROW
    EXECUTE FUNCTION increment_sync_count();
```

### 更新时间

```postgresql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = PUBLIC;

CREATE TRIGGER trigger_media_assets_updated_at BEFORE UPDATE ON media_assets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_tags_updated_at BEFORE UPDATE ON tags FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### tags 路径级联更新

```postgresql
-- 计算 full_path
CREATE OR REPLACE FUNCTION gallery.tags_compute_full_path(p_name TEXT, p_parent_id UUID)
RETURNS TEXT LANGUAGE plpgsql STABLE AS $$
DECLARE v_parent_path TEXT;
BEGIN
    IF p_parent_id IS NULL THEN RETURN p_name; END IF;
    SELECT full_path INTO v_parent_path FROM gallery.tags WHERE id = p_parent_id;
    IF v_parent_path IS NULL THEN RETURN p_name; END IF;
    RETURN v_parent_path || '/' || p_name;
END;
$$;

-- 递归级联更新子节点
CREATE OR REPLACE FUNCTION gallery.tags_cascade_update_full_path(p_id UUID)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE v_child RECORD; v_new_path TEXT;
BEGIN
    FOR v_child IN SELECT id, name FROM gallery.tags WHERE parent_id = p_id LOOP
        SELECT full_path || '/' || v_child.name INTO v_new_path FROM gallery.tags WHERE id = p_id;
        UPDATE gallery.tags SET full_path = v_new_path, updated_at = CURRENT_TIMESTAMP WHERE id = v_child.id;
        PERFORM gallery.tags_cascade_update_full_path(v_child.id);
    END LOOP;
END;
$$;

-- BEFORE INSERT/UPDATE
CREATE OR REPLACE FUNCTION gallery.tags_before_ins_upd()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.full_path := gallery.tags_compute_full_path(NEW.name, NEW.parent_id);
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- AFTER UPDATE
CREATE OR REPLACE FUNCTION gallery.tags_after_upd()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.name IS DISTINCT FROM NEW.name OR OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
        PERFORM gallery.tags_cascade_update_full_path(NEW.id);
    END IF;
    RETURN NULL;
END;
$$;

-- 绑定触发器
DROP TRIGGER IF EXISTS trg_tags_before_ins_upd ON gallery.tags;
DROP TRIGGER IF EXISTS trg_tags_after_upd ON gallery.tags;
CREATE TRIGGER trg_tags_before_ins_upd BEFORE INSERT OR UPDATE OF name, parent_id ON gallery.tags FOR EACH ROW EXECUTE FUNCTION gallery.tags_before_ins_upd();
CREATE TRIGGER trg_tags_after_upd AFTER UPDATE OF name, parent_id ON gallery.tags FOR EACH ROW EXECUTE FUNCTION gallery.tags_after_upd();
```
