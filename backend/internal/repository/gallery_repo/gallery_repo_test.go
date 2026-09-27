package gallery_repo

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// ============ 纯函数单测 ============

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
			wantCond:   []string{"is_deleted = false"},
			wantArgLen: 0,
		},
		{
			name:       "MIME 大类前缀匹配",
			params:     model.BatchQueryParams{MimeType: "image"},
			wantCond:   []string{`mime_type LIKE ? ESCAPE '\'`},
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
			wantCond:   []string{"substr(captured_at, 1, 4) = ?"},
			wantArgLen: 1,
		},
		{
			name:       "按年月",
			params:     model.BatchQueryParams{Year: 2024, Month: 6},
			wantCond:   []string{"substr(captured_at, 1, 4) = ? AND substr(captured_at, 6, 2) = ?"},
			wantArgLen: 2,
		},
		{
			name:       "按年月日",
			params:     model.BatchQueryParams{Year: 2024, Month: 6, Day: 3},
			wantCond:   []string{"substr(captured_at, 1, 10) = ?"},
			wantArgLen: 1,
		},
		{
			name:       "有月无年时不加年份条件",
			params:     model.BatchQueryParams{Month: 6},
			wantCond:   []string{"is_deleted = false"},
			wantArgLen: 0,
		},
		{
			name:       "MIME + 年月组合",
			params:     model.BatchQueryParams{MimeType: "video", Year: 2023, Month: 12},
			wantCond:   []string{"mime_type LIKE ?", "substr(captured_at, 1, 4) = ? AND substr(captured_at, 6, 2) = ?"},
			wantArgLen: 3,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			where, args := buildBatchWhereClause(tc.params)
			if strings.Contains(where, "$") {
				t.Fatalf("SQLite 占位符必须是 ?，实际: %s", where)
			}
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

	query, args := b.build("gallery_tags", "id = ?", uuid.Nil)
	want := "UPDATE gallery_tags SET name = ?, is_favorite = ?, group_id = NULL WHERE id = ?"
	if query != want {
		t.Fatalf("SQL 不符\n期望: %s\n实际: %s", want, query)
	}
	if len(args) != 3 {
		t.Fatalf("参数个数应为 3，实际 %d", len(args))
	}
	// WHERE 参数必须排在 SET 参数之后（? 按出现顺序绑定）
	if args[2] != any(uuid.Nil) {
		t.Fatalf("WHERE 参数位置错误: %v", args)
	}
}

func TestMediaAssetColumnListMatchesScanner(t *testing.T) {
	// scanMediaAssets 按固定顺序扫描 15 个字段；列清单长度变化必须同步修改它
	if len(mediaAssetColumnList) != 15 {
		t.Fatalf("列数应与 scanMediaAssets 的扫描字段数一致(15)，实际 %d", len(mediaAssetColumnList))
	}
}

func TestPlaceholders(t *testing.T) {
	if got := placeholders(0); got != "" {
		t.Fatalf("空列表不应生成占位符: %q", got)
	}
	if got := placeholders(1); got != "?" {
		t.Fatalf("单个占位符错误: %q", got)
	}
	if got := placeholders(3); got != "?,?,?" {
		t.Fatalf("多个占位符错误: %q", got)
	}
}

func TestEscapeLike(t *testing.T) {
	if got := escapeLike(`100%_a\b`); got != `100\%\_a\\b` {
		t.Fatalf("LIKE 通配符未正确转义: %q", got)
	}
	if got := escapeLike("image"); got != "image" {
		t.Fatalf("普通文本不应被改动: %q", got)
	}
}

func TestMimeCondition(t *testing.T) {
	cond, value := mimeCondition("mime_type", "image")
	if cond != `mime_type LIKE ? ESCAPE '\'` || value != "image/%" {
		t.Fatalf("大类前缀匹配错误: %q %v", cond, value)
	}
	cond, value = mimeCondition("mime_type", "image/jpeg")
	if cond != "mime_type = ?" || value != "image/jpeg" {
		t.Fatalf("精确匹配错误: %q %v", cond, value)
	}
	// 用户输入中的通配符必须退化为字面量
	_, value = mimeCondition("mime_type", "im_ge")
	if value != `im\_ge/%` {
		t.Fatalf("下划线未转义: %v", value)
	}
}

func TestJoinTagPath(t *testing.T) {
	if got := joinTagPath("", "root"); got != "root" {
		t.Fatalf("根标签路径错误: %q", got)
	}
	if got := joinTagPath("root", "child"); got != "root/child" {
		t.Fatalf("子标签路径错误: %q", got)
	}
}

func TestSameUUIDPtr(t *testing.T) {
	a, b := uuid.New(), uuid.New()
	if !sameUUIDPtr(nil, nil) {
		t.Fatal("两个 nil 应相等")
	}
	if sameUUIDPtr(&a, nil) || sameUUIDPtr(nil, &a) {
		t.Fatal("nil 与非 nil 不应相等")
	}
	if !sameUUIDPtr(&a, &a) {
		t.Fatal("同值应相等")
	}
	if sameUUIDPtr(&a, &b) {
		t.Fatal("不同值不应相等")
	}
}

// ============ 集成测试 ============
//
// 使用临时目录下的单文件 SQLite，不依赖外部数据库。

func setupTempDB(t *testing.T) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "gallery_test.db")
	if err := db.Open(path); err != nil {
		t.Fatalf("打开测试数据库失败: %v", err)
	}
	t.Cleanup(db.Close)
}

func insertTestMedia(t *testing.T, id uuid.UUID, mime, capturedAt string) {
	t.Helper()
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	now := model.Now()
	if _, err := db.W().ExecContext(ctx, `
		INSERT INTO gallery_media_assets
			(id, created_at, updated_at, captured_at, file_path, hash, size_bytes, mime_type, is_deleted, sync_count)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0)`,
		id, now, now, capturedAt, "/media/"+id.String(), []byte(id.String()), 10, mime); err != nil {
		t.Fatalf("插入测试媒体失败: %v", err)
	}
}

// TestTagFullPathCascade 覆盖 full_path 的创建、改名级联、换父级联与删除。
func TestTagFullPathCascade(t *testing.T) {
	setupTempDB(t)

	root, err := CreateTag("root", nil)
	if err != nil {
		t.Fatalf("创建根标签失败: %v", err)
	}
	if root.FullPath != "root" {
		t.Fatalf("根标签 full_path 错误: %q", root.FullPath)
	}
	child, err := CreateTag("child", &root.ID)
	if err != nil {
		t.Fatalf("创建子标签失败: %v", err)
	}
	if child.FullPath != "root/child" {
		t.Fatalf("子标签 full_path 错误: %q", child.FullPath)
	}
	grand, err := CreateTag("grand", &child.ID)
	if err != nil {
		t.Fatalf("创建孙标签失败: %v", err)
	}
	if grand.FullPath != "root/child/grand" {
		t.Fatalf("孙标签 full_path 错误: %q", grand.FullPath)
	}

	if _, err := CreateTag("child", &root.ID); err != ErrTagNameConflict {
		t.Fatalf("同级同名应报冲突，实际: %v", err)
	}
	// parent_id 为 NULL 时唯一索引不生效，必须由 Go 侧拦截
	if _, err := CreateTag("root", nil); err != ErrTagNameConflict {
		t.Fatalf("根级同名应报冲突，实际: %v", err)
	}
	missing := uuid.New()
	if _, err := CreateTag("x", &missing); err != ErrTagParentNotFound {
		t.Fatalf("父标签不存在应报错，实际: %v", err)
	}
	if _, err := CreateTag("   ", nil); err != ErrTagEmptyName {
		t.Fatalf("空名应报错，实际: %v", err)
	}

	// 改名：子孙 full_path 级联重算
	renamed := "root2"
	if _, err := UpdateTag(root.ID, TagPatch{Name: &renamed}); err != nil {
		t.Fatalf("改名失败: %v", err)
	}
	if got, _ := FetchTagByID(grand.ID); got.FullPath != "root2/child/grand" {
		t.Fatalf("改名父级联失败: %q", got.FullPath)
	}

	// 换父：自身与子孙一起级联
	other, err := CreateTag("other", nil)
	if err != nil {
		t.Fatalf("创建 other 失败: %v", err)
	}
	if _, err := UpdateTag(child.ID, TagPatch{ParentID: &other.ID}); err != nil {
		t.Fatalf("换父失败: %v", err)
	}
	if got, _ := FetchTagByID(child.ID); got.FullPath != "other/child" {
		t.Fatalf("换父自身路径错误: %q", got.FullPath)
	}
	if got, _ := FetchTagByID(grand.ID); got.FullPath != "other/child/grand" {
		t.Fatalf("换父级联失败: %q", got.FullPath)
	}

	if _, err := UpdateTag(other.ID, TagPatch{ParentID: &grand.ID}); err != ErrTagCycle {
		t.Fatalf("移动到子孙下应报环，实际: %v", err)
	}
	if _, err := UpdateTag(other.ID, TagPatch{ParentID: &other.ID}); err != ErrTagCycle {
		t.Fatalf("移动到自身应报环，实际: %v", err)
	}
	if _, err := UpdateTag(uuid.New(), TagPatch{Name: &renamed}); err != ErrTagNotFound {
		t.Fatalf("标签不存在应报错，实际: %v", err)
	}

	// 移到根级
	if _, err := UpdateTag(grand.ID, TagPatch{MoveToRoot: true}); err != nil {
		t.Fatalf("移到根级失败: %v", err)
	}
	if got, _ := FetchTagByID(grand.ID); got.FullPath != "grand" {
		t.Fatalf("移根后路径错误: %q", got.FullPath)
	}

	// 收藏标记与 updated_at 一并写入
	favorite := true
	before, _ := FetchTagByID(root.ID)
	if _, err := UpdateTag(root.ID, TagPatch{IsFavorite: &favorite}); err != nil {
		t.Fatalf("设置收藏失败: %v", err)
	}
	after, _ := FetchTagByID(root.ID)
	if !after.IsFavorite {
		t.Fatal("is_favorite 未生效")
	}
	if after.UpdatedAt.Time().Before(before.UpdatedAt.Time()) {
		t.Fatalf("updated_at 未刷新: %v -> %v", before.UpdatedAt, after.UpdatedAt)
	}

	all, err := FetchAllTags()
	if err != nil {
		t.Fatalf("FetchAllTags 失败: %v", err)
	}
	if len(all) != 4 {
		t.Fatalf("标签数应为 4，实际 %d", len(all))
	}
	if all[0].FullPath > all[1].FullPath {
		t.Fatalf("标签未按 full_path 升序: %v", all)
	}

	// 删除 other 时一并回收 child
	children, err := FetchDescendantTagIDs(other.ID)
	if err != nil || len(children) != 1 || children[0] != child.ID {
		t.Fatalf("子孙查询错误: %v %v", children, err)
	}
	deleted, err := DeleteTag(other.ID)
	if err != nil {
		t.Fatalf("删除标签失败: %v", err)
	}
	if len(deleted) != 2 {
		t.Fatalf("应删除 other 与 child，实际: %v", deleted)
	}
	if got, err := FetchTagByID(child.ID); err != nil || got != nil {
		t.Fatalf("子标签应已被级联删除: %v %v", got, err)
	}
	if _, err := DeleteTag(other.ID); err != ErrTagNotFound {
		t.Fatalf("重复删除应报不存在，实际: %v", err)
	}
}

// TestMediaAssetQueries 覆盖媒体查询的筛选、排序、分页与 vlm_tags。
func TestMediaAssetQueries(t *testing.T) {
	setupTempDB(t)

	m1, m2, m3 := uuid.New(), uuid.New(), uuid.New()
	insertTestMedia(t, m1, "image/jpeg", "2024-06-03T10:00:00.000Z")
	insertTestMedia(t, m2, "video/mp4", "2023-12-01T10:00:00.000Z")
	insertTestMedia(t, m3, "image/png", "2024-01-15T10:00:00.000Z")

	assets, err := FetchMediaAssetsByIDs([]uuid.UUID{m1, m2, m3})
	if err != nil || len(assets) != 3 {
		t.Fatalf("按 ID 查询失败: %v %d", err, len(assets))
	}
	if assets[0].ID != m2 || assets[1].ID != m3 {
		t.Fatalf("应按 captured_at 升序: %v", assets)
	}
	empty, err := FetchMediaAssetsByIDs(nil)
	if err != nil || len(empty) != 0 {
		t.Fatalf("空 ID 列表应返回空集: %v", err)
	}
	single, err := FetchMediaAssetByID(m1)
	if err != nil || single == nil || single.ID != m1 {
		t.Fatalf("按 ID 取单个失败: %v %v", single, err)
	}
	if missing, err := FetchMediaAssetByID(uuid.New()); err != nil || missing != nil {
		t.Fatalf("不存在的 ID 应返回 nil, nil: %v %v", missing, err)
	}

	for _, tc := range []struct {
		name string
		p    model.BatchQueryParams
		want int
	}{
		{"按年", model.BatchQueryParams{Year: 2024}, 2},
		{"按年月", model.BatchQueryParams{Year: 2024, Month: 6}, 1},
		{"按年月日", model.BatchQueryParams{Year: 2024, Month: 6, Day: 3}, 1},
		{"跨年同月", model.BatchQueryParams{Year: 2023, Month: 12}, 1},
		{"无匹配年份", model.BatchQueryParams{Year: 2025}, 0},
		{"MIME 大类", model.BatchQueryParams{MimeType: "image"}, 2},
		{"MIME 大类 video", model.BatchQueryParams{MimeType: "video"}, 1},
		{"MIME 精确", model.BatchQueryParams{MimeType: "image/png"}, 1},
		{"MIME 通配符按字面处理", model.BatchQueryParams{MimeType: "im_ge"}, 0},
	} {
		p := tc.p
		p.Limit, p.Offset = 10, 0
		got, err := FetchMediaAssetsWithParams(p)
		if err != nil {
			t.Fatalf("%s 查询失败: %v", tc.name, err)
		}
		if len(got) != tc.want {
			t.Fatalf("%s 期望 %d 条，实际 %d", tc.name, tc.want, len(got))
		}
	}

	// 分页
	page, err := FetchMediaAssetsWithParams(model.BatchQueryParams{Limit: 2, Offset: 1})
	if err != nil || len(page) != 2 || page[0].ID != m3 {
		t.Fatalf("分页结果错误: %v %v", page, err)
	}

	overview, err := FetchGalleryOverview()
	if err != nil {
		t.Fatalf("总览查询失败: %v", err)
	}
	if overview.TotalMedia != 3 || overview.ImageCount != 2 || overview.VideoCount != 1 {
		t.Fatalf("类型统计错误: %+v", overview)
	}
	if overview.TotalSize != 30 || overview.MinYear != 2023 || overview.MaxYear != 2024 {
		t.Fatalf("大小/年份统计错误: %+v", overview)
	}
	if len(overview.YearStats) != 2 || overview.YearStats[0].Year != 2024 || overview.YearStats[0].MediaCount != 2 {
		t.Fatalf("年份分布错误: %+v", overview.YearStats)
	}

	// 标签筛选：含子孙 / 不含子孙 / 未打标 / 指定 ID / 删除状态
	root, _ := CreateTag("r", nil)
	child, _ := CreateTag("c", &root.ID)
	if _, err := ReplaceMediaTags(m1, []uuid.UUID{child.ID}); err != nil {
		t.Fatalf("替换标签失败: %v", err)
	}

	got, links, total, err := FetchMediaAssetsByQuery(model.MediaQueryParams{
		TagIDs: root.ID.String(), IncludeDescendants: true, Limit: 10,
	})
	if err != nil || total != 1 || len(got) != 1 || got[0].ID != m1 || len(links) != 1 {
		t.Fatalf("含子孙筛选错误: %v total=%d got=%v links=%v", err, total, got, links)
	}
	if _, _, total, err = FetchMediaAssetsByQuery(model.MediaQueryParams{
		TagIDs: child.ID.String(), Limit: 10,
	}); err != nil || total != 1 {
		t.Fatalf("直接标签筛选错误: %v total=%d", err, total)
	}
	if _, _, total, err = FetchMediaAssetsByQuery(model.MediaQueryParams{
		TagIDs: root.ID.String(), Limit: 10,
	}); err != nil || total != 0 {
		t.Fatalf("不含子孙时父标签不应命中: %v total=%d", err, total)
	}
	if _, _, total, err = FetchMediaAssetsByQuery(model.MediaQueryParams{Untagged: true, Limit: 10}); err != nil || total != 2 {
		t.Fatalf("未打标筛选错误: %v total=%d", err, total)
	}
	if got, _, total, err = FetchMediaAssetsByQuery(model.MediaQueryParams{
		IDs: m1.String() + "," + m3.String(), Limit: 10,
	}); err != nil || total != 2 || len(got) != 2 {
		t.Fatalf("ID 筛选错误: %v total=%d", err, total)
	}
	if got, _, _, err = FetchMediaAssetsByQuery(model.MediaQueryParams{IncludeDeleted: true, Limit: 10}); err != nil || len(got) != 3 {
		t.Fatalf("包含已删除错误: %v %d", err, len(got))
	}
	if got, _, _, err = FetchMediaAssetsByQuery(model.MediaQueryParams{OnlyDeleted: true, Limit: 10}); err != nil || len(got) != 0 {
		t.Fatalf("仅已删除错误: %v %d", err, len(got))
	}

	// vlm_tags 是 JSON 文本，按元素命中
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	if _, err := db.W().ExecContext(ctx,
		`INSERT INTO ai_media (media_id, vlm_tags, updated_at) VALUES (?, ?, ?)`,
		m3, `["蓝天","城市"]`, model.Now()); err != nil {
		t.Fatalf("插入 ai_media 失败: %v", err)
	}
	if got, _, total, err = FetchMediaAssetsByQuery(model.MediaQueryParams{VLMTags: "蓝天", Limit: 10}); err != nil || total != 1 || got[0].ID != m3 {
		t.Fatalf("vlm_tags 筛选错误: %v total=%d got=%v", err, total, got)
	}
	if got, _, _, err = FetchMediaAssetsByQuery(model.MediaQueryParams{VLMTags: "不存在", Limit: 10}); err != nil || len(got) != 0 {
		t.Fatalf("vlm_tags 空结果错误: %v %d", err, len(got))
	}
}

// TestMediaAssetWrites 覆盖标签关联与媒体标注的写路径。
func TestMediaAssetWrites(t *testing.T) {
	setupTempDB(t)

	m1, m2 := uuid.New(), uuid.New()
	insertTestMedia(t, m1, "image/jpeg", "2024-06-03T10:00:00.000Z")
	insertTestMedia(t, m2, "image/jpeg", "2024-06-04T10:00:00.000Z")

	t1, _ := CreateTag("t1", nil)
	t2, _ := CreateTag("t2", nil)

	if _, err := ReplaceMediaTags(m1, []uuid.UUID{t1.ID, t2.ID, t1.ID}); err != nil {
		t.Fatalf("替换标签失败: %v", err)
	}
	links, _ := FetchMediaTagLinks([]uuid.UUID{m1, m2})
	if len(links) != 2 {
		t.Fatalf("关联数应为 2，实际 %d", len(links))
	}
	if _, err := ReplaceMediaTags(uuid.New(), []uuid.UUID{t1.ID}); err != ErrMediaNotFound {
		t.Fatalf("媒体不存在应报错，实际: %v", err)
	}
	if _, err := ReplaceMediaTags(m1, []uuid.UUID{uuid.New()}); err != ErrTagNotFound {
		t.Fatalf("标签不存在应报错，实际: %v", err)
	}
	if applied, err := ReplaceMediaTags(m2, nil); err != nil || len(applied) != 0 {
		t.Fatalf("空标签集合应可用: %v %v", applied, err)
	}

	// 清空后为两个媒体加 t1
	if n, err := AddRemoveMediaTags([]uuid.UUID{m1, m2}, nil, []uuid.UUID{t1.ID, t2.ID}); err != nil || n != 2 {
		t.Fatalf("清空关联失败: %v n=%d", err, n)
	}
	if n, err := AddRemoveMediaTags([]uuid.UUID{m1, m2}, []uuid.UUID{t1.ID}, nil); err != nil || n != 2 {
		t.Fatalf("批量新增失败: %v n=%d", err, n)
	}
	// 把 t1 换成 t2：删 2 加 2（先删后加，与旧实现一致）
	if n, err := AddRemoveMediaTags([]uuid.UUID{m1, m2}, []uuid.UUID{t2.ID}, []uuid.UUID{t1.ID}); err != nil || n != 4 {
		t.Fatalf("批量增删失败: %v n=%d", err, n)
	}
	links, _ = FetchMediaTagLinks([]uuid.UUID{m1, m2})
	if len(links) != 2 {
		t.Fatalf("批量增删后关联数应为 2，实际 %d: %v", len(links), links)
	}
	for _, link := range links {
		if link.TagID != t2.ID {
			t.Fatalf("应只剩 t2: %v", links)
		}
	}
	if n, err := AddRemoveMediaTags([]uuid.UUID{m1, m2}, nil, []uuid.UUID{t1.ID, t2.ID}); err != nil || n != 2 {
		t.Fatalf("批量删除失败: %v n=%d", err, n)
	}
	if links, _ = FetchMediaTagLinks([]uuid.UUID{m1, m2}); len(links) != 0 {
		t.Fatalf("批量删除后关联数应为 0，实际 %d", len(links))
	}
	if n, err := AddRemoveMediaTags(nil, []uuid.UUID{t1.ID}, nil); err != nil || n != 0 {
		t.Fatalf("空媒体列表应直接返回 0: %v n=%d", err, n)
	}

	// 标注：备注归一化与清空
	message := "  hello  "
	if _, err := PatchMediaAssets(MediaPatch{MediaIDs: []uuid.UUID{m1}, Message: &message}); err != nil {
		t.Fatalf("更新备注失败: %v", err)
	}
	if asset, _ := FetchMediaAssetByID(m1); asset.Message != "hello" {
		t.Fatalf("备注应去除首尾空白: %q", asset.Message)
	}
	blank := ""
	if _, err := PatchMediaAssets(MediaPatch{MediaIDs: []uuid.UUID{m1}, Message: &blank}); err != nil {
		t.Fatalf("清空备注失败: %v", err)
	}
	if asset, _ := FetchMediaAssetByID(m1); asset.Message != "" {
		t.Fatalf("备注应清空: %q", asset.Message)
	}

	// 捆绑：不能捆绑到自身；软删除主文件时成员一并处理
	if _, err := PatchMediaAssets(MediaPatch{MediaIDs: []uuid.UUID{m1}, GroupID: &m1}); err != ErrMediaSelfGroup {
		t.Fatalf("自捆绑应报错，实际: %v", err)
	}
	if _, err := PatchMediaAssets(MediaPatch{MediaIDs: []uuid.UUID{m2}, GroupID: &m1}); err != nil {
		t.Fatalf("捆绑失败: %v", err)
	}
	deleted := true
	updated, err := PatchMediaAssets(MediaPatch{MediaIDs: []uuid.UUID{m1}, IsDeleted: &deleted})
	if err != nil {
		t.Fatalf("软删除失败: %v", err)
	}
	if len(updated) != 2 {
		t.Fatalf("软删除应级联捆绑成员，实际 %d", len(updated))
	}
	for _, asset := range updated {
		if !asset.IsDeleted {
			t.Fatalf("成员未一并软删除: %v", asset.ID)
		}
	}

	// 编辑参数 / 处理游标 / updated_at
	editParams := `{"crop":1}`
	if _, err := PatchMediaAssets(MediaPatch{MediaIDs: []uuid.UUID{m1}, SetEditParams: &editParams, MarkProcessed: true}); err != nil {
		t.Fatalf("设置编辑参数失败: %v", err)
	}
	asset, _ := FetchMediaAssetByID(m1)
	if asset.EditParams == nil || *asset.EditParams != editParams || asset.SyncCount != 1 {
		t.Fatalf("编辑参数/处理游标错误: %v %d", asset.EditParams, asset.SyncCount)
	}
	before := asset.UpdatedAt

	if _, err := PatchMediaAssets(MediaPatch{MediaIDs: []uuid.UUID{m1}, ClearEditParams: true, ClearGroup: true}); err != nil {
		t.Fatalf("清除字段失败: %v", err)
	}
	asset, _ = FetchMediaAssetByID(m1)
	if asset.EditParams != nil || asset.GroupID != nil {
		t.Fatalf("清除未生效: %v %v", asset.EditParams, asset.GroupID)
	}
	if asset.UpdatedAt.Time().Before(before.Time()) {
		t.Fatalf("updated_at 未刷新: %v -> %v", before, asset.UpdatedAt)
	}

	// 无字段变更时直接返回当前行
	if got, err := PatchMediaAssets(MediaPatch{MediaIDs: []uuid.UUID{m1}}); err != nil || len(got) != 1 {
		t.Fatalf("空 patch 应返回当前行: %v %d", err, len(got))
	}
	if _, err := PatchMediaAssets(MediaPatch{MediaIDs: nil}); err != nil {
		t.Fatalf("空 ID 列表应返回空集: %v", err)
	}
	if _, err := PatchMediaAssets(MediaPatch{MediaIDs: []uuid.UUID{uuid.New()}, Message: &message}); err != ErrMediaNotFound {
		t.Fatalf("媒体不存在应报错，实际: %v", err)
	}
}
