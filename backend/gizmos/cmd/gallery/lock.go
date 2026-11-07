package main

import (
	"fmt"
	"os"
	"path/filepath"
)

func lockGallery(root string) (*os.File, error) {
	if err := os.MkdirAll(root, 0o755); err != nil {
		return nil, err
	}
	file, err := os.OpenFile(filepath.Join(root, ".gallery.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	if err := tryLock(file); err != nil {
		_ = file.Close()
		return nil, fmt.Errorf("无法锁定图库，请检查是否有其他 Gallery CLI 在运行: %w", err)
	}
	return file, nil
}
