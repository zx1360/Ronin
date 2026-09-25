# CLI Help Snapshot

- GeneratedAt: 2026-09-26T07:01:56+08:00
- WorkingDir: D:\products\Ronin\backend\gizmos
- Command: go run ./cmd/gallery -h
- ExitCode: 0

```text
Usage of C:\Users\puzzledAx\AppData\Local\go-build\61\611b14b1d618d3911db4fa58b3bf9ddcc2b7402c05f9ba75a2029201a087fbcb-d\gallery.exe:
  -batch int
    	批量写入大小 (default 160)
  -concurrency int
    	并发处理数 (default 10)
  -gallery-root string
    	Gallery 根目录（必填）
  -mode string
    	运行模式: ingest(摄入) | execute(执行删除) | refresh(刷新修复) (default "ingest")
  -resize int
    	refresh 模式: 同时设置预览图最大边和缩略图边长（像素，>0 生效）
  -resizePreview int
    	refresh 模式: 单独设置预览图最大边（像素，>0 生效）
  -resizeThumb int
    	refresh 模式: 单独设置缩略图边长（像素，>0 生效）
```

