-- 漫画域建表真源；Monarch 与 comix init 均在写事务内执行。

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
