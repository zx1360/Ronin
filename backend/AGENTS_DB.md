# 数据库相关信息

**PostgreSQL18.0**
本部分不轻易变动.

以下为数据表结构以及触发器定义.

## 漫画页数据表

### 建表

```postgresql
-- 漫画主表（存储单本漫画信息）
CREATE TABLE IF NOT EXISTS comics.comic_books (
    id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    cover_image TEXT -- 封面图相对路径.
		is_public BOOLEAN NOT NULL DEFAULT TRUE,
		readed BOOLEAN NOT NULL DEFAULT FALSE,
    source TEXT NOT NULL DEFAULT '';
);

-- 漫画章节表（存储单本漫画的章节信息）
CREATE TABLE IF NOT EXISTS comics.comic_chapters (
    id UUID PRIMARY KEY,
    comic_id uuid NOT NULL,
    dir_name VARCHAR(255) NOT NULL, -- 格式：001_章节名
    chapter_index INTEGER NOT NULL,
    FOREIGN KEY (comic_id) REFERENCES comic_books(id) ON DELETE CASCADE
);

-- 漫画图片表（存储章节下的图片路径及属性）
CREATE TABLE IF NOT EXISTS comics.comic_images (
    id UUID PRIMARY KEY,
    chapter_id UUID NOT NULL,
    image_path TEXT NOT NULL,
    sort_num INTEGER NOT NULL, -- 图片排序号（1、2、3...）
    width INTEGER NOT NULL, -- 图片宽度
    height INTEGER NOT NULL, -- 图片高度
    FOREIGN KEY (chapter_id) REFERENCES comic_chapters(id) ON DELETE CASCADE
);

-- 章节表：comic_id查询+排序索引
CREATE INDEX if not exists idx_comic_chapters_comic_id ON comics.comic_chapters (comic_id, chapter_index);
-- 图片表：chapter_id查询+排序索引
CREATE INDEX if not exists idx_comic_images_chapter_id ON comics.comic_images (chapter_id, sort_num);

```



## 藏品页数据表

### 建表

```postgresql
-- 文件信息表media_assets
CREATE TABLE
IF
	NOT EXISTS media_assets (
		ID UUID PRIMARY KEY,
		created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,-- 入库时间
		updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,-- 修改时间
		captured_at TIMESTAMPTZ NOT NULL,-- 优先级: EXIF > 修改时间 > 创建时间
		file_path TEXT NOT NULL,-- 存储中的相对路径
		thumb_path TEXT,-- 生成的缩略图/封面图相对路径
		preview_path TEXT,-- 生成的预览图相对路径
		hash BYTEA NOT NULL UNIQUE,-- SHA-256 用于去重
		size_bytes BIGINT NOT NULL DEFAULT 0,
		mime_type TEXT,
		is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
		sync_count INTEGER NOT NULL DEFAULT 0,-- 表示该媒体文件记录从移动端被同步到服务端的次数
		group_id UUID DEFAULT NULL,-- 指向“主文件”的 ID。如果不为空，代表该文件被捆绑.
		message TEXT default null,
		CONSTRAINT fk_group_id FOREIGN KEY ( group_id ) REFERENCES media_assets ( ID ) ON DELETE 
	SET NULL 
	);
-- 为media_assets添加索引
CREATE INDEX
IF
	NOT EXISTS idx_media_assets_sync_captured ON media_assets ( is_deleted, sync_count, captured_at );
CREATE INDEX
IF
	NOT EXISTS idx_media_assets_updated_at ON media_assets ( updated_at );-- 更新日期排序.
CREATE INDEX
IF
	NOT EXISTS idx_media_assets_group_id ON media_assets ( group_id );--主文件查询
CREATE INDEX
IF
	NOT EXISTS idx_media_assets_mime_type ON media_assets ( mime_type );--按文件类型排序

-- 标签表tags, 树状结构
CREATE TABLE
IF
	NOT EXISTS tags (
		ID UUID PRIMARY KEY,
		created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
		NAME TEXT NOT NULL,
		parent_id UUID,-- 记录其父标签, 根节点为 Null.
		full_path TEXT,-- 冗余字段用于快速搜索, 例如 "Family/2023/Xmas"). 级联更新.
		CONSTRAINT fk_parent_id FOREIGN KEY ( parent_id ) REFERENCES tags ( ID ) ON DELETE CASCADE,
		CONSTRAINT uk_tag_name_parent UNIQUE ( NAME, parent_id ) 
	);
-- 为tags添加索引
CREATE INDEX
IF
	NOT EXISTS idx_tags_parent_id ON tags ( parent_id );-- 按父标签查询子标签
CREATE INDEX
IF
	NOT EXISTS idx_tags_full_path ON tags ( full_path );-- 按完整路径快速搜索

-- 文件标签关联表media_tag_links
CREATE TABLE
IF
	NOT EXISTS media_tag_links (
		media_id UUID,
		tag_id UUID,
		PRIMARY KEY ( tag_id, media_id ),
		CONSTRAINT fk_media_id FOREIGN KEY ( media_id ) REFERENCES media_assets ( ID ) ON DELETE CASCADE,
		CONSTRAINT fk_tag_id FOREIGN KEY ( tag_id ) REFERENCES tags ( ID ) ON DELETE CASCADE 
	);
-- 为media_tag_links添加索引
CREATE INDEX
IF
	NOT EXISTS idx_media_tag_links_media_id ON media_tag_links ( media_id );-- 按媒体ID查询关联媒体
```



### 触发器

#### 触发器-自增同步次数

```postgresql
-- 1. 创建触发器函数：仅在未显式更新 sync_count 时自动自增
CREATE OR REPLACE FUNCTION increment_sync_count()
RETURNS TRIGGER AS $$
BEGIN
    -- 只在记录被更新时执行（排除 INSERT 场景）
    IF TG_OP = 'UPDATE' THEN
        -- 核心逻辑：检查是否显式更新了 sync_count 字段
        -- (OLD.sync_count IS DISTINCT FROM NEW.sync_count) 表示字段值被主动修改过
        -- 取反后，仅当字段未被显式更新时才自增
        IF NOT (OLD.sync_count IS DISTINCT FROM NEW.sync_count) THEN
            NEW.sync_count = OLD.sync_count + 1;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. 重建触发器（如果触发器已存在，先删除再创建）
DROP TRIGGER IF EXISTS trigger_media_assets_sync_count ON media_assets;
CREATE TRIGGER trigger_media_assets_sync_count
BEFORE UPDATE ON media_assets
FOR EACH ROW
EXECUTE FUNCTION increment_sync_count();
```



#### 触发器-更新时间

```postgresql
-- 创建通用的updated_at自动更新触发器函数
CREATE 
	OR REPLACE FUNCTION update_updated_at_column ( ) RETURNS TRIGGER AS $$ BEGIN
		NEW.updated_at := CURRENT_TIMESTAMP;
	RETURN NEW;
	
END;
$$ LANGUAGE plpgsql SECURITY DEFINER 
SET search_path = PUBLIC;

-- 为media_assets表添加updated_at触发器
CREATE TRIGGER trigger_media_assets_updated_at BEFORE UPDATE ON media_assets FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column ( );

-- 为tags表添加updated_at触发器
CREATE TRIGGER trigger_tags_updated_at BEFORE UPDATE ON tags FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column ( );
```



#### 触发器-tags路径级联更新

```postgresql
-- ============================================
-- 1. 先删除可能存在的旧触发器
-- ============================================
DROP TRIGGER IF EXISTS trg_tags_before_ins_upd ON gallery.tags;
DROP TRIGGER IF EXISTS trg_tags_after_upd ON gallery.tags;

-- ============================================
-- 2. 创建函数（指定 schema 为 gallery）
-- ============================================
CREATE OR REPLACE FUNCTION gallery.tags_compute_full_path(p_name TEXT, p_parent_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_parent_path TEXT;
BEGIN
  IF p_parent_id IS NULL THEN
    RETURN p_name;
  END IF;

  SELECT full_path INTO v_parent_path
  FROM gallery.tags
  WHERE id = p_parent_id;

  IF v_parent_path IS NULL THEN
    RETURN p_name;
  END IF;

  RETURN v_parent_path || '/' || p_name;
END;
$$;

-- ============================================
-- 3. 递归级联更新子节点
-- ============================================
CREATE OR REPLACE FUNCTION gallery.tags_cascade_update_full_path(p_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_child RECORD;
  v_new_path TEXT;
BEGIN
  FOR v_child IN
    SELECT id, name FROM gallery.tags WHERE parent_id = p_id
  LOOP
    SELECT full_path || '/' || v_child.name INTO v_new_path
    FROM gallery.tags WHERE id = p_id;

    UPDATE gallery.tags
    SET full_path = v_new_path,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_child.id;

    PERFORM gallery.tags_cascade_update_full_path(v_child.id);
  END LOOP;
END;
$$;

-- ============================================
-- 4. BEFORE INSERT/UPDATE 触发器函数
-- ============================================
CREATE OR REPLACE FUNCTION gallery.tags_before_ins_upd()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.full_path := gallery.tags_compute_full_path(NEW.name, NEW.parent_id);
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

-- ============================================
-- 5. AFTER UPDATE 触发器函数
-- ============================================
CREATE OR REPLACE FUNCTION gallery.tags_after_upd()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.name IS DISTINCT FROM NEW.name 
     OR OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
    PERFORM gallery.tags_cascade_update_full_path(NEW.id);
  END IF;
  RETURN NULL;
END;
$$;

-- ============================================
-- 6. 绑定触发器
-- ============================================
CREATE TRIGGER trg_tags_before_ins_upd
BEFORE INSERT OR UPDATE OF name, parent_id
ON gallery.tags
FOR EACH ROW
EXECUTE FUNCTION gallery.tags_before_ins_upd();

CREATE TRIGGER trg_tags_after_upd
AFTER UPDATE OF name, parent_id
ON gallery.tags
FOR EACH ROW
EXECUTE FUNCTION gallery.tags_after_upd();
```

## 用户数据表(booklet和essay模块)

### 建表

```postgresql
-- essay_articles: 随笔文章表
CREATE TABLE IF NOT EXISTS essay_articles (
    id          UUID PRIMARY KEY,                -- 沿用原 JSON 中的 id
    date        TIMESTAMPTZ NOT NULL,            -- 文章日期时间
    word_count  INT NOT NULL DEFAULT 0,          -- 字数
    content     TEXT NOT NULL DEFAULT '',         -- 正文
    imgs        TEXT[] NOT NULL DEFAULT '{}',     -- 图片路径数组
    labels      UUID[] NOT NULL DEFAULT '{}',     -- 标签 UUID 数组
    messages    JSONB NOT NULL DEFAULT '[]',      -- 留言: [{"timestamp":"...","content":"..."}]
    mood        TEXT,                             -- 心情: happy/sad/tired/angry/calm/null
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 全文搜索向量（content 权重 B，无 title 故无 A 权重）
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('simple', coalesce(content, '')), 'B')
    ) STORED
);

-- 索引
CREATE INDEX idx_essay_articles_date ON essay_articles(date);
CREATE INDEX idx_essay_articles_labels ON essay_articles USING GIN(labels);
CREATE INDEX idx_essay_articles_mood ON essay_articles(mood);
CREATE INDEX idx_essay_articles_search ON essay_articles USING GIN(search_vector);
CREATE INDEX idx_essay_articles_updated ON essay_articles(updated_at);

-- updated_at 触发器
CREATE OR REPLACE FUNCTION update_essay_articles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_essay_articles_updated_at
    BEFORE UPDATE ON essay_articles
    FOR EACH ROW EXECUTE FUNCTION update_essay_articles_updated_at();
		

-- essay_labels: 随笔标签表
CREATE TABLE IF NOT EXISTS essay_labels (
    id          UUID PRIMARY KEY,
    name        TEXT NOT NULL,
    essay_count INT NOT NULL DEFAULT 0,          -- 可实时计算，但保留字段方便排序
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_essay_labels_name ON essay_labels(name);

CREATE TRIGGER trg_essay_labels_updated_at
    BEFORE UPDATE ON essay_labels
    FOR EACH ROW EXECUTE FUNCTION update_essay_articles_updated_at();
		

-- essay_year_summaries: 年度汇总表
CREATE TABLE IF NOT EXISTS essay_year_summaries (
    year            INT PRIMARY KEY,
    essay_count     INT NOT NULL DEFAULT 0,
    word_count      INT NOT NULL DEFAULT 0,
    month_summaries JSONB NOT NULL DEFAULT '[]', -- [{"month":"1","essay_count":22,"word_count":3097}]
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);



-- booklet_styles: 打卡项目组表
CREATE TABLE IF NOT EXISTS booklet_styles (
    id                  UUID PRIMARY KEY,
    start_date          TIMESTAMPTZ NOT NULL,
    valid_check_in      INT NOT NULL DEFAULT 0,
    fully_done          INT NOT NULL DEFAULT 0,
    longest_streak      INT NOT NULL DEFAULT 0,
    longest_fully_streak INT NOT NULL DEFAULT 0,
    tasks               JSONB NOT NULL DEFAULT '[]',  -- 内嵌任务列表
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_booklet_styles_start ON booklet_styles(start_date);

CREATE TRIGGER trg_booklet_styles_updated_at
    BEFORE UPDATE ON booklet_styles
    FOR EACH ROW EXECUTE FUNCTION update_essay_articles_updated_at();
		

-- booklet_records: 每日打卡记录表
CREATE TABLE IF NOT EXISTS booklet_records (
    id              UUID PRIMARY KEY,
    style_id        UUID NOT NULL REFERENCES booklet_styles(id) ON DELETE CASCADE,
    date            DATE NOT NULL,
    message         TEXT NOT NULL DEFAULT '',
    task_completion JSONB NOT NULL DEFAULT '{}',  -- {"task_id": true/false, ...}
    mood            TEXT,                          -- 心情: happy/sad/.../null
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 同一天同一 style 只有一条记录
    CONSTRAINT uq_booklet_records_style_date UNIQUE (style_id, date)
);

CREATE INDEX idx_booklet_records_date ON booklet_records(date);
CREATE INDEX idx_booklet_records_style ON booklet_records(style_id);
CREATE INDEX idx_booklet_records_updated ON booklet_records(updated_at);

CREATE TRIGGER trg_booklet_records_updated_at
    BEFORE UPDATE ON booklet_records
    FOR EACH ROW EXECUTE FUNCTION update_essay_articles_updated_at();
```



