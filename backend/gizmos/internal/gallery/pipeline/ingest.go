package pipeline

import (
	"bytes"
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"

	"monarch/gizmos/internal/gallery/model"
	"monarch/gizmos/internal/gallery/processor"
)

type ingestion struct {
	*Pipeline
	pending sync.Map
	mu      sync.Mutex
	names   map[string]map[string]struct{}
	staging string
}

type stagedMedia struct {
	asset   *model.MediaAsset
	source  string
	info    os.FileInfo
	record  string
	release func()
}

func (p *Pipeline) RunIngestion(ctx context.Context) (*Stats, error) {
	if err := p.ensureDirectories(); err != nil {
		return nil, err
	}
	staging := filepath.Join(p.config.MediaDir, ".ronin-ingest")
	if err := os.MkdirAll(staging, 0o700); err != nil {
		return nil, err
	}
	defer os.Remove(staging)
	run := ingestion{Pipeline: p, names: make(map[string]map[string]struct{}), staging: staging}
	stats := &Stats{}
	paths, warnings := p.scanner.ScanDir(ctx)
	results := make(chan stagedMedia, p.config.Concurrency)
	var workers sync.WaitGroup
	workers.Go(func() {
		for warning := range warnings {
			log.Printf("扫描警告: %v", warning)
			atomic.AddInt64(&stats.FailedFiles, 1)
		}
	})
	for range p.config.Concurrency {
		workers.Go(func() {
			for path := range paths {
				if ctx.Err() != nil {
					return
				}
				atomic.AddInt64(&stats.TotalFiles, 1)
				staged, err := run.stage(ctx, path)
				switch {
				case err != nil:
					log.Printf("摄入失败 %s: %v", path, err)
					atomic.AddInt64(&stats.FailedFiles, 1)
				case staged.asset == nil:
					atomic.AddInt64(&stats.DuplicateFiles, 1)
				default:
					results <- staged
				}
			}
		})
	}
	go func() {
		workers.Wait()
		close(results)
	}()

	run.writeBatches(ctx, results, stats)
	p.cleanEmptyDirsRecursive(p.config.RawDir)
	if err := ctx.Err(); err != nil {
		return stats, err
	}
	if stats.FailedFiles > 0 {
		return stats, fmt.Errorf("摄入有 %d 项失败，可重试", stats.FailedFiles)
	}
	return stats, nil
}

func (p *ingestion) stage(ctx context.Context, path string) (result stagedMedia, err error) {
	info, err := os.Stat(path)
	if err != nil {
		return result, err
	}
	file, err := p.scanner.ExtractFileInfo(path)
	if err != nil {
		return result, err
	}
	key := fmt.Sprintf("%x", file.Hash)
	record := filepath.Join(p.staging, key)
	done := make(chan struct{})
	for {
		wait, busy := p.pending.LoadOrStore(key, done)
		if !busy {
			break
		}
		select {
		case <-ctx.Done():
			return result, ctx.Err()
		case <-wait.(chan struct{}):
		}
	}
	release := func() {
		p.pending.Delete(key)
		close(done)
	}
	defer func() {
		if result.asset == nil {
			release()
		}
	}()

	query, cancel := context.WithTimeout(ctx, 5*time.Second)
	exists, err := p.repository.HashExists(query, file.Hash)
	cancel()
	if err != nil {
		return result, err
	}
	if exists {
		p.mu.Lock()
		defer p.mu.Unlock()
		if err := unchangedSource(path, info); err != nil {
			return result, err
		}
		err := p.moveToDeleted(path)
		if err == nil {
			removeRecord(record)
		}
		return result, err
	}

	rel, err := p.resume(record, file.Hash)
	if err != nil {
		return result, err
	}
	if rel == "" {
		month := file.CapturedAt.Format("2006-01")
		dir := filepath.Join(p.config.MediaDir, month)
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return result, err
		}
		staged := filepath.Join(dir, ".ronin-ingest-"+key+".tmp")
		defer os.Remove(staged)
		if err := stageCopy(path, staged, info, file.Hash); err != nil {
			return result, err
		}
		rel, err = p.publish(staged, dir, file.FileName, record)
		if err != nil {
			return result, err
		}
	}
	file.FileName = filepath.Base(rel)
	file.Extension = strings.ToLower(filepath.Ext(rel))
	file.IsVideo = model.IsVideo(file.Extension)
	file.IsAnimated = model.IsAnimatedImage(file.Extension)
	file.MimeType = model.GetMimeType(file.Extension)
	derived, err := p.processor.Process(file, filepath.Join(p.config.MediaDir, rel), filepath.Dir(rel))
	if err != nil {
		log.Printf("派生图生成失败 %s: %v", path, err)
		derived = &processor.ProcessResult{}
	}
	return stagedMedia{
		source: path, info: info, record: record, release: release,
		asset: &model.MediaAsset{
			ID: uuid.New(), CapturedAt: file.CapturedAt, FilePath: rel,
			ThumbPath: strPtr(derived.ThumbPath), PreviewPath: strPtr(derived.PreviewPath),
			Hash: file.Hash, SizeBytes: file.SizeBytes, MimeType: &file.MimeType,
		},
	}, nil
}

func (p *ingestion) resume(record string, hash []byte) (string, error) {
	data, err := os.ReadFile(record)
	if os.IsNotExist(err) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	rel := string(data)
	if !filepath.IsLocal(rel) || filepath.Dir(rel) == "." {
		return "", fmt.Errorf("无效的摄入记录: %s", record)
	}
	current, err := calculateFileHash(filepath.Join(p.config.MediaDir, rel))
	if os.IsNotExist(err) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	if bytes.Equal(current, hash) {
		return rel, nil
	}
	return "", nil
}

// 先记录目标位置，中断后可按哈希找到同一份原件。
func (p *ingestion) publish(staged, dir, name, record string) (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	names := p.names[dir]
	if names == nil {
		entries, err := os.ReadDir(dir)
		if err != nil {
			return "", err
		}
		names = make(map[string]struct{}, len(entries))
		for _, entry := range entries {
			names[strings.ToLower(stem(entry.Name()))] = struct{}{}
		}
		p.names[dir] = names
	}
	for suffix := 0; ; suffix++ {
		candidate := name
		if suffix > 0 {
			candidate = fmt.Sprintf("%s_%d%s", stem(name), suffix, filepath.Ext(name))
		}
		key := strings.ToLower(stem(candidate))
		if _, occupied := names[key]; occupied {
			continue
		}
		rel := filepath.Join(filepath.Base(dir), candidate)
		temp := record + ".tmp"
		defer os.Remove(temp)
		if err := os.WriteFile(temp, []byte(rel), 0o600); err != nil {
			return "", err
		}
		if err := os.Rename(temp, record); err != nil {
			return "", err
		}
		if err := os.Rename(staged, filepath.Join(dir, candidate)); err != nil {
			return "", err
		}
		names[key] = struct{}{}
		return rel, nil
	}
}

func stem(name string) string { return strings.TrimSuffix(name, filepath.Ext(name)) }

func stageCopy(source, staged string, info os.FileInfo, expected []byte) error {
	raw, err := os.Open(source)
	if err != nil {
		return err
	}
	defer raw.Close()
	if err := os.Remove(staged); err != nil && !os.IsNotExist(err) {
		return err
	}
	dst, err := os.OpenFile(staged, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	hash := sha256.New()
	if _, err := io.Copy(io.MultiWriter(dst, hash), raw); err != nil {
		return errors.Join(err, dst.Close())
	}
	if !bytes.Equal(hash.Sum(nil), expected) {
		return errors.Join(errors.New("复制期间原件发生变化"), dst.Close())
	}
	if err := errors.Join(dst.Sync(), dst.Close()); err != nil {
		return err
	}
	return errors.Join(os.Chmod(staged, info.Mode().Perm()), os.Chtimes(staged, info.ModTime(), info.ModTime()))
}

func unchangedSource(path string, before os.FileInfo) error {
	now, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !os.SameFile(before, now) || before.Size() != now.Size() || before.ModTime() != now.ModTime() {
		return errors.New("原件发生变化，已保留 Raw")
	}
	return nil
}

func (p *ingestion) writeBatches(ctx context.Context, results <-chan stagedMedia, stats *Stats) {
	batch := make([]stagedMedia, 0, p.config.BatchSize)
	assets := make([]*model.MediaAsset, 0, p.config.BatchSize)
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	flush := func() {
		if len(batch) == 0 {
			return
		}
		for _, item := range batch {
			assets = append(assets, item.asset)
		}
		writeCtx, cancel := context.WithTimeout(ctx, 5*time.Minute)
		err := p.repository.BatchInsertMediaAssets(writeCtx, assets)
		cancel()
		if err != nil {
			log.Printf("批量写库失败，Raw 已保留: %v", err)
		} else {
			log.Printf("已提交 %d 条媒体记录", len(batch))
		}
		for _, item := range batch {
			if err != nil {
				atomic.AddInt64(&stats.FailedFiles, 1)
			} else if cleanupErr := removeImportedSource(item); cleanupErr != nil {
				log.Printf("清理已入库原件 %s: %v", item.source, cleanupErr)
				atomic.AddInt64(&stats.FailedFiles, 1)
			} else {
				stats.ProcessedFiles++
			}
			if err == nil {
				removeRecord(item.record)
			}
			item.release()
		}
		clear(assets)
		clear(batch)
		assets, batch = assets[:0], batch[:0]
	}
	for {
		select {
		case item, ok := <-results:
			if !ok {
				flush()
				return
			}
			batch = append(batch, item)
			if len(batch) >= p.config.BatchSize {
				flush()
			}
		case <-ticker.C:
			flush()
		}
	}
}

func removeRecord(path string) {
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		log.Printf("清理摄入记录 %s: %v", path, err)
	}
}

func removeImportedSource(item stagedMedia) error {
	if err := unchangedSource(item.source, item.info); err != nil {
		return err
	}
	return os.Remove(item.source)
}
