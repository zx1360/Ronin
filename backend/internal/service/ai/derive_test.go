package ai

import (
	"path/filepath"
	"testing"

	"monarch/internal/config"
	"monarch/internal/model"
)

// TestAIDerivedPath 派生路径必须与库内既有的 6.9 万张 `*_ai.jpg` 完全一致，
// 否则会为同一张媒体反复生成、并且永远命中不到缓存。
func TestAIDerivedPath(t *testing.T) {
	config.AppConf.GalleryDir = filepath.Join("C:", "Gallery")
	gallery := config.AppConf.GalleryDir

	cases := []struct {
		name  string
		paths mediaPaths
		want  string
	}{
		{
			name:  "预览图派生",
			paths: mediaPaths{Preview: `2020-03/IMG_20200319_135606_preview.jpg`},
			want:  filepath.Join(gallery, "AI", "2020-03", "IMG_20200319_135606_ai.jpg"),
		},
		{
			name:  "无预览时退回缩略图",
			paths: mediaPaths{Thumb: `2021-08/20210327153608_1_thumb.jpg`},
			want:  filepath.Join(gallery, "AI", "2021-08", "20210327153608_1_ai.jpg"),
		},
		{
			name:  "动图预览（gif）同样派生",
			paths: mediaPaths{Preview: `2022-06/cat_preview.gif`},
			want:  filepath.Join(gallery, "AI", "2022-06", "cat_ai.jpg"),
		},
		{
			name:  "两种派生图都缺失时无法推导",
			paths: mediaPaths{},
			want:  "",
		},
	}

	for _, tc := range cases {
		if got := aiDerivedPath(tc.paths); got != tc.want {
			t.Errorf("%s: aiDerivedPath()=%q, want %q", tc.name, got, tc.want)
		}
	}
}

// TestCapabilitySpecs 能力契约：档位分配符合"轻量能力用 256 档、识别类用 1024 档"，
// 且 VLM 的执行者随所选模型变化（这正是自动重排的依据）。
func TestCapabilitySpecs(t *testing.T) {
	config.AppConf.GalleryDir = filepath.Join("C:", "Gallery")
	e := New(nil, config.AiConfig{EmbedModel: "siglip2-base-patch16-224", OllamaVLM: "model-a"})

	specs := map[string]string{}
	tiers := map[string]string{}
	for _, spec := range e.CapabilitySpecs() {
		specs[spec.Capability] = spec.InputSig
		tiers[spec.Capability] = spec.InputTier
	}

	wantTiers := map[string]string{
		model.CapPHash: model.TierPreview,
		model.CapEmbed: model.TierPreview,
		model.CapFace:  model.TierAI,
		model.CapOCR:   model.TierAI,
		model.CapVLM:   model.TierAI,
	}
	for capability, want := range wantTiers {
		if got := tiers[capability]; got != want {
			t.Errorf("%s 档位不符: got %q, want %q", capability, got, want)
		}
		if specs[capability] == "" {
			t.Errorf("%s 缺少输入指纹", capability)
		}
	}

	// 未指定模型时用配置里的默认模型
	if got := specs[model.CapVLM]; got != "ai1024|ollama:model-a" {
		t.Fatalf("VLM 指纹不符: %q", got)
	}
	// pHash 与档位硬绑定，不随任何配置变化——换配置绝不该让全库重算哈希
	if got := specs[model.CapPHash]; got != "preview256|go-dct-phash" {
		t.Fatalf("pHash 指纹不符: %q", got)
	}
}
