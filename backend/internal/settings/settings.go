// Package settings 管理"用户会接触并修改"的运行时配置。
//
// 分层原则：.env 只保留连库之前就必须知道的项（见 config.Bootstrap）；
// 其余配置全部落在 SQLite 的 app_settings 表，由 UI 通过 /API/settings 读写。
// 本包只用字符串存取，取到的值由 config.ApplySettings 解释成类型化配置。
package settings

import (
	"context"
	"database/sql"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"sync"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// Kind 决定 UI 用哪种控件渲染。
type Kind string

const (
	KindString Kind = "string"
	KindInt    Kind = "int"
	KindBool   Kind = "bool"
	KindSelect Kind = "select"
	KindMulti  Kind = "multi"
	KindPath   Kind = "path"
)

// Option 是 select / multi 的候选项。
type Option struct {
	Value string `json:"value"`
	Label string `json:"label"`
}

// Spec 描述一项配置：默认值、取值范围与 UI 元信息都由后端下发，消费端不硬编码。
type Spec struct {
	Key     string   `json:"key"`
	Section string   `json:"section"`
	Label   string   `json:"label"`
	Help    string   `json:"help,omitempty"`
	Kind    Kind     `json:"kind"`
	Default string   `json:"default"`
	Options []Option `json:"options,omitempty"`
	Min     int      `json:"min,omitempty"`
	Max     int      `json:"max,omitempty"`
	// Restart 为 true 表示改动要重启服务才生效（UI 需提示）。
	Restart bool `json:"restart,omitempty"`
}

// Specs 是全部可配置项。顺序即 UI 展示顺序。
var Specs = []Spec{
	// ---- 应用 ----
	{Key: "app.static_dir", Section: "app", Label: "静态资源目录", Kind: KindPath,
		Default: "./static", Help: "HTTP 服务对外暴露的目录（日志、comics、img_storage 等）"},
	{Key: "app.gallery_dir", Section: "app", Label: "媒体库根目录", Kind: KindPath,
		Default: "", Help: "gallery 的 Media/Thumbs/Preview/AI 派生目录所在根路径", Restart: true},
	{Key: "app.ops_dir", Section: "app", Label: "ops 网页目录", Kind: KindPath,
		Default: "", Help: "留空则自动定位仓库中的 ops/", Restart: true},
	{Key: "app.gallery_cli", Section: "app", Label: "gallery CLI 路径", Kind: KindPath,
		Default: "", Help: "留空则自动定位 gizmos/gallery(.exe)", Restart: true},

	// ---- 媒体库 CLI ----
	{Key: "comix.python", Section: "comix", Label: "comix Python 解释器", Kind: KindString,
		Default: "python", Help: "gizmos/comix 侧车使用的解释器（需已安装 requirements.txt）", Restart: true},
	{Key: "comix.storage_root", Section: "comix", Label: "漫画存储根目录", Kind: KindPath,
		Default: "", Help: "漫画图片落盘根目录；空表示 static/comics"},
	{Key: "comix.max_workers", Section: "comix", Label: "下载并发数", Kind: KindInt,
		Default: "2", Min: 1, Max: 8},

	// ---- AI 总开关与进程 ----
	{Key: "ai.enabled", Section: "ai", Label: "启用 AI 处理层", Kind: KindBool,
		Default: "true", Help: "关闭后不启动任何 AI worker，检索与标注接口返回明确错误"},
	{Key: "ai.python", Section: "ai", Label: "侧车 Python 解释器", Kind: KindString,
		Default: "", Help: "留空则自动探测 tools/ai/.venv", Restart: true},
	{Key: "ai.sidecar_dir", Section: "ai", Label: "侧车项目目录", Kind: KindPath,
		Default: "./tools/ai", Restart: true},
	{Key: "ai.device", Section: "ai", Label: "推理设备", Kind: KindSelect,
		Default: "auto", Options: []Option{{"auto", "自动（Windows 上 face/ocr 走 DirectML）"}, {"cpu", "仅 CPU"}},
		Help: "向量编码固定 CPU：换执行提供者会改变向量数值"},
	{Key: "ai.idle_timeout", Section: "ai", Label: "侧车空闲退出（秒）", Kind: KindInt, Default: "120", Min: 1, Max: 86400},
	{Key: "ai.batch_size", Section: "ai", Label: "单批媒体数", Kind: KindInt, Default: "16", Min: 1, Max: 512},
	{Key: "ai.job_timeout", Section: "ai", Label: "单批超时（秒）", Kind: KindInt, Default: "900", Min: 1, Max: 86400},
	{Key: "ai.max_attempts", Section: "ai", Label: "单条最大尝试次数", Kind: KindInt, Default: "3", Min: 1, Max: 20},
	{Key: "ai.auto_capabilities", Section: "ai", Label: "入库后自动处理", Kind: KindMulti,
		Default: defaultAutoCapabilities(), Options: capabilityOptions(),
		Help: "空表示关闭自动入队，只能手动提交"},

	// ---- AI 执行者（能力实现 / 模型）----
	{Key: "ai.embed_model", Section: "ai", Label: "向量模型", Kind: KindString,
		Default: "siglip2-base-patch16-224",
		Help:    "必须是多语种分词器版本；更换会使既有向量失效并自动重排"},
	{Key: "ai.vlm_model", Section: "ai", Label: "VLM 标注模型", Kind: KindString,
		Default: "qwen3.5:4b", Help: "候选名单由 /API/ai/capabilities 下发"},

	// ---- Ollama ----
	{Key: "ai.ollama.url", Section: "ai", Label: "Ollama 地址", Kind: KindString,
		Default: "http://127.0.0.1:11434"},
	{Key: "ai.ollama.vlm_model_alt", Section: "ai", Label: "VLM 备选模型", Kind: KindString,
		Default: "huihui_ai/qwen3.5-abliterated:4B"},
	{Key: "ai.ollama.vlm_ctx", Section: "ai", Label: "VLM 上下文长度", Kind: KindInt,
		Default: "65536", Min: 2048, Max: 262144, Help: "必须显式下发，否则 Ollama 会撑爆显存"},
	{Key: "ai.ollama.keep_alive", Section: "ai", Label: "对话模型驻留（秒）", Kind: KindInt,
		Default: "300", Min: 0, Max: 86400},
	{Key: "ai.ollama.idle_timeout", Section: "ai", Label: "自拉 Ollama 回收（秒）", Kind: KindInt,
		Default: "360", Min: 1, Max: 86400, Help: "需大于模型 keep_alive"},
	{Key: "ai.ollama.exe", Section: "ai", Label: "Ollama 可执行文件", Kind: KindPath,
		Default: "", Help: "留空从 PATH 探测"},
	{Key: "ai.ollama.models", Section: "ai", Label: "Ollama 模型库目录", Kind: KindPath,
		Default: "", Help: "自拉 ollama serve 时指向用户既有模型库", Restart: true},
}

// capabilityOptions 把能力登记转成多选项控件（值即能力标识）。
func capabilityOptions() []Option {
	out := make([]Option, 0, len(model.Capabilities))
	for _, c := range model.Capabilities {
		out = append(out, Option{Value: c.ID, Label: c.ID})
	}
	return out
}

// defaultAutoCapabilities 默认自动处理的能力：登记里标了 AutoDefault 的那些。
func defaultAutoCapabilities() string {
	ids := make([]string, 0, len(model.Capabilities))
	for _, c := range model.Capabilities {
		if c.AutoDefault {
			ids = append(ids, c.ID)
		}
	}
	return strings.Join(ids, ",")
}

var specByKey = func() map[string]Spec {
	m := make(map[string]Spec, len(Specs))
	for _, s := range Specs {
		m[s.Key] = s
	}
	return m
}()

var (
	mu     sync.RWMutex
	values = map[string]string{}
)

// Load 把数据库中的覆盖值读入内存（服务启动时调用一次）。
func Load(ctx context.Context) error {
	rows, err := db.R().QueryContext(ctx, `SELECT key, value FROM app_settings`)
	if err != nil {
		return fmt.Errorf("读取运行时配置失败: %w", err)
	}
	defer rows.Close()

	loaded := make(map[string]string)
	for rows.Next() {
		var k, v string
		if err := rows.Scan(&k, &v); err != nil {
			return fmt.Errorf("扫描运行时配置失败: %w", err)
		}
		loaded[k] = v
	}
	if err := rows.Err(); err != nil {
		return err
	}

	mu.Lock()
	values = loaded
	mu.Unlock()
	return nil
}

// Get 返回生效值：数据库覆盖优先，否则用 Spec 默认值。
func Get(key string) string {
	mu.RLock()
	v, ok := values[key]
	mu.RUnlock()
	if ok {
		return v
	}
	if s, ok := specByKey[key]; ok {
		return s.Default
	}
	return ""
}

// GetCSV 读取逗号分隔的多值配置。
func GetCSV(key string) []string {
	var out []string
	for _, part := range strings.Split(Get(key), ",") {
		if part = strings.TrimSpace(part); part != "" {
			out = append(out, part)
		}
	}
	return out
}

// All 返回全部键的生效值（含默认值填充），供 config.ApplySettings 使用。
func All() map[string]string {
	out := make(map[string]string, len(Specs))
	mu.RLock()
	defer mu.RUnlock()
	for _, s := range Specs {
		if v, ok := values[s.Key]; ok {
			out[s.Key] = v
		} else {
			out[s.Key] = s.Default
		}
	}
	return out
}

// Schema 返回全部配置项的描述，供 UI 生成表单。
func Schema() []Spec {
	out := make([]Spec, len(Specs))
	copy(out, Specs)
	return out
}

// Update 校验并写入一批配置；返回实际写入的键（已排序）。
func Update(ctx context.Context, patch map[string]string) ([]string, error) {
	normalized := make(map[string]string, len(patch))
	for key, raw := range patch {
		spec, ok := specByKey[key]
		if !ok {
			return nil, fmt.Errorf("未知的配置项: %s", key)
		}
		v, err := normalize(spec, raw)
		if err != nil {
			return nil, err
		}
		normalized[key] = v
	}
	if len(normalized) == 0 {
		return nil, nil
	}

	now := model.Now()
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		for key, value := range normalized {
			if _, err := tx.ExecContext(ctx,
				`INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)
				 ON CONFLICT (key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
				key, value, now); err != nil {
				return fmt.Errorf("写入配置 %s 失败: %w", key, err)
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	changed := make([]string, 0, len(normalized))
	mu.Lock()
	for k, v := range normalized {
		values[k] = v
		changed = append(changed, k)
	}
	mu.Unlock()

	sort.Strings(changed)
	return changed, nil
}

// normalize 按 Spec 校验并归一化单个值。
func normalize(spec Spec, raw string) (string, error) {
	raw = strings.TrimSpace(raw)
	switch spec.Kind {
	case KindBool:
		b, err := strconv.ParseBool(strings.ToLower(raw))
		if err != nil {
			return "", fmt.Errorf("%s 需要布尔值", spec.Key)
		}
		return strconv.FormatBool(b), nil
	case KindInt:
		n, err := strconv.Atoi(raw)
		if err != nil {
			return "", fmt.Errorf("%s 需要整数", spec.Key)
		}
		if spec.Min != 0 && n < spec.Min || spec.Max != 0 && n > spec.Max {
			return "", fmt.Errorf("%s 超出范围 [%d, %d]", spec.Key, spec.Min, spec.Max)
		}
		return strconv.Itoa(n), nil
	case KindSelect:
		for _, o := range spec.Options {
			if o.Value == raw {
				return raw, nil
			}
		}
		return "", fmt.Errorf("%s 的取值不在候选中: %s", spec.Key, raw)
	case KindMulti:
		seen := map[string]bool{}
		var picked []string
		for _, part := range strings.Split(raw, ",") {
			part = strings.TrimSpace(part)
			if part == "" || seen[part] {
				continue
			}
			valid := false
			for _, o := range spec.Options {
				if o.Value == part {
					valid = true
					break
				}
			}
			if !valid {
				return "", fmt.Errorf("%s 的取值不在候选中: %s", spec.Key, part)
			}
			seen[part] = true
			picked = append(picked, part)
		}
		sort.Strings(picked)
		return strings.Join(picked, ","), nil
	default:
		return raw, nil
	}
}
