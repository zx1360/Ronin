-- Monarch 和 Gallery 的非漫画 schema。升级入口见 backend/AGENTS_DB.md。


-- gallery：媒体资产与标签

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
    last_processed_request TEXT,
    group_id     TEXT DEFAULT NULL REFERENCES media_assets(id) ON DELETE SET NULL,
    message      TEXT DEFAULT NULL,
    edit_params  TEXT DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_media_assets_sync_captured ON media_assets (is_deleted, sync_count, captured_at);
CREATE INDEX IF NOT EXISTS idx_media_assets_captured    ON media_assets (is_deleted, captured_at);
-- AI 缺产物诊断用此覆盖索引扫描未删除媒体。
CREATE INDEX IF NOT EXISTS idx_media_assets_deleted_id  ON media_assets (is_deleted, id);
CREATE INDEX IF NOT EXISTS idx_media_assets_updated_at    ON media_assets (updated_at);
CREATE INDEX IF NOT EXISTS idx_media_assets_group_id      ON media_assets (group_id);
CREATE INDEX IF NOT EXISTS idx_media_assets_mime_type     ON media_assets (mime_type);

CREATE TABLE IF NOT EXISTS gallery_library (
    slot INTEGER PRIMARY KEY CHECK (slot = 1),
    id TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS gallery_processed_requests (
    request_id TEXT PRIMARY KEY,
    media_ids_hash BLOB NOT NULL
) WITHOUT ROWID;

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

-- user_data：随笔与打卡

CREATE TABLE IF NOT EXISTS essay_articles (
    id         TEXT PRIMARY KEY,
    date       TEXT NOT NULL,
    word_count INTEGER NOT NULL DEFAULT 0,
    content    TEXT NOT NULL DEFAULT '',
    title      TEXT NOT NULL DEFAULT '',
    imgs       TEXT NOT NULL DEFAULT '[]',
    labels     TEXT NOT NULL DEFAULT '[]',
    messages   TEXT NOT NULL DEFAULT '[]',
    mood       TEXT,
    labels_updated_at TEXT,
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
    parent_id   TEXT,
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

CREATE TABLE IF NOT EXISTS user_data_changes (
    revision   INTEGER PRIMARY KEY AUTOINCREMENT,
    module     TEXT NOT NULL,
    collection TEXT NOT NULL,
    row_id     TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted    INTEGER NOT NULL DEFAULT 0 CHECK (deleted IN (0,1)),
    UNIQUE (module, collection, row_id)
);
CREATE INDEX IF NOT EXISTS idx_user_data_changes_cursor ON user_data_changes(module, revision);

-- ai：本地 AI 处理层

-- input_sig 记录输入档位与执行者，用于追溯产物及报告配置差异。
CREATE TABLE IF NOT EXISTS media_ai (
    media_id          TEXT PRIMARY KEY REFERENCES media_assets(id) ON DELETE CASCADE,
    phash             INTEGER,   -- 64 位感知哈希；-1 表示无法解码
    phash_input_sig   TEXT,
    ocr_text          TEXT,      -- OCR 全文（多行拼接）
    ocr_input_sig     TEXT,
    caption           TEXT,      -- VLM 一句话描述
    caption_input_sig TEXT,
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_media_ai_phash ON media_ai (phash);

CREATE TABLE IF NOT EXISTS media_ai_tags (
    media_id TEXT NOT NULL REFERENCES media_ai(media_id) ON DELETE CASCADE,
    tag      TEXT NOT NULL,
    PRIMARY KEY (media_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_media_ai_tags_tag ON media_ai_tags (tag);

-- 向量为 int8 量化 BLOB，检索由 Go 做精确扫描。
CREATE TABLE IF NOT EXISTS embeddings (
    media_id   TEXT NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
    kind       TEXT NOT NULL,
    model      TEXT NOT NULL,
    dim        INTEGER NOT NULL,
    scale      REAL NOT NULL,
    vec        BLOB NOT NULL,
    input_sig  TEXT,
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
    input_sig  TEXT,
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
    input_sig   TEXT,
    started_at  TEXT,
    finished_at TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
    UNIQUE (capability, media_id)
);

CREATE INDEX IF NOT EXISTS idx_jobs_claim   ON jobs (capability, status, priority, id);
CREATE INDEX IF NOT EXISTS idx_jobs_media   ON jobs (media_id);
CREATE INDEX IF NOT EXISTS idx_jobs_updated ON jobs (updated_at);

-- 人工保留的媒体同时排除于近重复与低价值推荐。
CREATE TABLE IF NOT EXISTS duplicate_ignores (
    media_id   TEXT PRIMARY KEY REFERENCES media_assets(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_duplicate_ignores_created ON duplicate_ignores (created_at);

CREATE TABLE IF NOT EXISTS deletion_candidates (
    media_id TEXT PRIMARY KEY REFERENCES media_assets(id) ON DELETE CASCADE,
    reason   TEXT NOT NULL
);

-- 运行时设置（能力开关、VLM 模型选择）
CREATE TABLE IF NOT EXISTS settings (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS trace_backup (
    id       INTEGER PRIMARY KEY CHECK (id = 1),
    revision INTEGER NOT NULL CHECK (revision > 0),
    snapshot TEXT NOT NULL CHECK (json_valid(snapshot))
);

-- updated_at 自动维护（AFTER UPDATE + 守卫；显式赋值时不覆盖）

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

