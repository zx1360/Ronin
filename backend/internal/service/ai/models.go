package ai

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
)

// 模型仲裁
//
// 本机只有一块 GPU：两个 4B 模型同时驻留会互相挤占显存，双方都变慢甚至被丢回 CPU。
// 因此同一时刻只允许一个模型在跑，规则如下：
//   - 前台对话（交互式）优先级高：需要另一个模型时直接中断当前工作并释放其显存；
//   - 后台批处理（VLM 自动标注）优先级低：需要另一个模型时先等待，超时才接管。
//     否则用户一边聊天一边被反复打断，比"标注慢一点"糟糕得多。
//
// 被中断的一方通过 [Engine.ModelAbortReason] 读到中断原因，据此给出友好提示而不是
// 报成失败。

// 模型使用优先级。
const (
	// ModelForeground 交互式工作（对话）：可抢占后台工作。
	ModelForeground = iota
	// ModelBackground 后台批处理：不抢占，先等待前台结束。
	ModelBackground
)

// backgroundWaitTimeout 后台工作等待前台释放模型的最长时间，超时后接管。
//
// 是变量而非常量：单元测试需要把它压到毫秒级。
var backgroundWaitTimeout = 5 * time.Minute

// modelSession 一次模型使用期。
type modelSession struct {
	id        int64
	model     string
	label     string
	priority  int
	startedAt time.Time
	cancel    context.CancelFunc
	abort     string // 被中断时的原因（空串表示未被打断）
}

// ModelLease 一次模型使用权。
type ModelLease struct {
	engine  *Engine
	session *modelSession
	ctx     context.Context

	// Notice 本次申请需要提示调用方的说明（抢占/等待了谁），无冲突时为空。
	Notice string
}

// Context 返回本次工作应使用的 ctx（被抢占时会被取消）。
func (l *ModelLease) Context() context.Context { return l.ctx }

// AbortReason 返回本次工作被打断的原因（空串表示未被打断）。
func (l *ModelLease) AbortReason() string {
	arb := &l.engine.arbiter
	arb.mu.Lock()
	defer arb.mu.Unlock()
	return l.session.abort
}

// Release 结束本次使用：取消 ctx 并让出模型。
func (l *ModelLease) Release() {
	if l.session == nil || l.session.cancel == nil {
		return // 未取得使用权的空租约（等待被取消）
	}
	l.session.cancel()
	l.engine.releaseModel(l.session.id)
}

// modelArbiter 模型仲裁状态。
type modelArbiter struct {
	mu       sync.Mutex
	seq      int64
	active   *modelSession
	lastUsed string // 上一次用过的模型：切换时立即卸载，避免两个模型同时驻留
	switched bool   // 因模型切换中断过后台批次（worker 据此把任务退回队列）
	// lastSwitch 最近一次"后台批次被前台抢占"的说明，供桌面端展示
	lastSwitch string
}

// UseModel 申请以 model 执行 label 描述的工作。
//
// 同一时刻只有一个模型在跑（见文件头注释）；调用方必须 Release。
func (e *Engine) UseModel(ctx context.Context, model, label string, priority int) *ModelLease {
	ctx, cancel := context.WithCancel(ctx)
	session, notice := e.acquireModel(ctx, model, label, priority, cancel)
	if session == nil {
		cancel()
		return &ModelLease{engine: e, ctx: ctx, Notice: notice}
	}
	return &ModelLease{
		engine:  e,
		session: session,
		ctx:     ctx,
		Notice:  notice,
	}
}

// acquireModel 按优先级取得模型使用权；ctx 被取消时返回 nil。
func (e *Engine) acquireModel(
	ctx context.Context,
	model, label string,
	priority int,
	cancel context.CancelFunc,
) (*modelSession, string) {
	arb := &e.arbiter
	notice := ""

	for {
		arb.mu.Lock()
		if arb.active == nil || arb.active.model == model {
			arb.seq++
			session := &modelSession{
				id:        arb.seq,
				model:     model,
				label:     label,
				priority:  priority,
				startedAt: time.Now(),
				cancel:    cancel,
			}
			arb.active = session
			// 显存只够一个 4B 模型：换模型时立刻卸载上一个（它的 keep_alive 可能还有数分钟）
			previous := arb.lastUsed
			arb.lastUsed = model
			arb.mu.Unlock()
			if previous != "" && previous != model {
				e.unloadModelAsync(previous)
			}
			return session, notice
		}
		victim := arb.active
		arb.mu.Unlock()

		if priority == ModelForeground {
			notice = fmt.Sprintf("已中断正在运行的%s（%s），本次改用 %s", victim.label, victim.model, model)
			e.abortModelSession(victim, fmt.Sprintf("模型已切换到 %s，本次工作被中断", model))
			log.Printf("[AI:model] %s", notice)
			if victim.priority == ModelBackground {
				e.recordSwitchNotice(fmt.Sprintf("%s 被中断：模型已切换到 %s，任务已退回队列",
					victim.label, model))
			}
			continue
		}

		select {
		case <-ctx.Done():
			return nil, notice
		case <-time.After(time.Second):
		}
		if time.Since(victim.startedAt) > backgroundWaitTimeout {
			notice = fmt.Sprintf("等待 %s 超过 %s，已接管模型使用权（改用 %s）",
				victim.model, backgroundWaitTimeout, model)
			e.abortModelSession(victim, fmt.Sprintf("模型已被后台任务接管（%s）", model))
			log.Printf("[AI:model] %s", notice)
		}
	}
}

// abortModelSession 中断指定会话：调用方随即成为新的使用者。
func (e *Engine) abortModelSession(session *modelSession, reason string) {
	arb := &e.arbiter
	arb.mu.Lock()
	if arb.active != nil && arb.active.id == session.id {
		arb.active = nil
		session.abort = reason
		if session.priority == ModelBackground {
			// 只有后台批次需要"退回队列"这条特殊处理
			arb.switched = true
		}
	}
	arb.mu.Unlock()

	session.cancel()
	// 旧模型的 keep_alive 可能还有数分钟，显式卸载以免与新模型抢显存
	e.unloadModelAsync(session.model)
}

// releaseModel 释放模型使用权（只释放自己那次会话）。
func (e *Engine) releaseModel(sessionID int64) {
	arb := &e.arbiter
	arb.mu.Lock()
	if arb.active != nil && arb.active.id == sessionID {
		arb.active = nil
	}
	arb.mu.Unlock()
}

// unloadModelAsync 尽力卸载模型（失败只记日志，不影响调用方）。
func (e *Engine) unloadModelAsync(model string) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := e.ollama.Unload(ctx, model); err != nil {
			log.Printf("[AI:model] 卸载 %s 失败（不影响新模型加载）: %v", model, err)
		}
	}()
}

// recordSwitchNotice 记录后台批次被抢占的说明（供桌面端展示）。
func (e *Engine) recordSwitchNotice(notice string) {
	arb := &e.arbiter
	arb.mu.Lock()
	arb.lastSwitch = fmt.Sprintf("%s · %s", time.Now().Format("15:04:05"), notice)
	arb.mu.Unlock()
}

// LastSwitchNotice 返回最近一次后台批次被抢占的说明（空串表示没有）。
func (e *Engine) LastSwitchNotice() string {
	arb := &e.arbiter
	arb.mu.Lock()
	defer arb.mu.Unlock()
	return arb.lastSwitch
}

// ActiveModel 返回当前正在使用的模型（空串表示空闲）。
func (e *Engine) ActiveModel() string {
	arb := &e.arbiter
	arb.mu.Lock()
	defer arb.mu.Unlock()
	if arb.active == nil {
		return ""
	}
	return arb.active.model
}

// TakeSwitchAbort 返回"是否因模型切换中断过后台批次"，读取后清空。
//
// worker 据此把未完成的任务退回队列（而不是计一次失败）。
func (e *Engine) TakeSwitchAbort() bool {
	arb := &e.arbiter
	arb.mu.Lock()
	defer arb.mu.Unlock()
	switched := arb.switched
	arb.switched = false
	return switched
}
