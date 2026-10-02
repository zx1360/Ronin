package ai

import (
	"context"
	"testing"
	"time"

	"monarch/internal/config"
)

// newTestEngine 构造一个不接触真实 Ollama 的引擎（卸载调用会立即连接失败，只留日志）。
func newTestEngine(t *testing.T) *Engine {
	t.Helper()
	return New(nil, config.AiConfig{
		OllamaURL:       "http://127.0.0.1:1", // 不可达：卸载动作在测试里不产生副作用
		OllamaKeepAlive: 5 * time.Minute,
	})
}

// 前台抢占：请求另一个模型时，当前工作被中断并拿到原因。
func TestModelArbitrationForegroundPreempts(t *testing.T) {
	e := newTestEngine(t)

	first := e.UseModel(context.Background(), "model-a", "对话", ModelForeground)
	if first.Context().Err() != nil {
		t.Fatal("首次申请不应被取消")
	}

	second := e.UseModel(context.Background(), "model-b", "对话", ModelForeground)
	defer second.Release()
	if second.Notice == "" {
		t.Fatal("抢占时应给出提示文案")
	}
	if first.Context().Err() == nil {
		t.Fatal("被抢占的会话 ctx 应被取消")
	}
	if first.AbortReason() == "" {
		t.Fatal("被抢占的会话应能读到中断原因")
	}
	if got := e.ActiveModel(); got != "model-b" {
		t.Fatalf("当前模型应为 model-b，实际 %q", got)
	}
	first.Release()

	// 前台被中断不涉及后台批次，不应标记"切换中断"
	if e.TakeSwitchAbort() {
		t.Fatal("前台被抢占不应标记后台批次中断")
	}
}

// 同模型复用：不产生提示，也不取消先前的会话。
func TestModelArbitrationSameModelReuses(t *testing.T) {
	e := newTestEngine(t)

	first := e.UseModel(context.Background(), "model-a", "对话", ModelForeground)
	second := e.UseModel(context.Background(), "model-a", "对话", ModelForeground)
	defer second.Release()
	defer first.Release()

	if second.Notice != "" {
		t.Fatalf("同模型不应给出切换提示: %s", second.Notice)
	}
	if first.Context().Err() != nil {
		t.Fatal("同模型不应中断已有会话")
	}
}

// 前台抢占后台批次：批次拿到"切换中断"标记，worker 据此把任务退回队列。
func TestModelArbitrationForegroundPreemptsBackgroundBatch(t *testing.T) {
	e := newTestEngine(t)

	batch := e.UseModel(context.Background(), "model-a", "VLM 自动标注", ModelBackground)
	chat := e.UseModel(context.Background(), "model-b", "对话", ModelForeground)
	defer chat.Release()

	if chat.Notice == "" {
		t.Fatal("抢占后台批次时应给出提示文案")
	}
	if batch.Context().Err() == nil {
		t.Fatal("被抢占的批次 ctx 应被取消")
	}
	if batch.AbortReason() == "" {
		t.Fatal("被抢占的批次应能读到中断原因")
	}
	if !e.TakeSwitchAbort() {
		t.Fatal("后台批次被抢占应标记为可退回队列的中断")
	}
	if e.TakeSwitchAbort() {
		t.Fatal("中断标记读取后应清空")
	}
	batch.Release()
}

// 后台等待：前台在跑时，后台批处理等待而不是打断它。
func TestModelArbitrationBackgroundWaits(t *testing.T) {
	e := newTestEngine(t)

	foreground := e.UseModel(context.Background(), "model-a", "对话", ModelForeground)

	acquired := make(chan *ModelLease, 1)
	go func() {
		acquired <- e.UseModel(context.Background(), "model-b", "VLM 自动标注", ModelBackground)
	}()

	// 等待期间不应拿到使用权，前台也不应被取消
	select {
	case <-acquired:
		t.Fatal("后台工作不应立即抢占前台")
	case <-time.After(300 * time.Millisecond):
	}
	if foreground.Context().Err() != nil {
		t.Fatal("等待中的后台工作不应取消前台会话")
	}

	// 前台释放后，后台应接手
	foreground.Release()
	select {
	case lease := <-acquired:
		defer lease.Release()
		if lease.AbortReason() != "" {
			t.Fatalf("正常接手不应有中断原因: %s", lease.AbortReason())
		}
		if lease.Context().Err() != nil {
			t.Fatal("接手后的 ctx 应可用")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("前台释放后后台未接手")
	}
}

// 后台超时接管：前台长时间占着模型时，后台到期接管并中断前台工作
// （被中断的是前台，不涉及批次退回，因此不应置位"切换中断"）。
func TestModelArbitrationBackgroundTakesOverOnTimeout(t *testing.T) {
	original := backgroundWaitTimeout
	backgroundWaitTimeout = 200 * time.Millisecond
	defer func() { backgroundWaitTimeout = original }()

	e := newTestEngine(t)
	foreground := e.UseModel(context.Background(), "model-a", "对话", ModelForeground)

	lease := e.UseModel(context.Background(), "model-b", "VLM 自动标注", ModelBackground)
	defer lease.Release()

	if lease.Notice == "" {
		t.Fatal("超时接管应给出提示文案")
	}
	if foreground.Context().Err() == nil {
		t.Fatal("超时接管时应取消原会话")
	}
	if foreground.AbortReason() == "" {
		t.Fatal("被接管的前台会话应能读到中断原因")
	}
	if e.TakeSwitchAbort() {
		t.Fatal("前台被接管不涉及后台批次退回")
	}
	foreground.Release()
}

// 释放后可以重新申请，且模型名会切换。
func TestModelArbitrationReleaseAllowsSwitch(t *testing.T) {
	e := newTestEngine(t)

	first := e.UseModel(context.Background(), "model-a", "对话", ModelForeground)
	first.Release()
	if got := e.ActiveModel(); got != "" {
		t.Fatalf("释放后应为空闲，实际 %q", got)
	}

	second := e.UseModel(context.Background(), "model-b", "VLM 自动标注", ModelBackground)
	defer second.Release()
	if second.Notice != "" {
		t.Fatalf("空闲时申请不应有提示: %s", second.Notice)
	}
	if got := e.ActiveModel(); got != "model-b" {
		t.Fatalf("当前模型应为 model-b，实际 %q", got)
	}
}

// 父 ctx 取消后，后台等待应立即放弃。
func TestModelArbitrationBackgroundCancel(t *testing.T) {
	e := newTestEngine(t)
	foreground := e.UseModel(context.Background(), "model-a", "对话", ModelForeground)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		lease := e.UseModel(ctx, "model-b", "VLM 自动标注", ModelBackground)
		lease.Release()
		close(done)
	}()

	time.Sleep(200 * time.Millisecond)
	cancel()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("父 ctx 取消后后台等待应立即结束")
	}
	foreground.Release()
}
