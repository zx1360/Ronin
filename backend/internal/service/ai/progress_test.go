package ai

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"sync/atomic"
	"testing"
	"time"

	"monarch/internal/config"
)

func TestProgressDoesNotProbe(t *testing.T) {
	initAITestDB(t)
	var requests atomic.Int32
	ollama := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		_, _ = w.Write([]byte(`{"models":[{"name":"example:latest","capabilities":["vision"]}]}`))
	}))
	defer ollama.Close()
	e := New(nil, config.AiConfig{Enabled: true, OllamaURL: ollama.URL, OllamaVLMCTX: 65536, OllamaKeepAlive: 300 * time.Second})
	defer e.Stop()
	e.rt.vlmModel = "example:latest"
	for i := 0; i < 3; i++ {
		if !e.Progress(t.Context()).SchemaReady {
			t.Fatal("临时库 schema 未就绪")
		}
	}
	if requests.Load() != 0 {
		t.Fatal("进度查询触发了诊断")
	}
	for _, sidecar := range e.sidecars() {
		if sidecar.probe != nil {
			t.Fatal("进度查询探测了 Python 依赖")
		}
	}
	raw, err := os.ReadFile("../../../../contracts/ai.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		ChatInfo ChatInfo `json:"chat_info"`
	}
	if err := json.Unmarshal(raw, &fixture); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		if got := e.ChatInfo(t.Context()); !reflect.DeepEqual(got, fixture.ChatInfo) {
			t.Fatalf("对话契约不符: %+v / %+v", got, fixture.ChatInfo)
		}
	}
	if requests.Load() != 1 {
		t.Fatal("模型清单未共用短期缓存")
	}
	e.RefreshDiagnostics()
	e.ChatInfo(t.Context())
	if requests.Load() != 2 {
		t.Fatal("显式刷新未更新模型清单")
	}
	e.rt.snap.Enabled = false
	e.Status(t.Context())
	if requests.Load() != 2 {
		t.Fatal("AI 关闭时进行了外部探测")
	}
}
