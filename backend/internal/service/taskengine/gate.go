package taskengine

import "sync"

// Gate 按提交顺序分配资源；取消等待者无需等待前面的进程结束。
type Gate struct {
	mu    sync.Mutex
	owner *ticket
	queue []*ticket
}

type ticket struct{ ready chan struct{} }

func (g *Gate) reserve() *ticket {
	g.mu.Lock()
	defer g.mu.Unlock()
	t := &ticket{ready: make(chan struct{})}
	if g.owner == nil {
		g.owner = t
		close(t.ready)
	} else {
		g.queue = append(g.queue, t)
	}
	return t
}

func (g *Gate) release(t *ticket) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.owner == t {
		g.unlock()
		return
	}
	for i, queued := range g.queue {
		if queued == t {
			copy(g.queue[i:], g.queue[i+1:])
			g.queue[len(g.queue)-1] = nil
			g.queue = g.queue[:len(g.queue)-1]
			break
		}
	}
}

func (g *Gate) TryLock() bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.owner != nil {
		return false
	}
	g.owner = &ticket{}
	return true
}

func (g *Gate) Unlock() {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.unlock()
}

func (g *Gate) unlock() {
	g.owner = nil
	if len(g.queue) > 0 {
		g.owner = g.queue[0]
		g.queue[0] = nil
		g.queue = g.queue[1:]
		close(g.owner.ready)
	}
	if len(g.queue) == 0 {
		g.queue = nil
	}
}
