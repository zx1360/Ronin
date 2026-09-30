package ai

import (
	"testing"
	"time"

	"monarch/internal/config"
)

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

// TestSupportsThinking 带命名空间的社区模型（无审查版）同样要能开启"深度思考"。
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
