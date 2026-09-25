package gallery_handler

import (
	"testing"

	"github.com/google/uuid"

	"monarch/internal/model"
)

func TestNormalizeJSONText(t *testing.T) {
	tests := []struct {
		name    string
		raw     string
		want    string
		wantErr bool
	}{
		{name: "JSON 对象原文", raw: `{"type":"image","rotation":90}`, want: `{"type":"image","rotation":90}`},
		{name: "JSON 数组原文", raw: `[1,2]`, want: `[1,2]`},
		{name: "JSON 字符串包裹对象", raw: `"{\"type\":\"video\"}"`, want: `{"type":"video"}`},
		{name: "空字符串对象", raw: `"   "`, want: ""},
		{name: "空对象保留", raw: `{}`, want: `{}`},
		{name: "非法内容", raw: `not-json`, wantErr: true},
		{name: "字符串里不是合法 JSON", raw: `"just text"`, wantErr: true},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := normalizeJSONText(tc.raw)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("期望报错，实际得到 %q", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("不应报错: %v", err)
			}
			if got != tc.want {
				t.Fatalf("期望 %q，实际 %q", tc.want, got)
			}
		})
	}
}

func TestValidateUUIDList(t *testing.T) {
	if err := validateUUIDList("", "ids"); err != nil {
		t.Fatalf("空串应合法: %v", err)
	}
	if err := validateUUIDList("  ", "ids"); err != nil {
		t.Fatalf("空白应合法: %v", err)
	}
	valid := uuid.New().String() + "," + uuid.New().String()
	if err := validateUUIDList(valid, "ids"); err != nil {
		t.Fatalf("合法列表不应报错: %v", err)
	}
	if err := validateUUIDList(valid+",oops", "tag_ids"); err == nil {
		t.Fatal("含非法 UUID 时应报错")
	}
}

func TestIsVideoAsset(t *testing.T) {
	video := "video/mp4"
	image := "image/jpeg"
	noMime := ""

	tests := []struct {
		name string
		path string
		mime *string
		want bool
	}{
		{name: "按 MIME", path: "2024/a.bin", mime: &video, want: true},
		// MIME 是"是视频"的正向证据；扩展名是 MIME 缺失/不匹配时的兜底判定
		{name: "MIME 为图片但扩展名是视频仍判为视频", path: "2024/a.mp4", mime: &image, want: true},
		{name: "按扩展名回退", path: "2024/a.MP4", mime: &noMime, want: true},
		{name: "MIME 缺失按扩展名", path: "2024/a.mkv", mime: nil, want: true},
		{name: "普通图片", path: "2024/a.jpg", mime: &image, want: false},
		{name: "短 MIME 不应越界", path: "2024/a.jpg", mime: stringPtr("vid"), want: false},
		{name: "空 MIME 不应越界", path: "2024/a.jpg", mime: stringPtr(""), want: false},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			asset := &model.MediaAsset{FilePath: tc.path, MimeType: tc.mime}
			if got := isVideoAsset(asset); got != tc.want {
				t.Fatalf("期望 %v，实际 %v", tc.want, got)
			}
		})
	}
}

func stringPtr(s string) *string { return &s }
