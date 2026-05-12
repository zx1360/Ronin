# 用户数据表 (user_data schema)

## essay_articles

| 列         | 类型                                          |
| ---------- | --------------------------------------------- |
| id         | UUID PRIMARY KEY                              |
| date       | TIMESTAMPTZ NOT NULL                          |
| word_count | INT NOT NULL DEFAULT 0                        |
| content    | TEXT NOT NULL DEFAULT ''                      |
| imgs       | TEXT[] NOT NULL DEFAULT '{}'                  |
| labels     | UUID[] NOT NULL DEFAULT '{}' (标签ID数组)     |
| messages   | JSONB NOT NULL DEFAULT '[]'                   |
| mood       | TEXT                                          |
| created_at | TIMESTAMPTZ NOT NULL DEFAULT NOW()            |
| updated_at | TIMESTAMPTZ NOT NULL DEFAULT NOW() (自动更新) |

## essay_labels

| 列          | 类型                                          |
| ----------- | --------------------------------------------- |
| id          | UUID PRIMARY KEY                              |
| name        | TEXT NOT NULL                                 |
| essay_count | INT NOT NULL DEFAULT 0                        |
| created_at  | TIMESTAMPTZ NOT NULL DEFAULT NOW()            |
| updated_at  | TIMESTAMPTZ NOT NULL DEFAULT NOW() (自动更新) |

## essay_year_summaries

| 列              | 类型                                          |
| --------------- | --------------------------------------------- |
| year            | INT PRIMARY KEY                               |
| essay_count     | INT NOT NULL DEFAULT 0                        |
| word_count      | INT NOT NULL DEFAULT 0                        |
| month_summaries | JSONB NOT NULL DEFAULT '[]'                   |
| updated_at      | TIMESTAMPTZ NOT NULL DEFAULT NOW() (自动更新) |

## booklet_styles

| 列                   | 类型                                          |
| -------------------- | --------------------------------------------- |
| id                   | UUID PRIMARY KEY                              |
| start_date           | TIMESTAMPTZ NOT NULL                          |
| valid_check_in       | INT NOT NULL DEFAULT 0                        |
| fully_done           | INT NOT NULL DEFAULT 0                        |
| longest_streak       | INT NOT NULL DEFAULT 0                        |
| longest_fully_streak | INT NOT NULL DEFAULT 0                        |
| tasks                | JSONB NOT NULL DEFAULT '[]'                   |
| created_at           | TIMESTAMPTZ NOT NULL DEFAULT NOW()            |
| updated_at           | TIMESTAMPTZ NOT NULL DEFAULT NOW() (自动更新) |

## booklet_records

| 列              | 类型                                          |
| --------------- | --------------------------------------------- |
| id              | UUID PRIMARY KEY                              |
| style_id        | UUID NOT NULL FK→booklet_styles               |
| date            | DATE NOT NULL                                 |
| message         | TEXT NOT NULL DEFAULT ''                      |
| task_completion | JSONB NOT NULL DEFAULT '{}'                   |
| mood            | TEXT                                          |
| created_at      | TIMESTAMPTZ NOT NULL DEFAULT NOW()            |
| updated_at      | TIMESTAMPTZ NOT NULL DEFAULT NOW() (自动更新) |

- 唯一约束：(style_id, date)
