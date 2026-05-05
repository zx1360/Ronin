# 用户数据表 (user_data schema: booklet + essay)

## essay_articles (随笔文章)

```postgresql
CREATE TABLE IF NOT EXISTS essay_articles (
    id          UUID PRIMARY KEY,
    date        TIMESTAMPTZ NOT NULL,
    word_count  INT NOT NULL DEFAULT 0,
    content     TEXT NOT NULL DEFAULT '',
    imgs        TEXT[] NOT NULL DEFAULT '{}',
    labels      UUID[] NOT NULL DEFAULT '{}',
    messages    JSONB NOT NULL DEFAULT '[]',
    mood        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('simple', coalesce(content, '')), 'B')
    ) STORED
);

CREATE INDEX idx_essay_articles_date ON essay_articles(date);
CREATE INDEX idx_essay_articles_labels ON essay_articles USING GIN(labels);
CREATE INDEX idx_essay_articles_mood ON essay_articles(mood);
CREATE INDEX idx_essay_articles_search ON essay_articles USING GIN(search_vector);
CREATE INDEX idx_essay_articles_updated ON essay_articles(updated_at);

CREATE OR REPLACE FUNCTION update_essay_articles_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_essay_articles_updated_at
    BEFORE UPDATE ON essay_articles
    FOR EACH ROW EXECUTE FUNCTION update_essay_articles_updated_at();
```

## essay_labels (随笔标签)

```postgresql
CREATE TABLE IF NOT EXISTS essay_labels (
    id          UUID PRIMARY KEY,
    name        TEXT NOT NULL,
    essay_count INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_essay_labels_name ON essay_labels(name);

CREATE TRIGGER trg_essay_labels_updated_at
    BEFORE UPDATE ON essay_labels
    FOR EACH ROW EXECUTE FUNCTION update_essay_articles_updated_at();
```

## essay_year_summaries (年度汇总)

```postgresql
CREATE TABLE IF NOT EXISTS essay_year_summaries (
    year            INT PRIMARY KEY,
    essay_count     INT NOT NULL DEFAULT 0,
    word_count      INT NOT NULL DEFAULT 0,
    month_summaries JSONB NOT NULL DEFAULT '[]',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## booklet_styles (打卡项目组)

```postgresql
CREATE TABLE IF NOT EXISTS booklet_styles (
    id                  UUID PRIMARY KEY,
    start_date          TIMESTAMPTZ NOT NULL,
    valid_check_in      INT NOT NULL DEFAULT 0,
    fully_done          INT NOT NULL DEFAULT 0,
    longest_streak      INT NOT NULL DEFAULT 0,
    longest_fully_streak INT NOT NULL DEFAULT 0,
    tasks               JSONB NOT NULL DEFAULT '[]',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_booklet_styles_start ON booklet_styles(start_date);

CREATE TRIGGER trg_booklet_styles_updated_at
    BEFORE UPDATE ON booklet_styles
    FOR EACH ROW EXECUTE FUNCTION update_essay_articles_updated_at();
```

## booklet_records (每日打卡记录)

```postgresql
CREATE TABLE IF NOT EXISTS booklet_records (
    id              UUID PRIMARY KEY,
    style_id        UUID NOT NULL REFERENCES booklet_styles(id) ON DELETE CASCADE,
    date            DATE NOT NULL,
    message         TEXT NOT NULL DEFAULT '',
    task_completion JSONB NOT NULL DEFAULT '{}',
    mood            TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_booklet_records_style_date UNIQUE (style_id, date)
);

CREATE INDEX idx_booklet_records_date ON booklet_records(date);
CREATE INDEX idx_booklet_records_style ON booklet_records(style_id);
CREATE INDEX idx_booklet_records_updated ON booklet_records(updated_at);

CREATE TRIGGER trg_booklet_records_updated_at
    BEFORE UPDATE ON booklet_records
    FOR EACH ROW EXECUTE FUNCTION update_essay_articles_updated_at();
```
