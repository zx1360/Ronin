# 关于MONARCH

**`GO`编写的http服务器, 用以支持另一个项目`TORRID`的网络请求.**

## 一、开源

[zx1360/monarch: Go编写的http服务器, 用以支持我另一个项目'torrid'的网络请求.](https://github.com/zx1360/monarch)

## 二、高性能 无感知后台运行

由于使用Go编写, 相比java/python开发的http服务器占用内存少, 响应高效, 后台友好.

可以编写vbs脚本放入开机启动目录以无窗口模式静默运行, 平时几乎不占用性能损耗

## 三、应用干净

一体式以独立目录存在, 所有数据均不存入C盘的文档目录之类的, 仅存于所在的目录中, 可方便地彻底删除.

**==因此, 应当自行做好数据的管理防止丢失数据==**

# 依赖的数据库

**PostgreSQL18.0**

如果要正确运行还需本地运行一个postgres数据库, (自用场景后台运行可忽略性能占用). 下面附上用到的数据表结构以及触发器定义.

## 漫画页数据库

### 建表

```postgresql
-- 漫画主表（存储单本漫画信息）
CREATE TABLE IF NOT EXISTS comic_books (
    id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    chapter_count INTEGER NOT NULL DEFAULT 0,
    image_count INTEGER NOT NULL DEFAULT 0, -- 该漫画总图片数
    cover_image TEXT -- 封面图相对路径（第一个章节的第一张图）
);

-- 漫画章节表（存储单本漫画的章节信息）
CREATE TABLE IF NOT EXISTS comic_chapters (
    id UUID PRIMARY KEY,
    comic_id VARCHAR(64) NOT NULL,
    dir_name VARCHAR(255) NOT NULL, -- 格式：001_章节名
    chapter_index INTEGER NOT NULL,
    image_count INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (comic_id) REFERENCES comic_books(id) ON DELETE CASCADE
);

-- 漫画图片表（存储章节下的图片路径及属性）
CREATE TABLE IF NOT EXISTS comic_images (
    id UUID PRIMARY KEY,
    chapter_id VARCHAR(64) NOT NULL,
    image_path TEXT NOT NULL,
    sort_num INTEGER NOT NULL, -- 图片排序号（1、2、3...）
    width INTEGER NOT NULL, -- 图片宽度
    height INTEGER NOT NULL, -- 图片高度
    FOREIGN KEY (chapter_id) REFERENCES comic_chapters(id) ON DELETE CASCADE
);

-- 漫画汇总表（存储所有漫画的统计信息）
CREATE TABLE IF NOT EXISTS comic_summary (
    id VARCHAR(64) PRIMARY KEY DEFAULT 'comic_total_metadata',
    title VARCHAR(255) NOT NULL DEFAULT '漫画信息元数据',
    book_count INTEGER NOT NULL DEFAULT 0,
    total_chapter_count INTEGER NOT NULL DEFAULT 0,
    total_image_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT comic_summary_single_row CHECK (id = 'comic_total_metadata')
);

-- 章节表：comic_id查询+排序索引
CREATE INDEX if not exists idx_comic_chapters_comic_id ON comics.comic_chapters (comic_id, chapter_index);
-- 图片表：chapter_id查询+排序索引
CREATE INDEX if not exists idx_comic_images_chapter_id ON comics.comic_images (chapter_id, sort_num);
```



## 藏品页数据库

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



# 其他说明

更详细的用法参考`TORRID`应用的使用:

`[zx1360/Torrid]` [https://github.com/zx1360/Torrid