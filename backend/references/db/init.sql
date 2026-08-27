-- =====================================================
-- 一键初始化脚本
-- 包含 schema、表、索引、函数、触发器
-- 适用 PostgreSQL 12+
-- =====================================================

\set ON_ERROR_STOP on

-- 创建 schema（如果不存在）
-- CREATE SCHEMA IF NOT EXISTS comics;
CREATE SCHEMA IF NOT EXISTS gallery;
CREATE SCHEMA IF NOT EXISTS user_data;

-- =====================================================
-- 通用函数：自动更新 updated_at 列
-- =====================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =====================================================
-- 原comics schema, 现comix. 且通过视图而非表访问. 以下为原表定义, 现在使用的是同结构的视图.
-- =====================================================

-- 漫画主表
CREATE TABLE IF NOT EXISTS comics.comic_books (
    id          UUID PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    cover_image TEXT,
    is_public   BOOLEAN NOT NULL DEFAULT TRUE,
    readed      BOOLEAN NOT NULL DEFAULT FALSE
);

-- 漫画章节表
CREATE TABLE IF NOT EXISTS comics.comic_chapters (
    id            UUID PRIMARY KEY,
    comic_id      UUID NOT NULL,
    dir_name      VARCHAR(255) NOT NULL,   -- 格式：001_章节名
    chapter_index INTEGER NOT NULL,
    FOREIGN KEY (comic_id) REFERENCES comics.comic_books(id) ON DELETE CASCADE
);

-- 漫画图片表
CREATE TABLE IF NOT EXISTS comics.comic_images (
    id          UUID PRIMARY KEY,
    chapter_id  UUID NOT NULL,
    image_path  TEXT NOT NULL,
    sort_num    INTEGER NOT NULL,
    width       INTEGER NOT NULL,
    height      INTEGER NOT NULL,
    FOREIGN KEY (chapter_id) REFERENCES comics.comic_chapters(id) ON DELETE CASCADE
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_comic_chapters_comic_id ON comics.comic_chapters (comic_id, chapter_index);
CREATE INDEX IF NOT EXISTS idx_comic_images_chapter_id ON comics.comic_images (chapter_id, sort_num);

-- =====================================================
-- gallery schema
-- =====================================================

-- 文件信息表
CREATE TABLE IF NOT EXISTS gallery.media_assets (
    id           UUID PRIMARY KEY,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    captured_at  TIMESTAMPTZ NOT NULL,
    file_path    TEXT NOT NULL,
    thumb_path   TEXT,
    preview_path TEXT,
    hash         BYTEA NOT NULL UNIQUE,
    size_bytes   BIGINT NOT NULL DEFAULT 0,
    mime_type    TEXT,
    is_deleted   BOOLEAN NOT NULL DEFAULT FALSE,
    sync_count   INTEGER NOT NULL DEFAULT 0,
    group_id     UUID DEFAULT NULL,
    message      TEXT DEFAULT NULL,
    edit_params  JSONB DEFAULT NULL,
    CONSTRAINT fk_group_id FOREIGN KEY (group_id) REFERENCES gallery.media_assets(id) ON DELETE SET NULL
);

-- media_assets 索引
CREATE INDEX IF NOT EXISTS idx_media_assets_sync_captured ON gallery.media_assets (is_deleted, sync_count, captured_at);
CREATE INDEX IF NOT EXISTS idx_media_assets_updated_at   ON gallery.media_assets (updated_at);
CREATE INDEX IF NOT EXISTS idx_media_assets_group_id     ON gallery.media_assets (group_id);
CREATE INDEX IF NOT EXISTS idx_media_assets_mime_type    ON gallery.media_assets (mime_type);

-- 标签表（树状结构）
CREATE TABLE IF NOT EXISTS gallery.tags (
    id         UUID PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    name       TEXT NOT NULL,
    parent_id  UUID,
    full_path  TEXT,
    CONSTRAINT fk_parent_id FOREIGN KEY (parent_id) REFERENCES gallery.tags(id) ON DELETE CASCADE,
    CONSTRAINT uk_tag_name_parent UNIQUE (name, parent_id)
);

-- tags 索引
CREATE INDEX IF NOT EXISTS idx_tags_parent_id  ON gallery.tags (parent_id);
CREATE INDEX IF NOT EXISTS idx_tags_full_path  ON gallery.tags (full_path);

-- 文件-标签关联表
CREATE TABLE IF NOT EXISTS gallery.media_tag_links (
    media_id UUID,
    tag_id   UUID,
    PRIMARY KEY (tag_id, media_id),
    CONSTRAINT fk_media_id FOREIGN KEY (media_id) REFERENCES gallery.media_assets(id) ON DELETE CASCADE,
    CONSTRAINT fk_tag_id   FOREIGN KEY (tag_id)   REFERENCES gallery.tags(id) ON DELETE CASCADE
);

-- media_tag_links 索引
CREATE INDEX IF NOT EXISTS idx_media_tag_links_media_id ON gallery.media_tag_links (media_id);

-- =====================================================
-- gallery tags 树状路径自动维护（函数+触发器）
-- =====================================================

-- 计算单个标签的 full_path
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

-- 递归更新所有子节点的 full_path
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

-- BEFORE INSERT/UPDATE 触发器函数
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

-- AFTER UPDATE 触发器函数（用于级联更新子节点）
CREATE OR REPLACE FUNCTION gallery.tags_after_upd()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.name IS DISTINCT FROM NEW.name OR OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
        PERFORM gallery.tags_cascade_update_full_path(NEW.id);
    END IF;
    RETURN NULL;
END;
$$;

-- 绑定触发器（先删除可能残留的旧触发器）
DROP TRIGGER IF EXISTS trg_tags_before_ins_upd ON gallery.tags;
DROP TRIGGER IF EXISTS trg_tags_after_upd ON gallery.tags;

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

-- gallery 表的 updated_at 自动更新触发器
CREATE TRIGGER trigger_media_assets_updated_at
    BEFORE UPDATE ON gallery.media_assets
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_tags_updated_at
    BEFORE UPDATE ON gallery.tags
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- user_data schema
-- =====================================================

-- 随笔文章表
CREATE TABLE IF NOT EXISTS user_data.essay_articles (
    id          UUID PRIMARY KEY,
    date        TIMESTAMPTZ NOT NULL,
    word_count  INT NOT NULL DEFAULT 0,
    content     TEXT NOT NULL DEFAULT '',
    imgs        TEXT[] NOT NULL DEFAULT '{}',
    labels      UUID[] NOT NULL DEFAULT '{}',
    messages    JSONB NOT NULL DEFAULT '[]',
    mood        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_essay_articles_date   ON user_data.essay_articles (date);
CREATE INDEX idx_essay_articles_labels ON user_data.essay_articles USING GIN (labels);
CREATE INDEX idx_essay_articles_mood   ON user_data.essay_articles (mood);
CREATE INDEX idx_essay_articles_updated ON user_data.essay_articles (updated_at);

-- 随笔标签表
CREATE TABLE IF NOT EXISTS user_data.essay_labels (
    id          UUID PRIMARY KEY,
    name        TEXT NOT NULL,
    essay_count INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_essay_labels_name ON user_data.essay_labels (name);

-- 年度汇总表
CREATE TABLE IF NOT EXISTS user_data.essay_year_summaries (
    year            INT PRIMARY KEY,
    essay_count     INT NOT NULL DEFAULT 0,
    word_count      INT NOT NULL DEFAULT 0,
    month_summaries JSONB NOT NULL DEFAULT '[]',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 打卡项目组表
CREATE TABLE IF NOT EXISTS user_data.booklet_styles (
    id                   UUID PRIMARY KEY,
    start_date           TIMESTAMPTZ NOT NULL,
    valid_check_in       INT NOT NULL DEFAULT 0,
    fully_done           INT NOT NULL DEFAULT 0,
    longest_streak       INT NOT NULL DEFAULT 0,
    longest_fully_streak INT NOT NULL DEFAULT 0,
    tasks                JSONB NOT NULL DEFAULT '[]',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_booklet_styles_start ON user_data.booklet_styles (start_date);

-- 每日打卡记录表
CREATE TABLE IF NOT EXISTS user_data.booklet_records (
    id               UUID PRIMARY KEY,
    style_id         UUID NOT NULL,
    date             DATE NOT NULL,
    message          TEXT NOT NULL DEFAULT '',
    task_completion  JSONB NOT NULL DEFAULT '{}',
    mood             TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_booklet_records_style_date UNIQUE (style_id, date),
    CONSTRAINT fk_booklet_records_style FOREIGN KEY (style_id) REFERENCES user_data.booklet_styles(id) ON DELETE CASCADE
);

CREATE INDEX idx_booklet_records_date   ON user_data.booklet_records (date);
CREATE INDEX idx_booklet_records_style  ON user_data.booklet_records (style_id);
CREATE INDEX idx_booklet_records_updated ON user_data.booklet_records (updated_at);

-- user_data 各表的 updated_at 自动更新触发器
CREATE TRIGGER trigger_essay_articles_updated_at
    BEFORE UPDATE ON user_data.essay_articles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_essay_labels_updated_at
    BEFORE UPDATE ON user_data.essay_labels
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_essay_year_summaries_updated_at
    BEFORE UPDATE ON user_data.essay_year_summaries
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_booklet_styles_updated_at
    BEFORE UPDATE ON user_data.booklet_styles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_booklet_records_updated_at
    BEFORE UPDATE ON user_data.booklet_records
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- 初始化完成
-- =====================================================