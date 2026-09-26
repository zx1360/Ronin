package ai

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
)

const (
	// reconcileInitialDelay 服务启动后首次补充入队的延迟。
	reconcileInitialDelay = 5 * time.Second
	// reconcileActiveInterval 仍有新增任务时的补充入队间隔。
	reconcileActiveInterval = 60 * time.Second
	// reconcileIdleInterval 队列已排空后的长间隔（降低空转开销）。
	reconcileIdleInterval = 10 * time.Minute
	// reconcileBatch 单次补充入队的上限（每个能力）。
	reconcileBatch = 5000
	// workerIdleInterval 无任务时的轮询间隔。
	workerIdleInterval = 5 * time.Second
	// vlmBatchMax VLM 单图耗时长，缩小批次以降低超时损失。
	vlmBatchMax = 4
)

// 各能力的默认优先级（越小越先处理，廉价能力优先）。
var capabilityPriority = map[string]int{
	model.CapPHash: 10,
	model.CapEmbed: 20,
	model.CapFace:  30,
	model.CapOCR:   40,
	model.CapVLM:   100,
}

// ---------- 入库自动触发 ----------

// reconcileLoop 周期性把"尚无任务行"的媒体补进队列。
//
// 这是"媒体入库后自动触发处理流水线"的唯一实现：不依赖入库方的任何配合，
// 幂等且自愈——无论媒体是何时、由哪个工具写入的，最终都会被覆盖到。
func (e *Engine) reconcileLoop(ctx context.Context) {
	next := reconcileInitialDelay
	for {
		select {
		case <-ctx.Done():
			return
		case <-time.After(next):
		}

		autoCaps := ai_repo.AutoCapabilities(e.cfg.AutoCaps)
		inserted := int64(0)
		for _, capability := range autoCaps {
			n, err := ai_repo.EnqueueMissing(capability, reconcileBatch, capabilityPriority[capability])
			if err != nil {
				log.Printf("[AI] 补充入队 %s 失败: %v", capability, err)
				continue
			}
			inserted += n
		}
		if inserted > 0 {
			log.Printf("[AI] 入库自动入队 %d 条任务（能力: %v）", inserted, autoCaps)
			e.Wake()
			next = reconcileActiveInterval
		} else {
			next = reconcileIdleInterval
		}
	}
}

// ---------- 任务调度 ----------

// workerLoop 主调度循环：有任务就连续处理，空闲则定期轮询。
func (e *Engine) workerLoop(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case <-e.wake:
		case <-time.After(workerIdleInterval):
		}
		for ctx.Err() == nil {
			worked, err := e.runOneBatch(ctx)
			if err != nil {
				log.Printf("[AI] 批次执行异常: %v", err)
				break
			}
			if !worked {
				break
			}
		}
	}
}

// runOneBatch 按优先级挑选一个能力并处理一批任务；无任务时返回 false。
func (e *Engine) runOneBatch(ctx context.Context) (bool, error) {
	// 用户暂停期间不认领任何任务（已认领的批次由 CancelRun 负责中断）
	if e.paused.Load() {
		return false, nil
	}

	for _, capability := range model.AllCapabilities {
		if ctx.Err() != nil {
			return false, ctx.Err()
		}
		if ready, _ := e.CapabilityReady(ctx, capability); !ready {
			continue
		}

		pending, err := ai_repo.PendingCount(capability)
		if err != nil {
			return false, err
		}
		if pending == 0 {
			continue
		}

		claimed, err := ai_repo.Claim(capability, e.batchLimit(capability))
		if err != nil {
			return false, err
		}
		if len(claimed) == 0 {
			continue
		}
		e.executeBatch(ctx, capability, claimed)
		return true, nil
	}
	return false, nil
}

// batchLimit 返回该能力单批处理条数。
func (e *Engine) batchLimit(capability string) int {
	limit := e.cfg.BatchSize
	if capability == model.CapVLM && limit > vlmBatchMax {
		limit = vlmBatchMax
	}
	if limit < 1 {
		limit = 1
	}
	return limit
}

// executeBatch 执行一个已认领的批次并回写任务状态。
func (e *Engine) executeBatch(parent context.Context, capability string, claimed []ai_repo.ClaimedJob) {
	batchCtx, cancel := context.WithTimeout(parent, e.cfg.JobTimeout)
	e.setRunCancel(cancel)
	defer func() {
		e.setRunCancel(nil)
		cancel()
	}()

	info := &RunInfo{
		Capability: capability,
		Total:      len(claimed),
		StartedAt:  time.Now(),
		Running:    true,
	}
	e.setRun(info)
	defer func() {
		finished := *info
		finished.Running = false
		e.setRun(&finished)
	}()

	mediaIDs := make([]string, 0, len(claimed))
	jobByMedia := make(map[string]int64, len(claimed))
	for _, job := range claimed {
		key := job.MediaID.String()
		mediaIDs = append(mediaIDs, key)
		jobByMedia[key] = job.JobID
	}

	items, missing, err := e.resolveItems(mediaIDs)
	if err != nil {
		e.failJobs(claimed, fmt.Sprintf("解析媒体失败: %v", err))
		info.Failed = len(claimed)
		return
	}

	failed := map[string]string{}
	for _, id := range missing {
		failed[id] = "媒体文件缺失或未生成派生图"
	}

	switch capability {
	case model.CapPHash:
		e.runPHash(items, failed)
	case model.CapEmbed:
		e.runEmbed(batchCtx, items, failed)
	case model.CapFace:
		e.runFace(batchCtx, items, failed)
	case model.CapOCR:
		e.runOCR(batchCtx, items, failed)
	case model.CapVLM:
		e.runVLM(batchCtx, items, failed)
	default:
		for _, item := range items {
			failed[item.MediaID] = "未知能力: " + capability
		}
	}

	// 按结果回写任务状态
	var doneJobIDs, failedJobIDs []int64
	var firstErr string
	for mediaID, jobID := range jobByMedia {
		if msg, bad := failed[mediaID]; bad {
			failedJobIDs = append(failedJobIDs, jobID)
			if firstErr == "" {
				firstErr = msg
			}
			continue
		}
		doneJobIDs = append(doneJobIDs, jobID)
	}

	if err := ai_repo.FinishDone(doneJobIDs); err != nil {
		log.Printf("[AI] 标记任务完成失败: %v", err)
	}
	// 用户主动中断 / 模型被切换抢占：未完成的任务退回队列，不计失败
	if e.cancelRequested.Load() || e.TakeSwitchAbort() {
		if err := ai_repo.ReleaseRunning(failedJobIDs); err != nil {
			log.Printf("[AI] 释放任务失败: %v", err)
		}
		e.cancelRequested.Store(false)
	} else if len(failedJobIDs) > 0 {
		if err := ai_repo.FinishFailed(failedJobIDs, firstErr, e.cfg.MaxAttempts); err != nil {
			log.Printf("[AI] 标记任务失败失败: %v", err)
		}
	}

	info.Processed = len(doneJobIDs)
	info.Failed = len(failedJobIDs)
	log.Printf("[AI] %s 批次完成: 成功 %d / 失败 %d（本批 %d 条）",
		capability, info.Processed, info.Failed, info.Total)
}

func (e *Engine) failJobs(claimed []ai_repo.ClaimedJob, reason string) {
	ids := make([]int64, 0, len(claimed))
	for _, job := range claimed {
		ids = append(ids, job.JobID)
	}
	if err := ai_repo.FinishFailed(ids, reason, e.cfg.MaxAttempts); err != nil {
		log.Printf("[AI] 标记批次失败状态时出错: %v", err)
	}
}

// ---------- 各能力实现 ----------

// runPHash 在 Go 进程内计算感知哈希，不依赖任何外部进程。
func (e *Engine) runPHash(items []MediaItem, failed map[string]string) {
	for _, item := range items {
		mediaID, err := uuid.Parse(item.MediaID)
		if err != nil {
			failed[item.MediaID] = "媒体 ID 非法"
			continue
		}
		hash := ComputePHash(item.Path)
		if err := ai_repo.SavePHash(mediaID, hash); err != nil {
			failed[item.MediaID] = err.Error()
			continue
		}
		e.index.PutPHash(mediaID, hash)
	}
}

// embedPayload 侧车返回的图像向量（int8 + 反量化系数，base64 编码）。
type embedPayload struct {
	Dim   int     `json:"dim"`
	Scale float32 `json:"scale"`
	Vec   string  `json:"vec"`
}

// runEmbed 通过侧车计算 SigLIP 图像向量。
func (e *Engine) runEmbed(ctx context.Context, items []MediaItem, failed map[string]string) {
	results, err := e.embed.RunBatch(ctx, map[string]any{"model": e.cfg.EmbedModel}, toSidecarItems(items))
	if err != nil {
		failAllItems(items, failed, err)
		return
	}

	writes := make([]ai_repo.EmbeddingWrite, 0, len(results))
	for _, res := range results {
		if !res.OK {
			failed[res.ID] = firstNonEmpty(res.Error, "侧车未返回向量")
			continue
		}
		var payload embedPayload
		if err := json.Unmarshal(res.Result, &payload); err != nil {
			failed[res.ID] = fmt.Sprintf("解析向量结果失败: %v", err)
			continue
		}
		raw, err := base64.StdEncoding.DecodeString(payload.Vec)
		if err != nil || len(raw) != payload.Dim {
			failed[res.ID] = "向量长度与维度不一致"
			continue
		}
		mediaID, err := uuid.Parse(res.ID)
		if err != nil {
			continue
		}
		writes = append(writes, ai_repo.EmbeddingWrite{
			MediaID: mediaID,
			Kind:    "image",
			Model:   e.cfg.EmbedModel,
			Dim:     payload.Dim,
			Scale:   payload.Scale,
			Vec:     raw,
		})
	}

	if err := ai_repo.SaveEmbeddings(writes); err != nil {
		for _, w := range writes {
			failed[w.MediaID.String()] = err.Error()
		}
		return
	}
	for _, w := range writes {
		e.index.PutVector(w.MediaID, w.Dim, w.Scale, w.Vec)
	}
}

// facePayload 侧车返回的人脸结果。
type facePayload struct {
	Faces []struct {
		BBox      []float32 `json:"bbox"`
		Det       float64   `json:"det"`
		Quality   float64   `json:"quality"`
		Embedding string    `json:"embedding"`
	} `json:"faces"`
}

// runFace 通过侧车做人脸检测与特征提取，随后增量归并到人物分组。
func (e *Engine) runFace(ctx context.Context, items []MediaItem, failed map[string]string) {
	results, err := e.face.RunBatch(ctx, nil, toSidecarItems(items))
	if err != nil {
		failAllItems(items, failed, err)
		return
	}

	var assigned []FaceInput
	for _, res := range results {
		if !res.OK {
			failed[res.ID] = firstNonEmpty(res.Error, "侧车未返回人脸结果")
			continue
		}
		mediaID, err := uuid.Parse(res.ID)
		if err != nil {
			continue
		}

		var payload facePayload
		if err := json.Unmarshal(res.Result, &payload); err != nil {
			failed[res.ID] = fmt.Sprintf("解析人脸结果失败: %v", err)
			continue
		}

		writes := make([]ai_repo.FaceWrite, 0, len(payload.Faces))
		inputs := make([]FaceInput, 0, len(payload.Faces))
		for _, f := range payload.Faces {
			raw, err := base64.StdEncoding.DecodeString(f.Embedding)
			if err != nil || len(raw) != 512*4 {
				continue
			}
			faceID := uuid.New()
			quality := f.Quality
			if quality <= 0 {
				quality = faceQuality(f.Det, f.BBox)
			}
			writes = append(writes, ai_repo.FaceWrite{
				ID:        faceID,
				MediaID:   mediaID,
				Box:       f.BBox,
				DetScore:  f.Det,
				Quality:   quality,
				Embedding: raw,
			})
			inputs = append(inputs, FaceInput{
				FaceID:  faceID,
				MediaID: mediaID,
				Quality: quality,
				Vector:  ai_repo.DecodeFloat32(raw),
			})
		}

		if err := ai_repo.ReplaceFaces(mediaID, writes); err != nil {
			failed[res.ID] = err.Error()
			continue
		}
		// 只把确实落库的人脸交给聚类，避免归并到不存在的记录
		assigned = append(assigned, inputs...)
	}

	if len(assigned) == 0 {
		return
	}
	if _, err := e.cluster.AssignIncremental(assigned); err != nil {
		// 归并失败不影响"人脸已入库"这一事实，仅记录日志等待下一次聚类收敛
		log.Printf("[AI] 人脸增量归并失败: %v", err)
	}
}

// ocrPayload 侧车返回的 OCR 结果（只取需要的合并文本）。
type ocrPayload struct {
	Text string `json:"text"`
}

// runOCR 通过侧车做文字识别。
func (e *Engine) runOCR(ctx context.Context, items []MediaItem, failed map[string]string) {
	results, err := e.ocr.RunBatch(ctx, nil, toSidecarItems(items))
	if err != nil {
		failAllItems(items, failed, err)
		return
	}

	for _, res := range results {
		if !res.OK {
			failed[res.ID] = firstNonEmpty(res.Error, "侧车未返回 OCR 结果")
			continue
		}
		var payload ocrPayload
		if err := json.Unmarshal(res.Result, &payload); err != nil {
			failed[res.ID] = fmt.Sprintf("解析 OCR 结果失败: %v", err)
			continue
		}
		mediaID, err := uuid.Parse(res.ID)
		if err != nil {
			continue
		}
		if err := ai_repo.SaveOCR(mediaID, payload.Text); err != nil {
			failed[res.ID] = err.Error()
		}
	}
}

// runVLM 通过 Ollama 逐张生成描述与关键词。
//
// 逐张串行是刻意的：单张 4B VLM 推理已接近本机算力上限，并发只会互相拖慢。
// 模型由人工选择（默认 / 无审查版），并受模型仲裁保护：后台工作不抢占前台对话。
func (e *Engine) runVLM(ctx context.Context, items []MediaItem, failed map[string]string) {
	modelName := e.VLMModel()
	lease := e.UseModel(ctx, modelName, "VLM 自动标注", ModelBackground)
	defer lease.Release()
	if lease.Notice != "" {
		log.Printf("[AI] %s", lease.Notice)
	}
	ctx = lease.Context()

	for _, item := range items {
		if ctx.Err() != nil {
			for _, rest := range items {
				if _, done := failed[rest.MediaID]; !done {
					failed[rest.MediaID] = "批次已中断"
				}
			}
			return
		}
		mediaID, err := uuid.Parse(item.MediaID)
		if err != nil {
			failed[item.MediaID] = "媒体 ID 非法"
			continue
		}
		result, err := e.ollama.Generate(ctx, modelName, item.Path)
		if err != nil {
			failed[item.MediaID] = err.Error()
			continue
		}
		if err := ai_repo.SaveVLM(mediaID, result.Caption, result.Tags); err != nil {
			failed[item.MediaID] = err.Error()
		}
	}
}

// ---------- 辅助 ----------

func toSidecarItems(items []MediaItem) []SidecarItem {
	out := make([]SidecarItem, 0, len(items))
	for _, item := range items {
		out = append(out, SidecarItem{ID: item.MediaID, Path: item.Path})
	}
	return out
}

// failAllItems 整个批次失败时，把失败原因落到该批每一条媒体上。
func failAllItems(items []MediaItem, failed map[string]string, err error) {
	for _, item := range items {
		failed[item.MediaID] = err.Error()
	}
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// ---------- 批次中断与暂停 ----------

// PauseRun 暂停处理：中断当前批次，并在 Resume 之前不再认领新任务。
//
// 只中断批次而不暂停是没有意义的——worker 会立刻认领下一批，用户看到的
// 就是"点了中断但还在跑"。返回是否确实中断到了一个正在执行的批次。
func (e *Engine) PauseRun() bool {
	e.paused.Store(true)

	e.runMu.Lock()
	hasRun := e.lastRun != nil && e.lastRun.Running
	e.runMu.Unlock()
	if !hasRun {
		return false
	}

	e.cancelRequested.Store(true)
	e.runCancelMu.Lock()
	cancel := e.runCancel
	e.runCancelMu.Unlock()
	if cancel != nil {
		cancel()
		return true
	}
	return false
}

// ResumeRun 解除暂停并唤醒 worker。
func (e *Engine) ResumeRun() {
	e.paused.Store(false)
	e.Wake()
}

func (e *Engine) setRunCancel(cancel context.CancelFunc) {
	e.runCancelMu.Lock()
	e.runCancel = cancel
	e.runCancelMu.Unlock()
}
