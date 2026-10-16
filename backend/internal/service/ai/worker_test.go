package ai

import (
	"context"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/service/db"
)

func initAITestDB(t *testing.T) {
	t.Helper()
	if err := db.Init(config.DbConfig{File: filepath.Join(t.TempDir(), "ai.db"), SchemaFile: "../../../references/db/sqlite.sql"}); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(db.Close)
}

func insertTestMedia(t *testing.T) uuid.UUID {
	t.Helper()
	id := uuid.New()
	_, err := db.Exec(t.Context(), `INSERT INTO media_assets (id, captured_at, file_path, hash)
		VALUES (?, '2026-01-01 12:00:00', ?, ?)`, id, id.String()+".jpg", id[:])
	if err != nil {
		t.Fatal(err)
	}
	return id
}

func TestReconcileIdempotentAndPreservesExistingJobs(t *testing.T) {
	initAITestDB(t)
	old, fresh := insertTestMedia(t), insertTestMedia(t)
	if _, err := db.Exec(t.Context(), `INSERT INTO jobs (media_id, capability, status, input_sig)
		VALUES (?, 'phash', 'done', 'old-input')`, old); err != nil {
		t.Fatal(err)
	}
	e := New(nil, config.AiConfig{AutoCaps: []string{model.CapPHash}})
	if next := e.reconcileOnce(); next != reconcileActiveInterval {
		t.Fatalf("新增任务后间隔 = %v", next)
	}
	select {
	case <-e.wake:
	default:
		t.Fatal("新增任务没有唤醒 worker")
	}
	if next := e.reconcileOnce(); next != reconcileIdleInterval {
		t.Fatalf("无新增任务时没有进入空闲间隔: %v", next)
	}
	var status, sig string
	if err := db.Read().QueryRow(`SELECT status, input_sig FROM jobs WHERE media_id = ?`, old).Scan(&status, &sig); err != nil {
		t.Fatal(err)
	}
	if status != "done" || sig != "old-input" {
		t.Fatalf("已有产物被重排: %s / %s", status, sig)
	}
	if err := db.Read().QueryRow(`SELECT status, input_sig FROM jobs WHERE media_id = ?`, fresh).Scan(&status, &sig); err != nil {
		t.Fatal(err)
	}
	if status != "pending" || sig != e.InputSignature(model.CapPHash) {
		t.Fatalf("新增任务不符: %s / %s", status, sig)
	}
}

func TestWorkerEmptyQueueDoesNotProbe(t *testing.T) {
	initAITestDB(t)
	var requests atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		_, _ = w.Write([]byte(`{"models":[]}`))
	}))
	defer server.Close()
	e := New(nil, config.AiConfig{OllamaURL: server.URL, SidecarDir: t.TempDir()})
	e.rt.vlmModel = "test-model"
	worked, err := e.runOneBatch(context.Background())
	if err != nil || worked || requests.Load() != 0 {
		t.Fatalf("空队列仍探测依赖: worked=%v err=%v requests=%d", worked, err, requests.Load())
	}
}

func TestIndexRebuildAfterIdleKeepsSearchResults(t *testing.T) {
	initAITestDB(t)
	id := insertTestMedia(t)
	if err := ai_repo.SaveEmbeddings([]ai_repo.EmbeddingWrite{{
		MediaID: id, Kind: "image", Model: "test", Dim: 2, Scale: 0.01, Vec: []byte{100, 0},
	}}); err != nil {
		t.Fatal(err)
	}
	ix := NewIndex("test")
	search := func() {
		t.Helper()
		hits, err := ix.SearchVector([]float32{1, 0}, 1, nil)
		if err != nil || len(hits) != 1 || hits[0].MediaID != id || hits[0].Score != 1 {
			t.Fatalf("搜索结果不符: %+v err=%v", hits, err)
		}
	}
	search()
	if ix.ReleaseIdle(time.Minute) || !ix.Loaded() {
		t.Fatal("活跃索引被提前释放")
	}
	ix.mu.Lock()
	ix.lastUsed = time.Now().Add(-2 * time.Minute)
	ix.phashes[id] = 1
	ix.ignores[id] = struct{}{}
	ix.mu.Unlock()
	_ = ix.VectorCount()
	_ = ix.Loaded()
	if !ix.ReleaseIdle(time.Minute) {
		t.Fatal("没有报告缓存回收")
	}
	if ix.Loaded() || ix.VectorCount() != 0 || ix.vecs != nil || ix.phashes != nil || ix.ignores != nil {
		t.Fatal("状态读取延长了驻留，或空闲缓存没有释放")
	}
	if ix.ReleaseIdle(time.Minute) {
		t.Fatal("重复空闲检查不应再次触发回收")
	}
	search()
}
