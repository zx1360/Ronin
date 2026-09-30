package gallery_repo

import (
	"strings"
	"testing"

	"github.com/google/uuid"

	"monarch/internal/model"
)

func TestMediaAssetColumns(t *testing.T) {
	plain := mediaAssetColumns("")
	if strings.Contains(plain, "m.") {
		t.Fatalf("无别名时不应带表前缀: %s", plain)
	}
	// COALESCE(message, '') 自带逗号，按列清单逐个核对存在性
	for _, col := range mediaAssetColumnList {
		if !strings.Contains(plain, col) {
			t.Fatalf("缺少列 %q: %s", col, plain)
		}
	}
	// COALESCE(message, '') 必须整体加前缀，不能拆坏括号
	aliased := mediaAssetColumns("m")
	if !strings.Contains(aliased, "COALESCE(m.message, '')") {
		t.Fatalf("别名列的 COALESCE 处理错误: %s", aliased)
	}
	if !strings.Contains(aliased, "m.captured_at") {
		t.Fatalf("普通列应加别名: %s", aliased)
	}
}

func TestBuildBatchWhereClause(t *testing.T) {
	tests := []struct {
		name       string
		params     model.BatchQueryParams
		wantCond   []string
		wantArgLen int
	}{
		{
			name:       "仅默认条件",
			params:     model.BatchQueryParams{},
			wantCond:   []string{"is_deleted = 0"},
			wantArgLen: 0,
		},
		{
			name:       "MIME 大类前缀匹配",
			params:     model.BatchQueryParams{MimeType: "image"},
			wantCond:   []string{"mime_type LIKE ?"},
			wantArgLen: 1,
		},
		{
			name:       "MIME 精确匹配",
			params:     model.BatchQueryParams{MimeType: "image/jpeg"},
			wantCond:   []string{"mime_type = ?"},
			wantArgLen: 1,
		},
		{
			name:       "按年",
			params:     model.BatchQueryParams{Year: 2024},
			wantCond:   []string{"CAST(strftime('%Y', captured_at) AS INTEGER) = ?"},
			wantArgLen: 1,
		},
		{
			name:   "按年月",
			params: model.BatchQueryParams{Year: 2024, Month: 6},
			wantCond: []string{"CAST(strftime('%Y', captured_at) AS INTEGER) = ? AND " +
				"CAST(strftime('%m', captured_at) AS INTEGER) = ?"},
			wantArgLen: 2,
		},
		{
			name:       "按年月日",
			params:     model.BatchQueryParams{Year: 2024, Month: 6, Day: 3},
			wantCond:   []string{"date(captured_at) = ?"},
			wantArgLen: 1,
		},
		{
			name:       "有月无年时不加年份条件",
			params:     model.BatchQueryParams{Month: 6},
			wantCond:   []string{"is_deleted = 0"},
			wantArgLen: 0,
		},
		{
			name:   "MIME + 年月组合的条件同时生效",
			params: model.BatchQueryParams{MimeType: "video", Year: 2023, Month: 12},
			wantCond: []string{"mime_type LIKE ?",
				"CAST(strftime('%Y', captured_at) AS INTEGER) = ? AND " +
					"CAST(strftime('%m', captured_at) AS INTEGER) = ?"},
			wantArgLen: 3,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			where, args := buildBatchWhereClause(tc.params)
			for _, cond := range tc.wantCond {
				if !strings.Contains(where, cond) {
					t.Fatalf("WHERE 缺少条件 %q，实际: %s", cond, where)
				}
			}
			if len(args) != tc.wantArgLen {
				t.Fatalf("参数个数应为 %d，实际 %d (%v)", tc.wantArgLen, len(args), args)
			}
		})
	}
}

func TestBuildBatchOrderClause(t *testing.T) {
	tests := []struct {
		name   string
		params model.BatchQueryParams
		want   string
	}{
		{
			name:   "默认按 sync_count 升序",
			params: model.BatchQueryParams{},
			want:   "sync_count ASC, captured_at ASC, id ASC",
		},
		{
			name:   "降序同时作用于主排序与兜底排序",
			params: model.BatchQueryParams{SortOrder: "desc"},
			want:   "sync_count DESC, captured_at DESC, id ASC",
		},
		{
			name:   "主排序即兜底字段时不重复",
			params: model.BatchQueryParams{SortBy: "captured_at"},
			want:   "captured_at ASC, id ASC",
		},
		{
			name:   "非法排序字段回退默认",
			params: model.BatchQueryParams{SortBy: "drop table"},
			want:   "sync_count ASC, captured_at ASC, id ASC",
		},
		{
			name:   "支持二次排序",
			params: model.BatchQueryParams{SortBy: "size_bytes", SecondarySort: "file_path"},
			want:   "size_bytes ASC, captured_at ASC, file_path ASC, id ASC",
		},
		{
			name:   "二次排序与已有键重复时忽略",
			params: model.BatchQueryParams{SortBy: "size_bytes", SecondarySort: "captured_at"},
			want:   "size_bytes ASC, captured_at ASC, id ASC",
		},
		{
			name:   "非法二次排序字段被忽略",
			params: model.BatchQueryParams{SecondarySort: "1; DROP"},
			want:   "sync_count ASC, captured_at ASC, id ASC",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := buildBatchOrderClause(tc.params); got != tc.want {
				t.Fatalf("ORDER BY 不符\n期望: %s\n实际: %s", tc.want, got)
			}
		})
	}
}

func TestBuildMediaOrderClause(t *testing.T) {
	if got := buildMediaOrderClause(model.MediaQueryParams{}); got != "m.captured_at DESC, m.id ASC" {
		t.Fatalf("默认排序错误: %s", got)
	}
	if got := buildMediaOrderClause(model.MediaQueryParams{SortBy: "sync_count", SortOrder: "asc"}); got != "m.sync_count ASC, m.id ASC" {
		t.Fatalf("指定排序错误: %s", got)
	}
	if got := buildMediaOrderClause(model.MediaQueryParams{SortBy: "bad"}); got != "m.captured_at DESC, m.id ASC" {
		t.Fatalf("非法字段应回退默认: %s", got)
	}
}

func TestIsValidSortField(t *testing.T) {
	for _, field := range []string{"captured_at", "sync_count", "size_bytes", "file_path"} {
		if !IsValidSortField(field) {
			t.Fatalf("%s 应被允许", field)
		}
	}
	for _, field := range []string{"", "id", "hash", "drop"} {
		if IsValidSortField(field) {
			t.Fatalf("%s 不应被允许", field)
		}
	}
}

func TestParseUUIDList(t *testing.T) {
	a, b := uuid.New(), uuid.New()
	got := parseUUIDList(" " + a.String() + " , " + b.String() + " , not-a-uuid, ")
	if len(got) != 2 || got[0] != a || got[1] != b {
		t.Fatalf("应解析出 2 个合法 UUID 并忽略非法项，实际: %v", got)
	}
	if parseUUIDList("") != nil || parseUUIDList("  ") != nil {
		t.Fatal("空串应返回 nil")
	}
}

func TestUniqueUUIDs(t *testing.T) {
	a, b := uuid.New(), uuid.New()
	got := uniqueUUIDs([]uuid.UUID{a, b, a, b, a})
	if len(got) != 2 || got[0] != a || got[1] != b {
		t.Fatalf("去重应保持首次出现顺序，实际: %v", got)
	}
}

func TestSetBuilder(t *testing.T) {
	var b setBuilder
	if !b.isEmpty() {
		t.Fatal("初始应为空")
	}
	b.add("name = ?", "x")
	b.add("is_favorite = ?", true)
	b.raw("group_id = NULL")
	if b.isEmpty() {
		t.Fatal("添加字段后不应为空")
	}

	query, args := b.build("tags", "id = ?", uuid.Nil)
	want := "UPDATE tags SET name = ?, is_favorite = ?, group_id = NULL WHERE id = ?"
	if query != want {
		t.Fatalf("SQL 不符\n期望: %s\n实际: %s", want, query)
	}
	if len(args) != 3 {
		t.Fatalf("参数个数应为 3，实际 %d", len(args))
	}
}

func TestMediaAssetColumnListMatchesScanner(t *testing.T) {
	// scanMediaAssets 按固定顺序扫描 15 个字段；列清单长度变化必须同步修改它
	if len(mediaAssetColumnList) != 15 {
		t.Fatalf("列数应与 scanMediaAssets 的扫描字段数一致(15)，实际 %d", len(mediaAssetColumnList))
	}
}
