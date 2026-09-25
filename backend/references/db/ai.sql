-- =====================================================
-- AI 智能媒体处理层（幂等，可重复执行）
--
-- 设计约定：
--   1. 全部对象只存在于 `ai` schema 内，不修改 gallery / user_data / comix 的任何既有对象；
--      整体回滚 = 执行 references/db/ai_rollback.sql（DROP SCHEMA ai CASCADE）。
--   2. pg_trgm 扩展显式装入 ai schema（而非 public），使其成为可整体回收的一部分。
--   3. 仅对 gallery.media_assets 建外键引用，不带任何反向触发器/列改动。
--   4. AI 结果与人工数据物理隔离：人工标签在 gallery.tags，AI 标签在 ai.media_ai.vlm_tags，
--      二者天然可区分，不会互相覆盖。
-- =====================================================

\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS ai;

-- pg_trgm 供 OCR/描述文本的子串检索使用（contrib 内置，无需编译安装）
CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA ai;

-- updated_at 自动维护函数：本 schema 自带一份，不依赖 public 下的同名函数。
-- （生产库的 gallery / user_data 各自持有自己的副本，沿用同样的约定。）
CREATE OR REPLACE FUNCTION ai.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =====================================================
-- 单媒体 AI 标量结果（一媒体一行，各能力列可独立为空）
-- =====================================================
CREATE TABLE IF NOT EXISTS ai.media_ai (
    media_id   UUID PRIMARY KEY REFERENCES gallery.media_assets(id) ON DELETE CASCADE,
    -- pHash 感知哈希（64 位；-1 表示无法解码）
    phash      BIGINT,
    -- OCR 全文（多行文本直接拼接）
    ocr_text   TEXT,
    -- Ollama VLM 生成的一句话描述
    caption    TEXT,
    -- Ollama VLM 生成的关键词（与人工标签隔离）
    vlm_tags   TEXT[] NOT NULL DEFAULT '{}',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_media_ai_phash    ON ai.media_ai (phash);
CREATE INDEX IF NOT EXISTS idx_media_ai_vlm_tags ON ai.media_ai USING GIN (vlm_tags);
CREATE INDEX IF NOT EXISTS idx_media_ai_ocr_trgm ON ai.media_ai USING GIN (ocr_text ai.gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_media_ai_cap_trgm ON ai.media_ai USING GIN (caption ai.gin_trgm_ops);

-- =====================================================
-- 向量表：int8 量化存储，检索在 Go 侧做精确扫描（无需 pgvector）
--
-- vec 为 dim 字节的 int8；真实分量 = int8 值 * scale。归一化后的向量
-- 在 int8 下排序保真度 >0.99，7w 规模单次扫描 20-40ms。
-- =====================================================
CREATE TABLE IF NOT EXISTS ai.embeddings (
    media_id   UUID NOT NULL REFERENCES gallery.media_assets(id) ON DELETE CASCADE,
    kind       TEXT NOT NULL,          -- 目前仅 'image'
    model      TEXT NOT NULL,          -- 如 siglip-base-patch16-224
    dim        INTEGER NOT NULL,
    scale      REAL NOT NULL,          -- 反量化系数
    vec        BYTEA NOT NULL,         -- dim 字节 int8
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (media_id, kind, model)
);

CREATE INDEX IF NOT EXISTS idx_embeddings_model ON ai.embeddings (model, kind);

-- =====================================================
-- 人脸与人物分组
-- =====================================================
CREATE TABLE IF NOT EXISTS ai.persons (
    id            UUID PRIMARY KEY,
    name          TEXT,
    cover_face_id UUID,                -- 外键在 faces 建表后追加（避免建表期循环依赖）
    face_count    INTEGER NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ai.faces (
    id         UUID PRIMARY KEY,
    media_id   UUID NOT NULL REFERENCES gallery.media_assets(id) ON DELETE CASCADE,
    person_id  UUID REFERENCES ai.persons(id) ON DELETE SET NULL,
    -- 归一化坐标 x1,y1,x2,y2（相对于原图宽高）
    bbox       REAL[] NOT NULL,
    det_score  REAL NOT NULL DEFAULT 0,
    quality    REAL NOT NULL DEFAULT 0,
    -- 512 维 float32 归一化特征（2048 字节）
    embedding  BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_faces_media_id  ON ai.faces (media_id);
CREATE INDEX IF NOT EXISTS idx_faces_person_id ON ai.faces (person_id);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_persons_cover_face'
    ) THEN
        ALTER TABLE ai.persons
            ADD CONSTRAINT fk_persons_cover_face
            FOREIGN KEY (cover_face_id) REFERENCES ai.faces(id) ON DELETE SET NULL;
    END IF;
END $$;

-- =====================================================
-- 任务队列
--
-- 一行 = 一个 (能力, 媒体) 处理单元。UNIQUE 约束保证重复入队幂等。
-- 认领使用 SELECT ... FOR UPDATE SKIP LOCKED，天然支持多 worker。
-- =====================================================
CREATE TABLE IF NOT EXISTS ai.jobs (
    id          BIGSERIAL PRIMARY KEY,
    capability  TEXT NOT NULL,         -- phash / embed / face / ocr / vlm
    media_id    UUID NOT NULL REFERENCES gallery.media_assets(id) ON DELETE CASCADE,
    status      TEXT NOT NULL DEFAULT 'pending', -- pending/running/done/failed
    priority    SMALLINT NOT NULL DEFAULT 100,   -- 越小越先处理
    attempts    SMALLINT NOT NULL DEFAULT 0,
    last_error  TEXT,
    started_at  TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_jobs_cap_media UNIQUE (capability, media_id)
);

CREATE INDEX IF NOT EXISTS idx_jobs_claim   ON ai.jobs (capability, status, priority, id);
CREATE INDEX IF NOT EXISTS idx_jobs_media   ON ai.jobs (media_id);
CREATE INDEX IF NOT EXISTS idx_jobs_updated ON ai.jobs (updated_at);

-- =====================================================
-- 运行时设置（能力开关等）
--
-- 刻意不在此处预置数据：未设置时由服务端 .env 的 AI_AUTO_CAPS 兜底，
-- 桌面端修改后才写入本表并从此以数据库为准。
-- =====================================================
CREATE TABLE IF NOT EXISTS ai.settings (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- updated_at 自动维护触发器
-- =====================================================
DROP TRIGGER IF EXISTS trigger_media_ai_updated_at ON ai.media_ai;
DROP TRIGGER IF EXISTS trigger_embeddings_updated_at ON ai.embeddings;
DROP TRIGGER IF EXISTS trigger_persons_updated_at ON ai.persons;
DROP TRIGGER IF EXISTS trigger_jobs_updated_at ON ai.jobs;
DROP TRIGGER IF EXISTS trigger_settings_updated_at ON ai.settings;

CREATE TRIGGER trigger_media_ai_updated_at
    BEFORE UPDATE ON ai.media_ai
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

CREATE TRIGGER trigger_embeddings_updated_at
    BEFORE UPDATE ON ai.embeddings
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

CREATE TRIGGER trigger_persons_updated_at
    BEFORE UPDATE ON ai.persons
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

CREATE TRIGGER trigger_jobs_updated_at
    BEFORE UPDATE ON ai.jobs
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();

CREATE TRIGGER trigger_settings_updated_at
    BEFORE UPDATE ON ai.settings
    FOR EACH ROW EXECUTE FUNCTION ai.update_updated_at_column();
