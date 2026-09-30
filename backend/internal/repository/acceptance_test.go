// Package repository_test 是数据层的端到端验收：在**数据库副本**上跑遍全部读写
// 场景（AI 产物写入、标签树级联、事务性全量替换、comix 管理字段）。
//
// 需要一份已迁移的 SQLite 数据库；缺省取 backend/data/monarch.db，可用
// MONARCH_DB_SRC 指定。测试先把库复制到临时目录再操作，绝不触碰真实数据。
package repository_test

import (
	"database/sql"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"

	"monarch/internal/config"
	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
	"monarch/internal/repository/comic_repo"
	"monarch/internal/repository/data_repo"
	"monarch/internal/repository/gallery_repo"
	"monarch/internal/service/db"
)

const (
	sourceDB   = "../../data/monarch.db"
	schemaFile = "../../references/db/sqlite.sql"
)

// TestMain 复制一份数据库副本供全部用例共用（每个用例各复制一次 340MB 太浪费）。
func TestMain(m *testing.M) {
	src := os.Getenv("MONARCH_DB_SRC")
	if src == "" {
		src = sourceDB
	}
	src = filepath.FromSlash(src)
	if _, err := os.Stat(src); err != nil {
		fmt.Fprintf(os.Stderr, "跳过数据层验收：未找到源数据库 %s（设置 MONARCH_DB_SRC 或先执行迁移）\n", src)
		os.Exit(0)
	}

	dir, err := os.MkdirTemp("", "monarch-acceptance")
	if err != nil {
		fmt.Fprintf(os.Stderr, "创建临时目录失败: %v\n", err)
		os.Exit(1)
	}
	dst := filepath.Join(dir, "monarch_test.db")
	if err := copyFilePlain(src, dst); err != nil {
		fmt.Fprintf(os.Stderr, "复制数据库失败: %v\n", err)
		os.Exit(1)
	}
	db.Init(config.DbConfig{File: dst, SchemaFile: schemaFile})

	code := m.Run()

	db.Close()
	os.RemoveAll(dir)
	os.Exit(code)
}

func copyFilePlain(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return err
}

// sampleMediaID 取一个未删除的媒体 ID。
func sampleMediaID(t *testing.T) uuid.UUID {
	t.Helper()
	var raw string
	err := db.Read().QueryRow(
		`SELECT id FROM media_assets WHERE is_deleted = 0 ORDER BY captured_at DESC LIMIT 1`).Scan(&raw)
	if err != nil {
		t.Fatalf("取样本媒体失败: %v", err)
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		t.Fatalf("媒体 ID 非法: %v", err)
	}
	return id
}

// ---------- AI 产物写入 ----------

func TestAiWrites(t *testing.T) {
	mediaID := sampleMediaID(t)

	if err := ai_repo.SavePHash(mediaID, -1); err != nil {
		t.Fatalf("写入感知哈希失败: %v", err)
	}
	if err := ai_repo.SaveOCR(mediaID, "验收用 OCR 文本"); err != nil {
		t.Fatalf("写入 OCR 失败: %v", err)
	}
	if err := ai_repo.SaveVLM(mediaID, "验收用描述", []string{"标签A", "标签B", "标签A", ""}); err != nil {
		t.Fatalf("写入 VLM 失败: %v", err)
	}

	detail, err := ai_repo.GetMediaDetail(mediaID)
	if err != nil {
		t.Fatalf("读取媒体 AI 详情失败: %v", err)
	}
	if detail.PHash == nil || *detail.PHash != -1 {
		t.Fatalf("感知哈希不符: %v", detail.PHash)
	}
	if detail.Caption == nil || *detail.Caption != "验收用描述" {
		t.Fatalf("描述不符: %v", detail.Caption)
	}
	if len(detail.VLMTags) != 2 {
		t.Fatalf("AI 标签应去空去重后为 2 条，实际 %v", detail.VLMTags)
	}

	vec := make([]byte, 8)
	for i := range vec {
		vec[i] = byte(i + 1)
	}
	if err := ai_repo.SaveEmbeddings([]ai_repo.EmbeddingWrite{{
		MediaID: mediaID, Kind: "image", Model: "test-model", Dim: 8, Scale: 0.5, Vec: vec,
	}}); err != nil {
		t.Fatalf("写入向量失败: %v", err)
	}
	row, err := ai_repo.GetEmbedding(mediaID, "image", "test-model")
	if err != nil || row == nil {
		t.Fatalf("读取向量失败: %v row=%v", err, row)
	}
	if row.Dim != 8 || len(row.Vec) != 8 || row.Vec[0] != 1 {
		t.Fatalf("向量内容不符: %+v", row)
	}
	if n, err := ai_repo.EmbeddingCount("image", "test-model"); err != nil || n != 1 {
		t.Fatalf("向量计数不符: n=%d err=%v", n, err)
	}

	// 人脸写入（bbox 走 JSON 文本）
	if err := ai_repo.ReplaceFaces(mediaID, []ai_repo.FaceWrite{{
		ID: uuid.New(), MediaID: mediaID, Box: []float32{0.1, 0.2, 0.3, 0.4},
		DetScore: 0.9, Quality: 0.8, Embedding: make([]byte, 2048),
	}}); err != nil {
		t.Fatalf("写入人脸失败: %v", err)
	}
	faces, err := ai_repo.ListFacesByMedia([]uuid.UUID{mediaID})
	if err != nil {
		t.Fatalf("读取人脸失败: %v", err)
	}
	if len(faces[mediaID]) != 1 {
		t.Fatalf("人脸数不符: %v", faces[mediaID])
	}
	box := faces[mediaID][0].Box
	if len(box) != 4 || box[0] < 0.09 || box[0] > 0.11 {
		t.Fatalf("bbox 往返不符: %v", box)
	}

	// 人物分组：新建 → 分配 → 统计 → 合并 → 改名 → 删除
	personID, err := ai_repo.CreatePerson(nil)
	if err != nil {
		t.Fatalf("创建人物失败: %v", err)
	}
	otherID, err := ai_repo.CreatePerson(nil)
	if err != nil {
		t.Fatalf("创建人物失败: %v", err)
	}
	faceID := faces[mediaID][0].ID
	if err := ai_repo.AssignFaces([]uuid.UUID{faceID}, &personID); err != nil {
		t.Fatalf("分配人脸失败: %v", err)
	}
	if err := ai_repo.RefreshPersonStats([]uuid.UUID{personID}); err != nil {
		t.Fatalf("重算人物统计失败: %v", err)
	}
	persons, err := ai_repo.ListPersons()
	if err != nil {
		t.Fatalf("读取人物失败: %v", err)
	}
	var found *model.AiPerson
	for i := range persons {
		if persons[i].ID == personID {
			found = &persons[i]
		}
	}
	if found == nil || found.FaceCount != 1 || found.CoverFaceID == nil {
		t.Fatalf("人物统计不符: %+v", found)
	}
	if _, err := ai_repo.MergePersons([]uuid.UUID{otherID}, personID); err != nil {
		t.Fatalf("合并人物失败: %v", err)
	}
	name := "验收人物"
	if err := ai_repo.RenamePerson(personID, &name); err != nil {
		t.Fatalf("重命名人物失败: %v", err)
	}
	if err := ai_repo.DeletePerson(personID); err != nil {
		t.Fatalf("删除人物失败: %v", err)
	}
	if err := ai_repo.DeletePerson(personID); err != ai_repo.ErrPersonMissing {
		t.Fatalf("重复删除应返回 ErrPersonMissing，实际 %v", err)
	}
	if err := ai_repo.ResetAllFaceAssignments(); err != nil {
		t.Fatalf("重置人脸归属失败: %v", err)
	}
	if err := ai_repo.RefreshAllPersonStats(); err != nil {
		t.Fatalf("全量重算人物统计失败: %v", err)
	}
	if _, err := ai_repo.DropEmptyPersons(); err != nil {
		t.Fatalf("清理空人物分组失败: %v", err)
	}

	// 去重人工判定
	if n, err := ai_repo.IgnoreDuplicates([]uuid.UUID{mediaID}); err != nil || n != 1 {
		t.Fatalf("标记非重复失败: n=%d err=%v", n, err)
	}
	if n, err := ai_repo.IgnoreDuplicates([]uuid.UUID{mediaID}); err != nil || n != 0 {
		t.Fatalf("重复标记应幂等: n=%d err=%v", n, err)
	}
	if ignores, err := ai_repo.LoadDuplicateIgnores(); err != nil || len(ignores) != 1 {
		t.Fatalf("读取忽略集合失败: n=%d err=%v", len(ignores), err)
	}
	if n, err := ai_repo.UnignoreDuplicates([]uuid.UUID{mediaID}); err != nil || n != 1 {
		t.Fatalf("取消标记失败: n=%d err=%v", n, err)
	}

	// 运行时设置
	if err := ai_repo.SetAutoCapabilities([]string{model.CapPHash, model.CapOCR}); err != nil {
		t.Fatalf("保存自动能力失败: %v", err)
	}
	if got := ai_repo.AutoCapabilities(nil); len(got) != 2 || got[0] != model.CapPHash {
		t.Fatalf("自动能力读取不符: %v", got)
	}
	if err := ai_repo.SetVLMModel("test-model"); err != nil {
		t.Fatalf("保存 VLM 模型失败: %v", err)
	}
	if got := ai_repo.VLMModel(); got != "test-model" {
		t.Fatalf("VLM 模型读取不符: %q", got)
	}
	if err := ai_repo.SetVLMModel(""); err != nil {
		t.Fatalf("清除 VLM 模型失败: %v", err)
	}
}

// ---------- AI 任务队列 ----------

func TestAiJobQueue(t *testing.T) {
	var mediaIDs []uuid.UUID
	rows, err := db.Read().Query(
		`SELECT id FROM media_assets WHERE is_deleted = 0 ORDER BY captured_at DESC LIMIT 300`)
	if err != nil {
		t.Fatalf("取样本媒体失败: %v", err)
	}
	for rows.Next() {
		var raw string
		if err := rows.Scan(&raw); err != nil {
			rows.Close()
			t.Fatalf("扫描媒体失败: %v", err)
		}
		id, _ := uuid.Parse(raw)
		mediaIDs = append(mediaIDs, id)
	}
	rows.Close()
	if len(mediaIDs) == 0 {
		t.Skip("跳过：库中没有媒体")
	}

	// 入队（幂等）→ 认领 → 完成/失败/退回/重试
	if n, err := ai_repo.Enqueue(model.CapVLM, mediaIDs); err != nil || n != int64(len(mediaIDs)) {
		t.Fatalf("入队失败: n=%d err=%v", n, err)
	}
	if n, err := ai_repo.Enqueue(model.CapVLM, mediaIDs); err != nil || n != 0 {
		t.Fatalf("重复入队应幂等: n=%d err=%v", n, err)
	}
	pending, err := ai_repo.PendingCount(model.CapVLM)
	if err != nil || pending < len(mediaIDs) {
		t.Fatalf("待处理计数不符: n=%d err=%v", pending, err)
	}

	claimed, err := ai_repo.Claim(model.CapVLM, 16)
	if err != nil {
		t.Fatalf("认领任务失败: %v", err)
	}
	if len(claimed) != 16 {
		t.Fatalf("应认领 16 条，实际 %d", len(claimed))
	}
	if err := ai_repo.FinishDone([]int64{claimed[0].JobID}); err != nil {
		t.Fatalf("标记完成失败: %v", err)
	}
	if err := ai_repo.FinishFailed([]int64{claimed[1].JobID}, "验收失败原因", 3); err != nil {
		t.Fatalf("标记失败失败: %v", err)
	}
	if err := ai_repo.ReleaseRunning([]int64{claimed[2].JobID}); err != nil {
		t.Fatalf("退回任务失败: %v", err)
	}
	if _, err := ai_repo.RecoverStaleRunning(0, 3); err != nil {
		t.Fatalf("回收孤儿任务失败: %v", err)
	}
	if n, err := ai_repo.RetryFailed(model.CapVLM, nil); err != nil || n < 1 {
		t.Fatalf("重试失败任务失败: n=%d err=%v", n, err)
	}

	jobs, total, err := ai_repo.ListJobs(model.CapVLM, "", 5, 0)
	if err != nil || len(jobs) != 5 || total < len(mediaIDs) {
		t.Fatalf("任务列表不符: n=%d total=%d err=%v", len(jobs), total, err)
	}
	if jobs[0].CreatedAt.Time().IsZero() {
		t.Fatalf("任务时间字段未解析: %+v", jobs[0])
	}

	stats, err := ai_repo.Stats()
	if err != nil || len(stats) != len(model.AllCapabilities) {
		t.Fatalf("队列统计不符: n=%d err=%v", len(stats), err)
	}
}

// ---------- AI 检索 ----------

func TestAiSearch(t *testing.T) {
	mediaID := sampleMediaID(t)
	if err := ai_repo.SaveOCR(mediaID, "独一无二的验收检索词"); err != nil {
		t.Fatalf("写入 OCR 失败: %v", err)
	}
	if err := ai_repo.SaveVLM(mediaID, "", []string{"验收专属标签"}); err != nil {
		t.Fatalf("写入 VLM 失败: %v", err)
	}

	ids, total, err := ai_repo.SearchMediaIDs(ai_repo.SearchFilters{
		Keyword: "独一无二的验收检索词", Limit: 10,
	})
	if err != nil {
		t.Fatalf("关键词检索失败: %v", err)
	}
	if total != 1 || len(ids) != 1 || ids[0] != mediaID {
		t.Fatalf("关键词检索结果不符: total=%d ids=%v", total, ids)
	}

	if _, total, err := ai_repo.SearchMediaIDs(ai_repo.SearchFilters{
		VLMTags: []string{"验收专属标签"}, Limit: 10,
	}); err != nil || total != 1 {
		t.Fatalf("AI 标签筛选不符: total=%d err=%v", total, err)
	}

	tags, err := ai_repo.ListVLMTags(100)
	if err != nil {
		t.Fatalf("AI 标签聚合失败: %v", err)
	}
	found := false
	for _, tag := range tags {
		if tag.Tag == "验收专属标签" && tag.Count == 1 {
			found = true
		}
	}
	if !found {
		t.Fatalf("AI 标签聚合缺少验收标签: %v", tags)
	}

	if _, err := ai_repo.CountMediaMissingAll(); err != nil {
		t.Fatalf("待处理统计失败: %v", err)
	}
	if !ai_repo.SchemaReady(nil) {
		t.Fatal("SchemaReady 应为 true")
	}
}

// ---------- 标签树与媒体标注 ----------

func TestGalleryTagTree(t *testing.T) {
	root, err := gallery_repo.CreateTag("验收根", nil)
	if err != nil {
		t.Fatalf("创建根标签失败: %v", err)
	}
	if root.FullPath != "验收根" {
		t.Fatalf("根标签路径不符: %q", root.FullPath)
	}
	child, err := gallery_repo.CreateTag("验收子", &root.ID)
	if err != nil {
		t.Fatalf("创建子标签失败: %v", err)
	}
	if child.FullPath != "验收根/验收子" {
		t.Fatalf("子标签路径不符: %q", child.FullPath)
	}
	if _, err := gallery_repo.CreateTag("验收子", &root.ID); err != gallery_repo.ErrTagNameConflict {
		t.Fatalf("同级同名应冲突，实际 %v", err)
	}
	missing := uuid.New()
	if _, err := gallery_repo.CreateTag("x", &missing); err != gallery_repo.ErrTagParentNotFound {
		t.Fatalf("父标签不存在应报错，实际 %v", err)
	}

	// 改名 → 子路径级联
	newName := "验收根改"
	if _, err := gallery_repo.UpdateTag(root.ID, gallery_repo.TagPatch{Name: &newName}); err != nil {
		t.Fatalf("改名失败: %v", err)
	}
	got, err := gallery_repo.FetchTagByID(child.ID)
	if err != nil || got.FullPath != "验收根改/验收子" {
		t.Fatalf("改名后子路径未级联: %+v err=%v", got, err)
	}

	// 环检测：把父挂到子下
	if _, err := gallery_repo.UpdateTag(root.ID, gallery_repo.TagPatch{ParentID: &child.ID}); err != gallery_repo.ErrTagCycle {
		t.Fatalf("环检测失败，实际 %v", err)
	}

	// 移动到根级
	if _, err := gallery_repo.UpdateTag(child.ID, gallery_repo.TagPatch{MoveToRoot: true}); err != nil {
		t.Fatalf("移动到根级失败: %v", err)
	}
	got, _ = gallery_repo.FetchTagByID(child.ID)
	if got.FullPath != "验收子" {
		t.Fatalf("移动后路径不符: %q", got.FullPath)
	}

	// 子孙查询与展开
	grand, err := gallery_repo.CreateTag("验收孙", &root.ID)
	if err != nil {
		t.Fatalf("创建孙标签失败: %v", err)
	}
	descendants, err := gallery_repo.FetchDescendantTagIDs(root.ID)
	if err != nil || len(descendants) != 1 || descendants[0] != grand.ID {
		t.Fatalf("子孙查询不符: %v err=%v", descendants, err)
	}
	expanded, err := gallery_repo.ExpandTagIDs([]uuid.UUID{root.ID})
	if err != nil || len(expanded) != 2 {
		t.Fatalf("标签展开不符: %v err=%v", expanded, err)
	}

	// 媒体打标签 + 含子孙筛选
	mediaID := sampleMediaID(t)
	if _, err := gallery_repo.ReplaceMediaTags(mediaID, []uuid.UUID{grand.ID}); err != nil {
		t.Fatalf("全量替换标签失败: %v", err)
	}
	_, _, total, err := gallery_repo.FetchMediaAssetsByQuery(model.MediaQueryParams{
		TagIDs: root.ID.String(), IncludeDescendants: true, Limit: 10,
	})
	if err != nil || total != 1 {
		t.Fatalf("含子孙标签筛选不符: total=%d err=%v", total, err)
	}
	// 移除 grand、加上 child：受影响行数 = 1 删 + 1 增
	if affected, err := gallery_repo.AddRemoveMediaTags(
		[]uuid.UUID{mediaID}, []uuid.UUID{child.ID}, []uuid.UUID{grand.ID}); err != nil || affected != 2 {
		t.Fatalf("批量增删标签不符: affected=%d err=%v", affected, err)
	}
	links, err := gallery_repo.FetchMediaTagLinks([]uuid.UUID{mediaID})
	if err != nil || len(links) != 1 || links[0].TagID != child.ID {
		t.Fatalf("批量增删后的标签集合不符: %v err=%v", links, err)
	}

	// 删除父标签应级联删除孙标签
	deleted, err := gallery_repo.DeleteTag(root.ID)
	if err != nil || len(deleted) != 2 {
		t.Fatalf("级联删除标签不符: %v err=%v", deleted, err)
	}
	if _, err := gallery_repo.DeleteTag(root.ID); err != gallery_repo.ErrTagNotFound {
		t.Fatalf("重复删除应为 ErrTagNotFound，实际 %v", err)
	}
	if _, err := gallery_repo.DeleteTag(child.ID); err != nil {
		t.Fatalf("清理根级子标签失败: %v", err)
	}
}

func TestGalleryMediaPatch(t *testing.T) {
	mediaID := sampleMediaID(t)

	message := "验收备注"
	patched, err := gallery_repo.PatchMediaAssets(gallery_repo.MediaPatch{
		MediaIDs: []uuid.UUID{mediaID}, Message: &message, MarkProcessed: true,
	})
	if err != nil || len(patched) != 1 {
		t.Fatalf("更新媒体标注失败: %v", err)
	}
	if patched[0].Message != message {
		t.Fatalf("备注未写入: %q", patched[0].Message)
	}
	if patched[0].SyncCount < 1 {
		t.Fatalf("sync_count 未自增: %d", patched[0].SyncCount)
	}

	edit := `{"type":"image","rotation":90}`
	if _, err := gallery_repo.PatchMediaAssets(gallery_repo.MediaPatch{
		MediaIDs: []uuid.UUID{mediaID}, SetEditParams: &edit,
	}); err != nil {
		t.Fatalf("写入编辑参数失败: %v", err)
	}
	got, _ := gallery_repo.FetchMediaAssetByID(mediaID)
	if got.EditParams == nil || *got.EditParams != edit {
		t.Fatalf("编辑参数未写入: %v", got.EditParams)
	}
	if _, err := gallery_repo.PatchMediaAssets(gallery_repo.MediaPatch{
		MediaIDs: []uuid.UUID{mediaID}, ClearEditParams: true,
	}); err != nil {
		t.Fatalf("清除编辑参数失败: %v", err)
	}

	// 自捆绑应被拒绝
	if _, err := gallery_repo.PatchMediaAssets(gallery_repo.MediaPatch{
		MediaIDs: []uuid.UUID{mediaID}, GroupID: &mediaID,
	}); err != gallery_repo.ErrMediaSelfGroup {
		t.Fatalf("自捆绑应报错，实际 %v", err)
	}

	// 软删除 + 恢复（此处只改状态，不动磁盘）
	yes := true
	if _, err := gallery_repo.PatchMediaAssets(gallery_repo.MediaPatch{
		MediaIDs: []uuid.UUID{mediaID}, IsDeleted: &yes,
	}); err != nil {
		t.Fatalf("软删除失败: %v", err)
	}
	_, _, onlyDeleted, err := gallery_repo.FetchMediaAssetsByQuery(model.MediaQueryParams{
		OnlyDeleted: true, Limit: 1000,
	})
	if err != nil || onlyDeleted < 1 {
		t.Fatalf("仅已删除筛选不符: %d err=%v", onlyDeleted, err)
	}
	no := false
	if _, err := gallery_repo.PatchMediaAssets(gallery_repo.MediaPatch{
		MediaIDs: []uuid.UUID{mediaID}, IsDeleted: &no,
	}); err != nil {
		t.Fatalf("恢复失败: %v", err)
	}

	// 不存在的媒体
	if _, err := gallery_repo.PatchMediaAssets(gallery_repo.MediaPatch{
		MediaIDs: []uuid.UUID{uuid.New()}, Message: &message,
	}); err != gallery_repo.ErrMediaNotFound {
		t.Fatalf("不存在媒体应报错，实际 %v", err)
	}

	if _, err := gallery_repo.FetchGalleryOverview(); err != nil {
		t.Fatalf("总览统计失败: %v", err)
	}
	if _, err := gallery_repo.FetchMediaAssetsWithParams(model.BatchQueryParams{Limit: 5}); err != nil {
		t.Fatalf("batch 查询失败: %v", err)
	}
	if _, err := gallery_repo.FetchAllTags(); err != nil {
		t.Fatalf("标签列表失败: %v", err)
	}
}

// ---------- 用户数据全量替换 ----------

func TestUserDataReplace(t *testing.T) {
	articles, err := data_repo.FetchAllEssayArticles()
	if err != nil {
		t.Fatalf("读取随笔失败: %v", err)
	}
	labels, err := data_repo.FetchAllEssayLabels()
	if err != nil {
		t.Fatalf("读取标签失败: %v", err)
	}
	summaries, err := data_repo.FetchAllEssayYearSummaries()
	if err != nil {
		t.Fatalf("读取年度汇总失败: %v", err)
	}
	articleIDs := make([]uuid.UUID, 0, len(articles))
	for _, a := range articles {
		articleIDs = append(articleIDs, a.ID)
	}
	labelIDs := make([]uuid.UUID, 0, len(labels))
	for _, l := range labels {
		labelIDs = append(labelIDs, l.ID)
	}
	years := make([]int, 0, len(summaries))
	for _, s := range summaries {
		years = append(years, int(s.Year))
	}

	// 原样回写一遍：既不改变行数，也不应丢失 JSON 字段
	if err := data_repo.ReplaceEssayData(data_repo.EssayBackupData{
		Articles: articles, Labels: labels, YearSummaries: summaries,
		ArticleIDs: articleIDs, LabelIDs: labelIDs, YearIDs: years,
	}); err != nil {
		t.Fatalf("全量替换随笔失败: %v", err)
	}
	again, err := data_repo.FetchAllEssayArticles()
	if err != nil || len(again) != len(articles) {
		t.Fatalf("回写后行数不符: %d → %d err=%v", len(articles), len(again), err)
	}
	for i := range again {
		if len(again[i].Imgs) != len(articles[i].Imgs) || len(again[i].Labels) != len(articles[i].Labels) {
			t.Fatalf("第 %d 条随笔的 JSON 数组字段丢失", i)
		}
		if string(again[i].Messages) != string(articles[i].Messages) {
			t.Fatalf("第 %d 条随笔的 messages 不一致", i)
		}
	}

	styles, err := data_repo.FetchAllBookletStyles()
	if err != nil {
		t.Fatalf("读取打卡样式失败: %v", err)
	}
	records, err := data_repo.FetchAllBookletRecords()
	if err != nil {
		t.Fatalf("读取打卡记录失败: %v", err)
	}
	styleIDs := make([]uuid.UUID, 0, len(styles))
	for _, s := range styles {
		styleIDs = append(styleIDs, s.ID)
	}
	recordIDs := make([]uuid.UUID, 0, len(records))
	for _, r := range records {
		recordIDs = append(recordIDs, r.ID)
	}
	if err := data_repo.ReplaceBookletData(data_repo.BookletBackupData{
		Styles: styles, Records: records, StyleIDs: styleIDs, RecordIDs: recordIDs,
	}); err != nil {
		t.Fatalf("全量替换打卡数据失败: %v", err)
	}
	stylesAgain, _ := data_repo.FetchAllBookletStyles()
	recordsAgain, _ := data_repo.FetchAllBookletRecords()
	if len(stylesAgain) != len(styles) || len(recordsAgain) != len(records) {
		t.Fatalf("打卡数据回写后行数不符: %d/%d → %d/%d",
			len(styles), len(records), len(stylesAgain), len(recordsAgain))
	}
	for i := range recordsAgain {
		if recordsAgain[i].Date.Time().Format("2006-01-02") != records[i].Date.Time().Format("2006-01-02") {
			t.Fatalf("打卡记录 date 往返不一致: %v → %v", records[i].Date, recordsAgain[i].Date)
		}
	}

	if refs, err := data_repo.CollectEssayReferencedImages(); err != nil {
		t.Fatalf("收集随笔图片引用失败: %v", err)
	} else if len(refs) == 0 {
		t.Fatal("随笔图片引用不应为空")
	}
	if refs, err := data_repo.CollectBookletReferencedImages(); err != nil {
		t.Fatalf("收集打卡图片引用失败: %v", err)
	} else if len(refs) == 0 {
		t.Fatal("打卡图片引用不应为空")
	}
}

// ---------- comix 漫画读取与管理字段 ----------

func TestComicRepo(t *testing.T) {
	meta, err := comic_repo.GetComicMetaData()
	if err != nil || meta.BookCount == 0 || meta.TotalImageCount == 0 {
		t.Fatalf("漫画总元数据不符: %+v err=%v", meta, err)
	}
	if meta.UpdatedAt.IsZero() {
		t.Fatal("漫画元数据时间未设置")
	}

	infos, err := comic_repo.GetAllComicInfos()
	if err != nil || len(infos) != meta.BookCount {
		t.Fatalf("漫画列表不符: %d/%d err=%v", len(infos), meta.BookCount, err)
	}
	var withChapters *model.ComicInfo
	for i := range infos {
		if infos[i].ChapterCount > 0 {
			withChapters = &infos[i]
			break
		}
	}
	if withChapters == nil {
		t.Skip("跳过：库中没有含章节的漫画")
	}

	chapters, err := comic_repo.GetChaptersWithComicId(withChapters.ID)
	if err != nil || len(chapters) == 0 {
		t.Fatalf("章节列表失败: %v", err)
	}
	first := chapters[0]
	if len(first.DirName) < 5 || first.DirName[3] != '_' {
		t.Fatalf("dir_name 投影不符: %q", first.DirName)
	}
	if first.ID == "" || first.ComicID != withChapters.ID {
		t.Fatalf("章节 ID 投影不符: %+v", first)
	}

	images, err := comic_repo.GetImagesWithChapterId(first.ID)
	if err != nil {
		t.Fatalf("图片清单失败: %v", err)
	}
	if len(images) > 0 && (images[0].Path == "" || images[0].Width <= 0) {
		t.Fatalf("图片投影不符: %+v", images[0])
	}

	chapterMap, imageMap, err := comic_repo.GetComicAllChaptersAndImages(withChapters.ID)
	if err != nil || len(chapterMap) != len(chapters) {
		t.Fatalf("整本漫画查询不符: %d/%d err=%v", len(chapterMap), len(chapters), err)
	}
	for id, list := range imageMap {
		if ch, ok := chapterMap[id]; ok && ch.ImageCount != len(list) {
			t.Fatalf("章节 %s 图片数不一致: %d/%d", id, ch.ImageCount, len(list))
		}
	}

	// 管理字段写入（在副本上操作）
	target := !withChapters.IsPublic
	if err := comic_repo.UpdateComicMeta(withChapters.ID, model.UpdateComicRequest{IsPublic: &target}); err != nil {
		t.Fatalf("更新漫画元数据失败: %v", err)
	}
	after, err := comic_repo.GetAllComicInfos()
	if err != nil {
		t.Fatalf("重新读取漫画列表失败: %v", err)
	}
	for _, info := range after {
		if info.ID == withChapters.ID && info.IsPublic != target {
			t.Fatalf("is_public 未生效: %+v", info)
		}
	}

	resp, err := comic_repo.SyncReadedStatus([]string{withChapters.ID})
	if err != nil {
		t.Fatalf("同步已读失败: %v", err)
	}
	if resp.NewChapters[withChapters.ID] != len(chapters) {
		t.Fatalf("已读同步的章节计数不符: %d/%d", resp.NewChapters[withChapters.ID], len(chapters))
	}
	if _, err := comic_repo.SyncReadedStatus([]string{"not-a-number"}); err == nil {
		t.Fatal("非法漫画 ID 应报错")
	}
}

// ---------- 时间列往返 ----------

func TestTimestampRoundTrip(t *testing.T) {
	var raw string
	if err := db.Read().QueryRow(`SELECT captured_at FROM media_assets LIMIT 1`).Scan(&raw); err != nil {
		t.Fatalf("读取时间列失败: %v", err)
	}
	if len(raw) != len("2006-01-02 15:04:05.000") {
		t.Fatalf("时间列格式不符（应为定宽毫秒文本）: %q", raw)
	}

	mediaID := sampleMediaID(t)
	got, err := gallery_repo.FetchMediaAssetByID(mediaID)
	if err != nil || got == nil {
		t.Fatalf("读取媒体失败: %v", err)
	}
	if got.CapturedAt.Time().IsZero() || got.CreatedAt.Time().IsZero() {
		t.Fatalf("时间字段未解析: %+v", got)
	}
	if got.CapturedAt.Time().Location() != time.Local {
		t.Fatalf("时间应按本机时区解析: %v", got.CapturedAt.Time().Location())
	}
}

// ---------- 事务回滚 ----------

func TestWriteRollback(t *testing.T) {
	mediaID := sampleMediaID(t)
	message := "回滚用例"

	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx,
			`UPDATE media_assets SET message = ? WHERE id = ?`, message, mediaID); err != nil {
			return err
		}
		return io.ErrUnexpectedEOF // 触发回滚
	})
	if err == nil {
		t.Fatal("事务内报错应返回错误")
	}
	got, err := gallery_repo.FetchMediaAssetByID(mediaID)
	if err != nil {
		t.Fatalf("读取媒体失败: %v", err)
	}
	if got.Message == message {
		t.Fatal("事务失败后写入未回滚")
	}
}
