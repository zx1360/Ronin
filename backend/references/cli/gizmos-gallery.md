# CLI Help Snapshot

- GeneratedAt: 2026-05-05T08:16:58+08:00
- WorkingDir: D:\products\Ronin\backend\gizmos
- Command: go run ./cmd/gallery -h
- ExitCode: 0

```text
Usage of C:\Users\puzzledAx\AppData\Local\go-build\72\7219cbc90a73c44eae8cff4c771dcf0b4693e1e71fbf38b1cde9d4633bc324fa-d\gallery.exe:
  -batch int
    	批量写入大小 (default 160)
  -concurrency int
    	并发处理数 (default 10)
  -gallery-root string
    	Gallery 根目录 (default "D:\\Assests\\Gallery")
  -mode string
    	运行模式: ingest(摄入) | execute(执行删除) | refresh(刷新修复) (default "ingest")
  -resize int
    	refresh 模式: 同时设置预览图最大边和缩略图边长（像素，>0 生效）
  -resizePreview int
    	refresh 模式: 单独设置预览图最大边（像素，>0 生效）
  -resizeThumb int
    	refresh 模式: 单独设置缩略图边长（像素，>0 生效）
```

