package data_handler

import (
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

// 文件先暂存；提交数据失败时恢复被覆盖的文件。
type backupFiles struct {
	dir     string
	entries []backupFile
	targets map[string]bool
}

type backupFile struct {
	dest, staged, previous string
	installed              bool
}

func newBackupFiles(parent string) (*backupFiles, error) {
	if err := os.MkdirAll(parent, 0o755); err != nil {
		return nil, err
	}
	dir, err := os.MkdirTemp(parent, ".backup-")
	return &backupFiles{dir: dir, targets: make(map[string]bool)}, err
}

func (b *backupFiles) contains(dest string) bool {
	return b.targets[dest]
}

func (b *backupFiles) add(dest string, save func(string) error) error {
	if b.contains(dest) {
		return fmt.Errorf("重复文件: %s", filepath.Base(dest))
	}
	staged := filepath.Join(b.dir, fmt.Sprintf("%d.new", len(b.entries)))
	if err := save(staged); err != nil {
		return err
	}
	b.entries = append(b.entries, backupFile{dest: dest, staged: staged})
	b.targets[dest] = true
	return nil
}

func (b *backupFiles) commit(writeData func() error) (err error) {
	defer func() {
		if err == nil {
			return
		}
		for i := len(b.entries) - 1; i >= 0; i-- {
			e := &b.entries[i]
			if e.installed {
				err = errors.Join(err, os.Remove(e.dest))
			}
			if e.previous != "" {
				if restoreErr := os.Rename(e.previous, e.dest); restoreErr != nil {
					err = errors.Join(err, fmt.Errorf("恢复 %s 失败，原文件保留在 %s: %w", e.dest, filepath.Dir(e.previous), restoreErr))
					b.dir = "" // 恢复失败时保留副本供人工处理。
				}
			}
		}
	}()
	for i := range b.entries {
		e := &b.entries[i]
		if err = os.MkdirAll(filepath.Dir(e.dest), 0o755); err != nil {
			return err
		}
		if info, statErr := os.Stat(e.dest); statErr == nil {
			if !info.Mode().IsRegular() {
				return fmt.Errorf("目标不是普通文件: %s", e.dest)
			}
			previous := filepath.Join(b.dir, fmt.Sprintf("%d.old", i))
			if err = os.Rename(e.dest, previous); err != nil {
				return err
			}
			e.previous = previous
		} else if !errors.Is(statErr, os.ErrNotExist) {
			return statErr
		}
		if err = os.Rename(e.staged, e.dest); err != nil {
			return err
		}
		e.installed = true
	}
	return writeData()
}

func (b *backupFiles) close() {
	if b.dir != "" {
		if err := os.RemoveAll(b.dir); err != nil {
			log.Printf("清理备份暂存目录失败: %v", err)
		}
	}
}
