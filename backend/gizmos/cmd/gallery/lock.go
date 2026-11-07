package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"monarch/gizmos/internal/gallery/repository"
	"monarch/internal/galleryfs"
	"monarch/internal/repository/gallery_repo"
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

func checkLibrary(ctx context.Context, lock *os.File, mediaDir string) error {
	bound, err := io.ReadAll(lock)
	if err != nil {
		return err
	}
	if len(bound) == 0 {
		assets, err := repository.NewRepository().GetAllAssets(ctx)
		if err != nil {
			return err
		}
		matches := len(assets) == 0
		for _, asset := range assets {
			rel, ok := galleryfs.RelativePath(asset.FilePath)
			if !ok {
				continue
			}
			if hash, err := galleryfs.HashFile(filepath.Join(mediaDir, rel)); err == nil && bytes.Equal(hash, asset.Hash) {
				matches = true
				break
			}
		}
		if !matches {
			return fmt.Errorf("媒体目录与数据库不匹配，请核对 DB_FILE 和 Gallery 根目录")
		}
	}
	id, err := gallery_repo.LibraryID(ctx)
	if err != nil {
		return err
	}
	if len(bound) == 0 {
		_, err := lock.WriteString(id + "\n")
		return err
	}
	if strings.TrimSpace(string(bound)) != id {
		return fmt.Errorf("图库标识与数据库不匹配，请核对 DB_FILE 和 Gallery 根目录")
	}
	return nil
}
