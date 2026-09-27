-- Monarch 数据库结构（SQLite 单文件，幂等可重复执行）。
--
-- 命名规则：表名 = 原 PostgreSQL 的 schema 与表名用下划线连接（SQLite 没有 schema）。
-- comix_* 由 backend/gizmos/comix 的 Python 侧建表与维护，此处不涉及。
--
-- 约定：
--   * 时间列一律 TEXT，格式见 model.TimeFormat（UTC / 毫秒 / 定宽，字典序即时序）。
--     仅日期的列用 'YYYY-MM-DD'。
--   * 布尔列用 INTEGER 0/1，数组列用 JSON 文本（需要按元素检索时用 json_each）。
--   * 主键统一用 TEXT 存 UUID。
--   * updated_at 由 Go 侧显式写入（不再有触发器），因此每次 UPDATE 都必须带上它。
--   * 用户数据用 deleted_at 墓碑表达删除，不做物理删除（见 /API/user-data/sync 的逐行合并）。

-- =====================================================
-- gallery：媒体库
-- =====================================================

CREATE TABLE IF NOT EXISTS gallery_media_assets (
    id           TEXT PRIMARY KEY,
    created_at   TEXT NOT NULL,
    updated_at   TEXT NOT NULL,
    captured_at  TEXT NOT NULL,
    file_path    TEXT NOT NULL,
    thumb_path   TEXT,
    preview_path TEXT,
    hash         BLOB NOT NULL UNIQUE,
    size_bytes   INTEGER NOT NULL DEFAULT 0,
    mime_type    TEXT,
    is_deleted   INTEGER NOT NULL DEFAULT 0,
    sync_count   INTEGER NOT NULL DEFAULT 0,
    group_id     TEXT REFERENCES gallery_media_assets(id) ON DELETE SET NULL,
    message      TEXT,
    edit_params  TEXT
);

CREATE INDEX IF NOT EXISTS idx_gallery_media_assets_sync_captured
    ON gallery_media_assets (is_deleted, sync_count, captured_at);
CREATE INDEX IF NOT EXISTS idx_gallery_media_assets_updated_at ON gallery_media_assets (updated_at);
CREATE INDEX IF NOT EXISTS idx_gallery_media_assets_captured_at ON gallery_media_assets (captured_at);
CREATE INDEX IF NOT EXISTS idx_gallery_media_assets_group_id ON gallery_media_assets (group_id);
CREATE INDEX IF NOT EXISTS idx_gallery_media_assets_mime_type ON gallery_media_assets (mime_type);

-- 标签树。full_path 与 updated_at 由 Go 侧维护（原 PostgreSQL 触发器上移）。
CREATE TABLE IF NOT EXISTS gallery_tags (
    id          TEXT PRIMARY KEY,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    name        TEXT NOT NULL,
    parent_id   TEXT REFERENCES gallery_tags(id) ON DELETE CASCADE,
    full_path   TEXT NOT NULL DEFAULT '',
    is_favorite INTEGER NOT NULL DEFAULT 0,
    UNIQUE (name, parent_id)
);

CREATE INDEX IF NOT EXISTS idx_gallery_tags_parent_id ON gallery_tags (parent_id);
CREATE INDEX IF NOT EXISTS idx_gallery_tags_full_path ON gallery_tags (full_path);

CREATE TABLE IF NOT EXISTS gallery_media_tag_links (
    media_id TEXT NOT NULL REFERENCES gallery_media_assets(id) ON DELETE CASCADE,
    tag_id   TEXT NOT NULL REFERENCES gallery_tags(id) ON DELETE CASCADE,
    PRIMARY KEY (tag_id, media_id)
);

CREATE INDEX IF NOT EXISTS idx_gallery_media_tag_links_media_id ON gallery_media_tag_links (media_id);

-- =====================================================
-- user_data：随笔与打卡（两端可写，逐行按 updated_at 合并）
-- =====================================================

CREATE TABLE IF NOT EXISTS user_data_essay_articles (
    id         TEXT PRIMARY KEY,
    date       TEXT NOT NULL,
    word_count INTEGER NOT NULL DEFAULT 0,
    content    TEXT NOT NULL DEFAULT '',
    imgs       TEXT NOT NULL DEFAULT '[]',     -- JSON 数组（图片文件名）
    labels     TEXT NOT NULL DEFAULT '[]',     -- JSON 数组（标签 UUID）
    messages   TEXT NOT NULL DEFAULT '[]',     -- JSON 数组
    mood       TEXT,
    deleted_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_data_essay_articles_date ON user_data_essay_articles (date);
CREATE INDEX IF NOT EXISTS idx_user_data_essay_articles_mood ON user_data_essay_articles (mood);
CREATE INDEX IF NOT EXISTS idx_user_data_essay_articles_updated ON user_data_essay_articles (updated_at);

CREATE TABLE IF NOT EXISTS user_data_essay_labels (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    essay_count INTEGER NOT NULL DEFAULT 0,
    deleted_at  TEXT,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_data_essay_labels_name ON user_data_essay_labels (name);
CREATE INDEX IF NOT EXISTS idx_user_data_essay_labels_updated ON user_data_essay_labels (updated_at);

CREATE TABLE IF NOT EXISTS user_data_essay_year_summaries (
    year            INTEGER PRIMARY KEY,
    essay_count     INTEGER NOT NULL DEFAULT 0,
    word_count      INTEGER NOT NULL DEFAULT 0,
    month_summaries TEXT NOT NULL DEFAULT '[]',
    deleted_at      TEXT,
    updated_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_data_booklet_styles (
    id                   TEXT PRIMARY KEY,
    start_date           TEXT NOT NULL,        -- 'YYYY-MM-DD'
    valid_check_in       INTEGER NOT NULL DEFAULT 0,
    fully_done           INTEGER NOT NULL DEFAULT 0,
    longest_streak       INTEGER NOT NULL DEFAULT 0,
    longest_fully_streak INTEGER NOT NULL DEFAULT 0,
    tasks                TEXT NOT NULL DEFAULT '[]',
    deleted_at           TEXT,
    created_at           TEXT NOT NULL,
    updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_data_booklet_styles_start ON user_data_booklet_styles (start_date);
CREATE INDEX IF NOT EXISTS idx_user_data_booklet_styles_updated ON user_data_booklet_styles (updated_at);

-- (style_id, date) 是打卡记录的业务主键：同一天同项目组只有一条，
-- 墓碑保留在同一行上，客户端重建时按此冲突键覆盖即可复活。
CREATE TABLE IF NOT EXISTS user_data_booklet_records (
    id              TEXT PRIMARY KEY,
    style_id        TEXT NOT NULL REFERENCES user_data_booklet_styles(id) ON DELETE CASCADE,
    date            TEXT NOT NULL,             -- 'YYYY-MM-DD'
    message         TEXT NOT NULL DEFAULT '',
    task_completion TEXT NOT NULL DEFAULT '{}',
    mood            TEXT,
    deleted_at      TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,
    UNIQUE (style_id, date)
);

CREATE INDEX IF NOT EXISTS idx_user_data_booklet_records_date ON user_data_booklet_records (date);
CREATE INDEX IF NOT EXISTS idx_user_data_booklet_records_style ON user_data_booklet_records (style_id);
CREATE INDEX IF NOT EXISTS idx_user_data_booklet_records_updated ON user_data_booklet_records (updated_at);

-- =====================================================
-- ai：本地 AI 处理层
-- =====================================================

-- 单媒体标量结果（一媒体一行，各能力列可独立为空）。
CREATE TABLE IF NOT EXISTS ai_media (
    media_id   TEXT PRIMARY KEY REFERENCES gallery_media_assets(id) ON DELETE CASCADE,
    phash      INTEGER,                        -- 64 位感知哈希
    ocr_text   TEXT,
    caption    TEXT,
    vlm_tags   TEXT NOT NULL DEFAULT '[]',     -- JSON 数组，与人工标签物理隔离
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_media_phash ON ai_media (phash);

-- 结果溯源：每条 (媒体, 能力) 记录它是用哪个输入档位、哪个执行者算出来的。
-- 期望规格与之不符时由 reconcile 循环自动重排（见 service/ai/spec.go）。
CREATE TABLE IF NOT EXISTS ai_results (
    media_id   TEXT NOT NULL REFERENCES gallery_media_assets(id) ON DELETE CASCADE,
    capability TEXT NOT NULL,                  -- phash / embed / face / ocr / vlm
    input_tier TEXT NOT NULL,                  -- preview256 / ai1024
    executor   TEXT NOT NULL,                  -- 能力实现或模型标识
    updated_at TEXT NOT NULL,
    PRIMARY KEY (media_id, capability)
);

CREATE INDEX IF NOT EXISTS idx_ai_results_spec ON ai_results (capability, input_tier, executor);

-- 向量以 int8 量化 + 反量化系数存储，检索在 Go 侧精确扫描（不需要向量扩展）。
CREATE TABLE IF NOT EXISTS ai_embeddings (
    media_id   TEXT NOT NULL REFERENCES gallery_media_assets(id) ON DELETE CASCADE,
    kind       TEXT NOT NULL,                  -- 目前仅 'image'
    model      TEXT NOT NULL,                  -- 与 ai_results.executor 一致
    dim        INTEGER NOT NULL,
    scale      REAL NOT NULL,
    vec        BLOB NOT NULL,                  -- dim 字节 int8
    updated_at TEXT NOT NULL,
    PRIMARY KEY (media_id, kind, model)
);

CREATE INDEX IF NOT EXISTS idx_ai_embeddings_model ON ai_embeddings (model, kind);

-- 先建 faces（其 person_id 指向尚未建立的 persons，SQLite 只在实际写入时校验外键）。
CREATE TABLE IF NOT EXISTS ai_faces (
    id         TEXT PRIMARY KEY,
    media_id   TEXT NOT NULL REFERENCES gallery_media_assets(id) ON DELETE CASCADE,
    person_id  TEXT REFERENCES ai_persons(id) ON DELETE SET NULL,
    bbox       TEXT NOT NULL DEFAULT '[]',     -- JSON 数组 [x1,y1,x2,y2]，归一化
    det_score  REAL NOT NULL DEFAULT 0,
    quality    REAL NOT NULL DEFAULT 0,
    embedding  BLOB NOT NULL,                  -- 512 维 float32 小端
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_faces_media_id ON ai_faces (media_id);
CREATE INDEX IF NOT EXISTS idx_ai_faces_person_id ON ai_faces (person_id);

CREATE TABLE IF NOT EXISTS ai_persons (
    id            TEXT PRIMARY KEY,
    name          TEXT,
    cover_face_id TEXT REFERENCES ai_faces(id) ON DELETE SET NULL,
    face_count    INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);

-- 任务队列：一行 = 一个 (能力, 媒体) 处理单元；UNIQUE 保证重复入队幂等。
-- 认领在写池单连接内串行完成，因此无需 PostgreSQL 的 FOR UPDATE SKIP LOCKED。
CREATE TABLE IF NOT EXISTS ai_jobs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    capability  TEXT NOT NULL,
    media_id    TEXT NOT NULL REFERENCES gallery_media_assets(id) ON DELETE CASCADE,
    status      TEXT NOT NULL DEFAULT 'pending',  -- pending/running/done/failed
    priority    INTEGER NOT NULL DEFAULT 100,     -- 越小越先处理
    attempts    INTEGER NOT NULL DEFAULT 0,
    last_error  TEXT,
    started_at  TEXT,
    finished_at TEXT,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    UNIQUE (capability, media_id)
);

CREATE INDEX IF NOT EXISTS idx_ai_jobs_claim ON ai_jobs (capability, status, priority, id);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_media ON ai_jobs (media_id);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_updated ON ai_jobs (updated_at);

-- 去重的人工判定：「非重复」标记，删除本表记录即可恢复原有分组。
CREATE TABLE IF NOT EXISTS ai_duplicate_ignores (
    media_id   TEXT PRIMARY KEY REFERENCES gallery_media_assets(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_duplicate_ignores_created ON ai_duplicate_ignores (created_at);

-- 近期回顾：由后端算确定性统计，再交本地模型生成叙述，结果按输入指纹缓存。
CREATE TABLE IF NOT EXISTS ai_reviews (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    kind        TEXT NOT NULL,                 -- 目前仅 'recent'
    scope_key   TEXT NOT NULL,                 -- 统计范围的确定性指纹
    preset_id   TEXT NOT NULL DEFAULT '',      -- 使用的语气/角色预设
    model       TEXT NOT NULL,
    stats       TEXT NOT NULL,                 -- JSON：后端算出的确定性统计
    narrative   TEXT NOT NULL,                 -- 模型生成的叙述
    created_at  TEXT NOT NULL,
    UNIQUE (kind, scope_key, preset_id, model)
);

CREATE INDEX IF NOT EXISTS idx_ai_reviews_created ON ai_reviews (created_at);

-- 语气与角色预设（可在前端编辑，默认全本地不外发）。
CREATE TABLE IF NOT EXISTS ai_review_presets (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    tone       TEXT NOT NULL DEFAULT '',
    role       TEXT NOT NULL DEFAULT '',
    is_default INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- =====================================================
-- app_settings：运行时配置（.env 只保留连库前必须知道的项）
-- =====================================================

CREATE TABLE IF NOT EXISTS app_settings (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
