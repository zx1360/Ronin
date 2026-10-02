package ai

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"monarch/internal/config"
)

// TestListModelInfo 模型清单以本机 Ollama 为唯一真源：
// capabilities 里有 vision 才算视觉模型，未上报时才退回模型族启发式判断。
func TestListModelInfo(t *testing.T) {
	const tags = `{"models":[
	  {"name":"qwen3.5:4b","capabilities":["completion","vision","tools","thinking"],
	   "details":{"family":"qwen35","families":["qwen35"]}},
	  {"name":"huihui_ai/qwen3.5-abliterated:4b","capabilities":["completion","vision","thinking"],
	   "details":{"family":"qwen35","families":["qwen35"]}},
	  {"name":"text-only:latest","capabilities":["completion","tools"],
	   "details":{"family":"llama","families":["llama"]}},
	  {"name":"legacy-vl:latest","details":{"family":"clip","families":["clip"]}}
	]}`

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/tags" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		_, _ = w.Write([]byte(tags))
	}))
	defer server.Close()

	o := NewOllama(config.AiConfig{OllamaURL: server.URL}, nil)
	models, err := o.ListModelInfo(t.Context())
	if err != nil {
		t.Fatalf("读取模型清单失败: %v", err)
	}
	if len(models) != 4 {
		t.Fatalf("模型条数不符: %d", len(models))
	}

	cases := map[string]struct{ vision, thinking bool }{
		"qwen3.5:4b":                       {true, true},
		"huihui_ai/qwen3.5-abliterated:4b": {true, true},
		"text-only:latest":                 {false, false},
		"legacy-vl:latest":                 {true, false}, // 未上报 capabilities：按模型族判断
	}
	for _, info := range models {
		want, ok := cases[info.Name]
		if !ok {
			t.Fatalf("出现预期外的模型: %s", info.Name)
		}
		if info.Vision != want.vision || info.Thinking != want.thinking {
			t.Errorf("%s: vision=%v thinking=%v, want vision=%v thinking=%v",
				info.Name, info.Vision, info.Thinking, want.vision, want.thinking)
		}
	}

	names, err := o.ListModels(t.Context())
	if err != nil || len(names) != 4 {
		t.Fatalf("ListModels 不符: n=%d err=%v", len(names), err)
	}
}

// TestKeepAliveMapping 确认 keep_alive 的三态语义：负数沿用服务端默认、
// 0 表示回答完立即卸载（必须真实下发，不能被当成"未指定"）。
func TestKeepAliveMapping(t *testing.T) {
	o := NewOllama(config.AiConfig{OllamaKeepAlive: 300 * time.Second}, nil)

	cases := []struct {
		name     string
		override int
		want     int
	}{
		{"未指定", -1, 300},
		{"立即卸载", 0, 0},
		{"显式秒数", 45, 45},
		{"超长驻留", 3600, 3600},
	}
	for _, tc := range cases {
		if got := o.keepAliveSeconds(tc.override); got != tc.want {
			t.Errorf("%s: keepAliveSeconds(%d)=%d, want %d",
				tc.name, tc.override, got, tc.want)
		}
	}
}

// TestSupportsThinking 带命名空间的社区重打包模型（如 abliteration 版）同样要能开启"深度思考"。
func TestSupportsThinking(t *testing.T) {
	cases := map[string]bool{
		"qwen3.5:4b":                       true,
		"huihui_ai/qwen3.5-abliterated:4b": true,
		"deepseek-r1:7b":                   true,
		"library/thinking-model:latest":    true,
		"llava:13b":                        false,
		"qwen2.5:0.5b":                     false,
	}
	for model, want := range cases {
		if got := SupportsThinking(model); got != want {
			t.Errorf("SupportsThinking(%q)=%v, want %v", model, got, want)
		}
	}
}
