package ai_handler_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"monarch/internal/config"
	"monarch/internal/router"
	"monarch/internal/service/ai"
	"monarch/internal/service/db"
)

func TestReviewStream(t *testing.T) {
	temp := t.TempDir()
	if err := db.Init(config.DbConfig{File: filepath.Join(temp, "review.db"), SchemaFile: "../../../references/db/sqlite.sql"}); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(db.Close)

	ollama := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/tags":
			io.WriteString(w, `{"models":[{"name":"test:latest","capabilities":["completion"]}]}`)
		case "/api/chat":
			io.WriteString(w, `{"message":{"content":"回顾正文"},"done":true}`+"\n")
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(ollama.Close)

	previous := ai.Default
	t.Cleanup(func() { ai.Default = previous })
	t.Setenv("API_KEY_SERVER", "review-test-key")
	routes := router.SetupRouter()
	request := func(enabled bool, body string) *httptest.ResponseRecorder {
		engine := ai.New(nil, config.AiConfig{
			Enabled: enabled, OllamaURL: ollama.URL, OllamaVLMCTX: 4096,
			OllamaExe: filepath.Join(temp, "no-ollama.exe"),
		})
		defer engine.Stop()
		ai.Default = engine
		req := httptest.NewRequest(http.MethodPost, "/API/ai/review", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-API-Key", "review-test-key")
		response := httptest.NewRecorder()
		routes.ServeHTTP(response, req)
		return response
	}

	const body = `{"role":"测试","model":"test:latest","days":1,"sample_essays":0,"sample_records":0}`
	invalid := request(true, `{"days":1}`)
	if invalid.Code != http.StatusBadRequest || !strings.Contains(invalid.Body.String(), "role") {
		t.Fatalf("缺少角色时应返回 400，得到 %d %s", invalid.Code, invalid.Body)
	}

	disabled := request(false, body)
	if disabled.Code != http.StatusServiceUnavailable ||
		!strings.HasPrefix(disabled.Header().Get("Content-Type"), "application/json") ||
		!strings.Contains(disabled.Body.String(), "服务端未启用 AI") {
		t.Fatalf("AI 禁用时应返回 JSON 503，得到 %d %s", disabled.Code, disabled.Body)
	}

	response := request(true, body)
	if response.Code != http.StatusOK || !response.Flushed || !strings.HasPrefix(response.Header().Get("Content-Type"), "application/x-ndjson") {
		t.Fatalf("应返回 NDJSON 200，得到 %d %s", response.Code, response.Body)
	}
	decoder := json.NewDecoder(response.Body)
	for _, want := range []ai.ChatEvent{
		{Type: "stats", Content: "统计范围"},
		{Type: "delta", Content: "回顾正文"},
		{Type: "done"},
	} {
		var got ai.ChatEvent
		if err := decoder.Decode(&got); err != nil || got.Type != want.Type || !strings.Contains(got.Content, want.Content) {
			t.Fatalf("回顾事件不符，期望 %+v，得到 %+v (%v)", want, got, err)
		}
	}
	if err := decoder.Decode(new(ai.ChatEvent)); err != io.EOF {
		t.Fatalf("done 后应结束响应，得到 %v", err)
	}
}
