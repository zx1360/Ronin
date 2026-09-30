-- =====================================================
-- Monarch / Gizmos / comix 共用单文件 SQLite 数据库（幂等，可重复执行）
--
-- 设计约定：
--   1. 单文件、应用目录下（backend/data/monarch.db），无外部数据库服务；
--      SQLite 无 schema 概念，comix 的表统一加 `comic_` 前缀避免与其它模块撞名。
--   2. 时间统一存**本机本地时区**的 ISO 文本 'YYYY-MM-DD HH:MM:SS.SSS'：
--      与 PostgreSQL 会话时区（= 本机时区）下 DATE()/EXTRACT() 的语义一致，
--      定宽且无时区后缀，字典序即时间序；SQLite 的 date/strftime 可直接解析。
--   3. UUID 存 36 字符小写 TEXT；BYTEA 存 BLOB；jsonb 与 text[] 存 JSON 文本
--      （vlm_tags 例外：拆到 media_ai_tags，便于按标签索引与聚合）。
--   4. updated_at 由 AFTER UPDATE 触发器维护（SQLite 无 BEFORE 触发器）；
--      触发器带 `NEW.updated_at IS OLD.updated_at` 守卫，显式赋值时不再覆盖，
--      同时避免开启 recursive_triggers 后自递归。
--   5. 写入按单写者模型：WAL 日志 + busy_timeout + _txlock=immediate（连接串控制）。
-- =====================================================

PRAGMA user_version = 1;
PRAGMA foreign_keys = ON;

-- =====================================================
-- gallery：媒体资产与标签
-- =====================================================

CREATE TABLE IF NOT EXISTS media_assets (
    id           TEXT PRIMARY KEY,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    captured_at  TEXT NOT NULL,
    file_path    TEXT NOT NULL,
    thumb_path   TEXT,
    preview_path TEXT,
    hash         BLOB NOT NULL UNIQUE,
    size_bytes   INTEGER NOT NULL DEFAULT 0,
    mime_type    TEXT,
    is_deleted   INTEGER NOT NULL DEFAULT 0,
    sync_count   INTEGER NOT NULL DEFAULT 0,
    group_id     TEXT DEFAULT NULL REFERENCES media_assets(id) ON DELETE SET NULL,
    message      TEXT DEFAULT NULL,
    edit_params  TEXT DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_media_assets_sync_captured ON media_assets (is_deleted, sync_count, captured_at);
CREATE INDEX IF NOT EXISTS idx_media_assets_captured    ON media_assets (is_deleted, captured_at);
-- 覆盖索引：AI "尚无产物" 统计（CountMediaMissingAll）外层只需 (is_deleted, id)，
-- 覆盖后可完全走索引（实测 3.1s → 0.3s），否则每行都要回表取 id。
CREATE INDEX IF NOT EXISTS idx_media_assets_deleted_id  ON media_assets (is_deleted, id);
CREATE INDEX IF NOT EXISTS idx_media_assets_updated_at    ON media_assets (updated_at);
CREATE INDEX IF NOT EXISTS idx_media_assets_group_id      ON media_assets (group_id);
CREATE INDEX IF NOT EXISTS idx_media_assets_mime_type     ON media_assets (mime_type);

-- 标签表（树状结构）；full_path 与子孙级联由 Go 侧维护（见 gallery_repo）
CREATE TABLE IF NOT EXISTS tags (
    id          TEXT PRIMARY KEY,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    name        TEXT NOT NULL,
    parent_id   TEXT DEFAULT NULL REFERENCES tags(id) ON DELETE CASCADE,
    full_path   TEXT,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    UNIQUE (name, parent_id)
);

CREATE INDEX IF NOT EXISTS idx_tags_parent_id ON tags (parent_id);
CREATE INDEX IF NOT EXISTS idx_tags_full_path ON tags (full_path);

CREATE TABLE IF NOT EXISTS media_tag_links (
    media_id TEXT NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
    tag_id   TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (tag_id, media_id)
);

CREATE INDEX IF NOT EXISTS idx_media_tag_links_media_id ON media_tag_links (media_id);

-- =====================================================
-- user_data：随笔与打卡
-- 原 text[] / jsonb 列统一存 JSON 文本，读写整列，语义不变。
-- =====================================================

CREATE TABLE IF NOT EXISTS essay_articles (
    id         TEXT PRIMARY KEY,
    date       TEXT NOT NULL,
    word_count INTEGER NOT NULL DEFAULT 0,
    content    TEXT NOT NULL DEFAULT '',
    imgs       TEXT NOT NULL DEFAULT '[]',
    labels     TEXT NOT NULL DEFAULT '[]',
    messages   TEXT NOT NULL DEFAULT '[]',
    mood       TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_essay_articles_date    ON essay_articles (date);
CREATE INDEX IF NOT EXISTS idx_essay_articles_mood    ON essay_articles (mood);
CREATE INDEX IF NOT EXISTS idx_essay_articles_updated ON essay_articles (updated_at);

CREATE TABLE IF NOT EXISTS essay_labels (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    essay_count INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_essay_labels_name ON essay_labels (name);

CREATE TABLE IF NOT EXISTS essay_year_summaries (
    year            INTEGER PRIMARY KEY,
    essay_count     INTEGER NOT NULL DEFAULT 0,
    word_count      INTEGER NOT NULL DEFAULT 0,
    month_summaries TEXT NOT NULL DEFAULT '[]',
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS booklet_styles (
    id                   TEXT PRIMARY KEY,
    start_date           TEXT NOT NULL,
    valid_check_in       INTEGER NOT NULL DEFAULT 0,
    fully_done           INTEGER NOT NULL DEFAULT 0,
    longest_streak       INTEGER NOT NULL DEFAULT 0,
    longest_fully_streak INTEGER NOT NULL DEFAULT 0,
    tasks                TEXT NOT NULL DEFAULT '[]',
    created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_booklet_styles_start ON booklet_styles (start_date);

CREATE TABLE IF NOT EXISTS booklet_records (
    id              TEXT PRIMARY KEY,
    style_id        TEXT NOT NULL REFERENCES booklet_styles(id) ON DELETE CASCADE,
    date            TEXT NOT NULL,
    message         TEXT NOT NULL DEFAULT '',
    task_completion TEXT NOT NULL DEFAULT '{}',
    mood            TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    UNIQUE (style_id, date)
);

CREATE INDEX IF NOT EXISTS idx_booklet_records_date    ON booklet_records (date);
CREATE INDEX IF NOT EXISTS idx_booklet_records_style   ON booklet_records (style_id);
CREATE INDEX IF NOT EXISTS idx_booklet_records_updated ON booklet_records (updated_at);

-- =====================================================
-- ai：本地 AI 处理层
-- =====================================================

CREATE TABLE IF NOT EXISTS media_ai (
    media_id   TEXT PRIMARY KEY REFERENCES media_assets(id) ON DELETE CASCADE,
    phash      INTEGER,          -- 64 位感知哈希；-1 表示无法解码
    ocr_text   TEXT,             -- OCR 全文（多行拼接）
    caption    TEXT,             -- VLM 一句话描述
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_media_ai_phash ON media_ai (phash);

-- AI 标签：替代 PG 的 ai.media_ai.vlm_tags text[]（数组包含/重叠 → 关系表）。
CREATE TABLE IF NOT EXISTS media_ai_tags (
    media_id TEXT NOT NULL REFERENCES media_ai(media_id) ON DELETE CASCADE,
    tag      TEXT NOT NULL,
    PRIMARY KEY (media_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_media_ai_tags_tag ON media_ai_tags (tag);

-- 向量：int8 量化存 BLOB，检索在 Go 侧内存精确扫描（无需 pgvector）
CREATE TABLE IF NOT EXISTS embeddings (
    media_id   TEXT NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
    kind       TEXT NOT NULL,
    model      TEXT NOT NULL,
    dim        INTEGER NOT NULL,
    scale      REAL NOT NULL,
    vec        BLOB NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    PRIMARY KEY (media_id, kind, model)
);

CREATE INDEX IF NOT EXISTS idx_embeddings_model ON embeddings (model, kind);

CREATE TABLE IF NOT EXISTS persons (
    id            TEXT PRIMARY KEY,
    name          TEXT,
    cover_face_id TEXT REFERENCES faces(id) ON DELETE SET NULL,
    face_count    INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS faces (
    id         TEXT PRIMARY KEY,
    media_id   TEXT NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
    person_id  TEXT REFERENCES persons(id) ON DELETE SET NULL,
    bbox       TEXT NOT NULL,        -- JSON [x1,y1,x2,y2]（归一化）
    det_score  REAL NOT NULL DEFAULT 0,
    quality    REAL NOT NULL DEFAULT 0,
    embedding  BLOB NOT NULL,        -- 512 维 float32（2048 字节）
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_faces_media_id  ON faces (media_id);
CREATE INDEX IF NOT EXISTS idx_faces_person_id ON faces (person_id);

-- 任务队列：一行 = 一个 (能力, 媒体)；UNIQUE 保证重复入队幂等。
CREATE TABLE IF NOT EXISTS jobs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    capability  TEXT NOT NULL,
    media_id    TEXT NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
    status      TEXT NOT NULL DEFAULT 'pending',
    priority    INTEGER NOT NULL DEFAULT 100,
    attempts    INTEGER NOT NULL DEFAULT 0,
    last_error  TEXT,
    started_at  TEXT,
    finished_at TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    UNIQUE (capability, media_id)
);

CREATE INDEX IF NOT EXISTS idx_jobs_claim   ON jobs (capability, status, priority, id);
CREATE INDEX IF NOT EXISTS idx_jobs_media   ON jobs (media_id);
CREATE INDEX IF NOT EXISTS idx_jobs_updated ON jobs (updated_at);

-- 去重人工判定："非重复"标记；删除本表记录即可完全恢复原有分组结果。
CREATE TABLE IF NOT EXISTS duplicate_ignores (
    media_id   TEXT PRIMARY KEY REFERENCES media_assets(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_duplicate_ignores_created ON duplicate_ignores (created_at);

-- 运行时设置（能力开关、VLM 模型选择）
CREATE TABLE IF NOT EXISTS settings (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

-- =====================================================
-- comix：漫画爬虫（原 comix schema，与 comix Python 项目共用）
-- =====================================================

CREATE TABLE IF NOT EXISTS comic_sites (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    code       TEXT NOT NULL UNIQUE,
    name       TEXT NOT NULL,
    base_url   TEXT NOT NULL DEFAULT '',
    enabled    INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS comics (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    title             TEXT NOT NULL,
    title_normalized  TEXT NOT NULL DEFAULT '',
    site_id           INTEGER NOT NULL REFERENCES comic_sites(id),
    site_comic_id     TEXT NOT NULL DEFAULT '',
    detail_url        TEXT NOT NULL,
    author            TEXT NOT NULL DEFAULT '',
    status            TEXT NOT NULL DEFAULT '',
    cover_url         TEXT NOT NULL DEFAULT '',
    total_chapters    INTEGER NOT NULL DEFAULT 0,
    max_chapter_no    INTEGER NOT NULL DEFAULT 0,
    rel_dir           TEXT NOT NULL DEFAULT '',
    is_public         INTEGER NOT NULL DEFAULT 1,
    readed            INTEGER NOT NULL DEFAULT 0,
    cover_image       TEXT NOT NULL DEFAULT '',
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    UNIQUE (site_id, site_comic_id)
);

CREATE TABLE IF NOT EXISTS comic_chapters (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    comic_id    INTEGER NOT NULL REFERENCES comics(id) ON DELETE CASCADE,
    site_id     INTEGER NOT NULL REFERENCES comic_sites(id),
    chapter_no  INTEGER NOT NULL,
    title       TEXT NOT NULL DEFAULT '',
    url         TEXT NOT NULL UNIQUE,
    page_count  INTEGER NOT NULL DEFAULT 0,
    rel_dir     TEXT NOT NULL DEFAULT '',
    status      TEXT NOT NULL DEFAULT 'pending',
    error       TEXT NOT NULL DEFAULT '',
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    UNIQUE (comic_id, chapter_no)
);

CREATE INDEX IF NOT EXISTS idx_comic_chapters_comic ON comic_chapters (comic_id);

CREATE TABLE IF NOT EXISTS comic_images (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    chapter_id INTEGER NOT NULL REFERENCES comic_chapters(id) ON DELETE CASCADE,
    sort_num   INTEGER NOT NULL,
    file_name  TEXT NOT NULL,
    width      INTEGER NOT NULL DEFAULT 0,
    height     INTEGER NOT NULL DEFAULT 0,
    UNIQUE (chapter_id, sort_num)
);

CREATE INDEX IF NOT EXISTS idx_comic_images_chapter ON comic_images (chapter_id);

CREATE TABLE IF NOT EXISTS comic_download_tasks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    comic_id    INTEGER NOT NULL REFERENCES comics(id) ON DELETE CASCADE,
    chapter_id  INTEGER NOT NULL REFERENCES comic_chapters(id) ON DELETE CASCADE,
    status      TEXT NOT NULL DEFAULT 'queued',
    image_count INTEGER NOT NULL DEFAULT 0,
    error       TEXT NOT NULL DEFAULT '',
    started_at  TEXT,
    finished_at TEXT,
    UNIQUE (chapter_id)
);

CREATE INDEX IF NOT EXISTS idx_comic_download_tasks_chapter ON comic_download_tasks (chapter_id);

CREATE TABLE IF NOT EXISTS comic_aliases (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    comic_id INTEGER NOT NULL REFERENCES comics(id) ON DELETE CASCADE,
    name     TEXT NOT NULL,
    UNIQUE (comic_id, name)
);

-- =====================================================
-- updated_at 自动维护（AFTER UPDATE + 守卫；显式赋值时不覆盖）
-- =====================================================

CREATE TRIGGER IF NOT EXISTS trg_media_assets_updated_at AFTER UPDATE ON media_assets FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE media_assets SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_tags_updated_at AFTER UPDATE ON tags FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE tags SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_essay_articles_updated_at AFTER UPDATE ON essay_articles FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE essay_articles SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_essay_labels_updated_at AFTER UPDATE ON essay_labels FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE essay_labels SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_essay_year_summaries_updated_at AFTER UPDATE ON essay_year_summaries FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE essay_year_summaries SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE year = NEW.year;
END;

CREATE TRIGGER IF NOT EXISTS trg_booklet_styles_updated_at AFTER UPDATE ON booklet_styles FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE booklet_styles SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_booklet_records_updated_at AFTER UPDATE ON booklet_records FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE booklet_records SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_media_ai_updated_at AFTER UPDATE ON media_ai FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE media_ai SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE media_id = NEW.media_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_embeddings_updated_at AFTER UPDATE ON embeddings FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE embeddings SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')
    WHERE media_id = NEW.media_id AND kind = NEW.kind AND model = NEW.model;
END;

CREATE TRIGGER IF NOT EXISTS trg_persons_updated_at AFTER UPDATE ON persons FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE persons SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_jobs_updated_at AFTER UPDATE ON jobs FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE jobs SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_settings_updated_at AFTER UPDATE ON settings FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE settings SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE key = NEW.key;
END;

-- comic 基表的 updated_at 由 Python 侧显式维护（沿用原有 `updated_at = now()` 写法），
-- 这里同样加守卫触发器，避免两侧行为不一致。
CREATE TRIGGER IF NOT EXISTS trg_comics_updated_at AFTER UPDATE ON comics FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE comics SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_comic_chapters_updated_at AFTER UPDATE ON comic_chapters FOR EACH ROW
WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE comic_chapters SET updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime') WHERE id = NEW.id;
END;
