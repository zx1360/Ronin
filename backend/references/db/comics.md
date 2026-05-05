# 漫画数据表 (comics schema)

## comic_books

```postgresql
CREATE TABLE IF NOT EXISTS comics.comic_books (
    id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    cover_image TEXT,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    readed BOOLEAN NOT NULL DEFAULT FALSE,
    source TEXT NOT NULL DEFAULT ''
);
```

## comic_chapters

```postgresql
CREATE TABLE IF NOT EXISTS comics.comic_chapters (
    id UUID PRIMARY KEY,
    comic_id uuid NOT NULL,
    dir_name VARCHAR(255) NOT NULL,
    chapter_index INTEGER NOT NULL,
    FOREIGN KEY (comic_id) REFERENCES comic_books(id) ON DELETE CASCADE
);
```

## comic_images

```postgresql
CREATE TABLE IF NOT EXISTS comics.comic_images (
    id UUID PRIMARY KEY,
    chapter_id UUID NOT NULL,
    image_path TEXT NOT NULL,
    sort_num INTEGER NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    FOREIGN KEY (chapter_id) REFERENCES comic_chapters(id) ON DELETE CASCADE
);
```

## 索引

```postgresql
CREATE INDEX IF NOT EXISTS idx_comic_chapters_comic_id ON comics.comic_chapters (comic_id, chapter_index);
CREATE INDEX IF NOT EXISTS idx_comic_images_chapter_id ON comics.comic_images (chapter_id, sort_num);
```
