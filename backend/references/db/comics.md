# 漫画数据表 (comics schema)

## comic_books
| 列          | 类型                  |
| ----------- | --------------------- |
| id          | UUID PRIMARY KEY      |
| title       | VARCHAR(255) NOT NULL |
| cover_image | TEXT                  |
| is_public   | BOOLEAN DEFAULT TRUE  |
| readed      | BOOLEAN DEFAULT FALSE |

## comic_chapters
| 列            | 类型                         |
| ------------- | ---------------------------- |
| id            | UUID PRIMARY KEY             |
| comic_id      | UUID NOT NULL FK→comic_books |
| dir_name      | VARCHAR(255) NOT NULL        |
| chapter_index | INTEGER NOT NULL             |

## comic_images
| 列         | 类型                            |
| ---------- | ------------------------------- |
| id         | UUID PRIMARY KEY                |
| chapter_id | UUID NOT NULL FK→comic_chapters |
| image_path | TEXT NOT NULL                   |
| sort_num   | INTEGER NOT NULL                |
| width      | INTEGER NOT NULL                |
| height     | INTEGER NOT NULL                |
