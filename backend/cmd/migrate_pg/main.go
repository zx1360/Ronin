// migrate_pg 把生产 PostgreSQL 数据一次性搬到 SQLite 单文件。
//
// 本目录是独立 Go module（主服务因此不依赖任何 PostgreSQL 驱动），
// 因此必须在本目录内运行：
//
//	cd backend/cmd/migrate_pg
//	$env:PGPASSWORD='...'; go run . -verify-sample 200
//
// 安全约定：
//   - 只读源库：所有查询都在 `BEGIN READ ONLY` 事务内进行，绝不写入或修改 PostgreSQL。
//   - 原库原样保留：本工具不删除、不清理源库；回滚 = 丢弃目标 SQLite 文件。
//   - 目标库必须"干净"：文件不存在或为空库时直接建；已有数据时必须显式 -force（会先删除目标文件）。
//   - 分段提交：普通表每 -segment 行一个事务，中断后可删除目标文件重跑。
//
// comix_* 表由 gizmos/comix 的 Python 侧建表与维护，本工具不搬运；
// 迁移完成后需再执行 `python -m comix.cli init` 与 gizmos/comix/scripts/import_from_pg.py。
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"

	"monarch/internal/model"
	"monarch/internal/service/db"
)

// ---------------------------------------------------------------------------
// 列与表定义
// ---------------------------------------------------------------------------

type colKind int

const (
	kText      colKind = iota // text / varchar
	kUUID                     // uuid → TEXT
	kTime                     // timestamptz → 'YYYY-MM-DDTHH:MM:SS.mmmZ'
	kDate                     // date → 'YYYY-MM-DD'
	kBool                     // boolean → 0/1
	kInt                      // smallint / int / bigint
	kReal                     // real / double precision
	kBytes                    // bytea → BLOB
	kJSON                     // jsonb → JSON 文本（pgx 会解成 map/slice，必须重新序列化）
	kTextArray                // text[] → JSON 数组
	kUUIDArray                // uuid[] → JSON 数组
	kRealArray                // real[] → JSON 数组
)

type col struct {
	name string
	kind colKind
}

type tableSpec struct {
	pg     string // 源：schema.table
	sqlite string // 目标表
	cols   []col
	keys   []col // 抽样校验用的主键列
	// group 非空时，同组表在同一个事务内写入并推迟外键检查。
	// 用于自引用（tags）与环形引用（persons ↔ faces）这类无法靠排序满足的表。
	group string
}

var tables = []tableSpec{
	{
		pg: "gallery.media_assets", sqlite: "gallery_media_assets",
		keys: []col{{"id", kUUID}},
		cols: []col{
			{"id", kUUID}, {"created_at", kTime}, {"updated_at", kTime}, {"captured_at", kTime},
			{"file_path", kText}, {"thumb_path", kText}, {"preview_path", kText},
			{"hash", kBytes}, {"size_bytes", kInt}, {"mime_type", kText},
			{"is_deleted", kBool}, {"sync_count", kInt}, {"group_id", kUUID},
			{"message", kText}, {"edit_params", kJSON},
		},
	},
	{
		pg: "gallery.tags", sqlite: "gallery_tags", group: "self_ref",
		keys: []col{{"id", kUUID}},
		cols: []col{
			{"id", kUUID}, {"created_at", kTime}, {"updated_at", kTime},
			{"name", kText}, {"parent_id", kUUID}, {"full_path", kText}, {"is_favorite", kBool},
		},
	},
	{
		pg: "gallery.media_tag_links", sqlite: "gallery_media_tag_links",
		keys: []col{{"tag_id", kUUID}, {"media_id", kUUID}},
		cols: []col{{"media_id", kUUID}, {"tag_id", kUUID}},
	},
	{
		pg: "user_data.essay_articles", sqlite: "user_data_essay_articles",
		keys: []col{{"id", kUUID}},
		cols: []col{
			{"id", kUUID}, {"date", kTime}, {"word_count", kInt}, {"content", kText},
			{"imgs", kTextArray}, {"labels", kUUIDArray}, {"messages", kJSON}, {"mood", kText},
			{"created_at", kTime}, {"updated_at", kTime},
		},
	},
	{
		pg: "user_data.essay_labels", sqlite: "user_data_essay_labels",
		keys: []col{{"id", kUUID}},
		cols: []col{
			{"id", kUUID}, {"name", kText}, {"essay_count", kInt},
			{"created_at", kTime}, {"updated_at", kTime},
		},
	},
	{
		pg: "user_data.essay_year_summaries", sqlite: "user_data_essay_year_summaries",
		keys: []col{{"year", kInt}},
		cols: []col{
			{"year", kInt}, {"essay_count", kInt}, {"word_count", kInt},
			{"month_summaries", kJSON}, {"updated_at", kTime},
		},
	},
	{
		pg: "user_data.booklet_styles", sqlite: "user_data_booklet_styles",
		keys: []col{{"id", kUUID}},
		cols: []col{
			{"id", kUUID}, {"start_date", kTime}, {"valid_check_in", kInt}, {"fully_done", kInt},
			{"longest_streak", kInt}, {"longest_fully_streak", kInt}, {"tasks", kJSON},
			{"created_at", kTime}, {"updated_at", kTime},
		},
	},
	{
		pg: "user_data.booklet_records", sqlite: "user_data_booklet_records",
		keys: []col{{"id", kUUID}},
		cols: []col{
			{"id", kUUID}, {"style_id", kUUID}, {"date", kDate}, {"message", kText},
			{"task_completion", kJSON}, {"mood", kText},
			{"created_at", kTime}, {"updated_at", kTime},
		},
	},
	{
		pg: "ai.media_ai", sqlite: "ai_media",
		keys: []col{{"media_id", kUUID}},
		cols: []col{
			{"media_id", kUUID}, {"phash", kInt}, {"ocr_text", kText},
			{"caption", kText}, {"vlm_tags", kTextArray}, {"updated_at", kTime},
		},
	},
	{
		pg: "ai.embeddings", sqlite: "ai_embeddings",
		keys: []col{{"media_id", kUUID}, {"kind", kText}, {"model", kText}},
		cols: []col{
			{"media_id", kUUID}, {"kind", kText}, {"model", kText},
			{"dim", kInt}, {"scale", kReal}, {"vec", kBytes}, {"updated_at", kTime},
		},
	},
	{
		// persons.cover_face_id ↔ faces.person_id 是环形引用，必须同事务 + 推迟检查。
		pg: "ai.faces", sqlite: "ai_faces", group: "face_person",
		keys: []col{{"id", kUUID}},
		cols: []col{
			{"id", kUUID}, {"media_id", kUUID}, {"person_id", kUUID},
			{"bbox", kRealArray}, {"det_score", kReal}, {"quality", kReal},
			{"embedding", kBytes}, {"created_at", kTime},
		},
	},
	{
		pg: "ai.persons", sqlite: "ai_persons", group: "face_person",
		keys: []col{{"id", kUUID}},
		cols: []col{
			{"id", kUUID}, {"name", kText}, {"cover_face_id", kUUID}, {"face_count", kInt},
			{"created_at", kTime}, {"updated_at", kTime},
		},
	},
	{
		pg: "ai.jobs", sqlite: "ai_jobs",
		keys: []col{{"id", kInt}},
		cols: []col{
			{"id", kInt}, {"capability", kText}, {"media_id", kUUID}, {"status", kText},
			{"priority", kInt}, {"attempts", kInt}, {"last_error", kText},
			{"started_at", kTime}, {"finished_at", kTime},
			{"created_at", kTime}, {"updated_at", kTime},
		},
	},
	{
		pg: "ai.duplicate_ignores", sqlite: "ai_duplicate_ignores",
		keys: []col{{"media_id", kUUID}},
		cols: []col{{"media_id", kUUID}, {"created_at", kTime}},
	},
}

type options struct {
	pgHost     string
	pgPort     string
	pgUser     string
	pgPassword string
	pgDB       string
	sqlitePath string
	segment    int
	sample     int
	force      bool
}

func main() {
	// 一次性迁移需要读取 .env 里的"旧"配置（GALLERY_DIR / AI_* 等）来播种运行时设置。
	_ = godotenv.Load()

	opt := parseFlags()
	if err := run(opt); err != nil {
		log.Fatalf("迁移失败: %v", err)
	}
}

func parseFlags() options {
	var opt options
	flag.StringVar(&opt.pgHost, "pg-host", envOr("PGHOST", "localhost"), "PostgreSQL 主机")
	flag.StringVar(&opt.pgPort, "pg-port", envOr("PGPORT", "5432"), "PostgreSQL 端口")
	flag.StringVar(&opt.pgUser, "pg-user", envOr("PGUSER", "postgres"), "PostgreSQL 用户")
	flag.StringVar(&opt.pgPassword, "pg-password", envOr("PGPASSWORD", ""), "PostgreSQL 密码")
	flag.StringVar(&opt.pgDB, "pg-db", envOr("PGDATABASE", "monarch"), "PostgreSQL 数据库")
	flag.StringVar(&opt.sqlitePath, "sqlite", filepath.Join("data", "monarch.db"), "目标 SQLite 文件")
	flag.IntVar(&opt.segment, "segment", 2000, "普通表每段行数（一个事务）")
	flag.IntVar(&opt.sample, "verify-sample", 200, "每表抽样校验行数（0 = 只比对行数）")
	flag.BoolVar(&opt.force, "force", false, "目标文件已存在时删除重建")
	flag.Parse()
	return opt
}

func run(opt options) error {
	ctx := context.Background()

	// 重跑迁移（-force）不应丢掉用户已经改过的运行时配置，先快照再重建。
	preserved, err := readExistingSettings(opt.sqlitePath)
	if err != nil {
		return err
	}

	if err := prepareTarget(opt); err != nil {
		return err
	}
	if err := db.Open(opt.sqlitePath); err != nil {
		return err
	}
	defer db.Close()

	src, err := connectPG(ctx, opt)
	if err != nil {
		return err
	}
	defer src.Close(ctx)

	// 只读事务：从协议层保证源库不会被本工具改写。
	tx, err := src.BeginTx(ctx, pgx.TxOptions{AccessMode: pgx.ReadOnly})
	if err != nil {
		return fmt.Errorf("开启只读事务失败: %w", err)
	}
	defer tx.Rollback(ctx)

	start := time.Now()
	if err := copyAll(ctx, tx, opt.segment); err != nil {
		return err
	}
	if err := migrateLegacySettings(ctx, tx); err != nil {
		return fmt.Errorf("搬运 AI 运行时设置失败: %w", err)
	}
	if err := seedRuntimeSettings(ctx); err != nil {
		return fmt.Errorf("写入运行时配置失败: %w", err)
	}
	if err := restoreSettings(ctx, preserved); err != nil {
		return fmt.Errorf("恢复既有运行时配置失败: %w", err)
	}
	if err := seedResultProvenance(ctx); err != nil {
		return fmt.Errorf("登记 AI 结果溯源失败: %w", err)
	}
	log.Printf("数据搬运完成，耗时 %s", time.Since(start).Round(time.Second))

	if err := verify(ctx, tx, opt.sample); err != nil {
		return err
	}
	log.Printf("抽样校验通过。原 PostgreSQL 库未被修改，回滚方式：删除 %s 后重启服务。", opt.sqlitePath)
	log.Printf("提示：comix_* 表需另行执行 gizmos/comix 的 init 与 import_from_pg 脚本。")
	return nil
}

// prepareTarget 保证目标文件不会覆盖已有数据（除非显式 -force）。
func prepareTarget(opt options) error {
	abs, err := filepath.Abs(opt.sqlitePath)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
		return err
	}
	fi, err := os.Stat(abs)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if fi.Size() == 0 {
		return nil
	}
	if !opt.force {
		return fmt.Errorf("目标文件已存在且非空: %s（确认可覆盖后加 -force）", abs)
	}
	log.Printf("-force：删除既有目标库 %s", abs)
	// SQLite 还会带 WAL/SHM 附属文件，一并清理，避免旧数据残留。
	for _, suffix := range []string{"", "-wal", "-shm"} {
		if err := os.Remove(abs + suffix); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func connectPG(ctx context.Context, opt options) (*pgx.Conn, error) {
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=prefer",
		opt.pgHost, opt.pgPort, opt.pgUser, opt.pgPassword, opt.pgDB)
	conn, err := pgx.Connect(ctx, dsn)
	if err != nil {
		return nil, fmt.Errorf("连接 PostgreSQL 失败: %w", err)
	}
	return conn, nil
}

// copyAll 按 group 分组搬运：同组表共用一个事务并推迟外键检查。
func copyAll(ctx context.Context, src pgx.Tx, segment int) error {
	for i := 0; i < len(tables); {
		spec := tables[i]
		if spec.group == "" {
			n, err := copySegmented(ctx, src, spec, segment)
			if err != nil {
				return fmt.Errorf("搬运 %s 失败: %w", spec.pg, err)
			}
			log.Printf("  %-26s → %-30s %7d 行", spec.pg, spec.sqlite, n)
			i++
			continue
		}
		j := i
		var group []tableSpec
		for j < len(tables) && tables[j].group == spec.group {
			group = append(group, tables[j])
			j++
		}
		n, err := copyGroupDeferred(ctx, src, group)
		if err != nil {
			return fmt.Errorf("搬运 %s 组失败: %w", spec.group, err)
		}
		log.Printf("  [%s] 共 %d 张表 %7d 行", spec.group, len(group), n)
		i = j
	}
	return nil
}

// copySegmented 普通表：每 segment 行一个事务。
func copySegmented(ctx context.Context, src pgx.Tx, spec tableSpec, segment int) (int, error) {
	insertSQL := buildInsert(spec)
	total := 0
	err := iterateRows(ctx, src, spec, segment, func(batch [][]any) error {
		if err := insertSegment(ctx, insertSQL, batch); err != nil {
			return err
		}
		total += len(batch)
		return nil
	})
	return total, err
}

// copyGroupDeferred 一组表共用一个事务，把外键检查推迟到提交时。
//
// 组内表按行流式写入而不预读入内存：人脸表的 embedding 每行 2KB，全量驻留没有意义。
func copyGroupDeferred(ctx context.Context, src pgx.Tx, group []tableSpec) (int, error) {
	total := 0
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, "PRAGMA defer_foreign_keys = ON"); err != nil {
			return err
		}
		for _, spec := range group {
			insertSQL := buildInsert(spec)
			stmt, err := tx.PrepareContext(ctx, insertSQL)
			if err != nil {
				return err
			}
			n := 0
			iterErr := iterateRows(ctx, src, spec, 512, func(batch [][]any) error {
				for _, row := range batch {
					if _, err := stmt.ExecContext(ctx, row...); err != nil {
						return err
					}
				}
				n += len(batch)
				return nil
			})
			stmt.Close()
			if iterErr != nil {
				return fmt.Errorf("搬运 %s 失败: %w", spec.pg, iterErr)
			}
			total += n
			log.Printf("  %-26s → %-30s %7d 行", spec.pg, spec.sqlite, n)
		}
		return nil
	})
	return total, err
}

// iterateRows 按 batchSize 从源表读出转换后的行并交给 fn。
func iterateRows(ctx context.Context, src pgx.Tx, spec tableSpec, batchSize int, fn func([][]any) error) error {
	names := make([]string, len(spec.cols))
	for i, c := range spec.cols {
		names[i] = c.name
	}
	// 用主键排序保证分段稳定（源库只读，不依赖物理顺序）。
	order := ""
	if len(spec.keys) > 0 {
		keyNames := make([]string, len(spec.keys))
		for i, k := range spec.keys {
			keyNames[i] = k.name
		}
		order = " ORDER BY " + strings.Join(keyNames, ", ")
	}
	rows, err := src.Query(ctx, fmt.Sprintf("SELECT %s FROM %s%s", strings.Join(names, ", "), spec.pg, order))
	if err != nil {
		return err
	}
	defer rows.Close()

	batch := make([][]any, 0, batchSize)
	flush := func() error {
		if len(batch) == 0 {
			return nil
		}
		if err := fn(batch); err != nil {
			return err
		}
		batch = batch[:0]
		return nil
	}

	for rows.Next() {
		values, err := rows.Values()
		if err != nil {
			return fmt.Errorf("读取行失败: %w", err)
		}
		converted := make([]any, len(spec.cols))
		for i, c := range spec.cols {
			v, err := convert(values[i], c.kind)
			if err != nil {
				return fmt.Errorf("列 %s 转换失败: %w", c.name, err)
			}
			converted[i] = v
		}
		batch = append(batch, converted)
		if len(batch) >= batchSize {
			if err := flush(); err != nil {
				return err
			}
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}
	return flush()
}

func buildInsert(spec tableSpec) string {
	names := make([]string, len(spec.cols))
	for i, c := range spec.cols {
		names[i] = `"` + c.name + `"`
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(spec.cols)), ",")
	return fmt.Sprintf("INSERT INTO %s (%s) VALUES (%s)", spec.sqlite, strings.Join(names, ", "), placeholders)
}

// insertSegment 在一个事务内写入一段行。
func insertSegment(ctx context.Context, insertSQL string, batch [][]any) error {
	return db.Tx(ctx, func(tx *sql.Tx) error {
		return execRows(ctx, tx, insertSQL, batch)
	})
}

func execRows(ctx context.Context, tx *sql.Tx, insertSQL string, batch [][]any) error {
	stmt, err := tx.PrepareContext(ctx, insertSQL)
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, row := range batch {
		if _, err := stmt.ExecContext(ctx, row...); err != nil {
			return err
		}
	}
	return nil
}

// ---------------------------------------------------------------------------
// 值转换
// ---------------------------------------------------------------------------

func convert(v any, kind colKind) (any, error) {
	if v == nil {
		return nil, nil
	}
	switch kind {
	case kText:
		return toText(v), nil
	case kUUID:
		return toUUIDText(v), nil
	case kTime:
		t, ok := v.(time.Time)
		if !ok {
			return nil, fmt.Errorf("期望时间，实际 %T", v)
		}
		return model.FormatTime(t), nil
	case kDate:
		if t, ok := v.(time.Time); ok {
			return model.FormatDate(t), nil
		}
		return toText(v), nil
	case kBool:
		b, ok := v.(bool)
		if !ok {
			return nil, fmt.Errorf("期望布尔，实际 %T", v)
		}
		if b {
			return 1, nil
		}
		return 0, nil
	case kInt, kReal:
		return v, nil
	case kBytes:
		b, ok := v.([]byte)
		if !ok {
			return nil, fmt.Errorf("期望字节，实际 %T", v)
		}
		return b, nil
	case kJSON:
		return toJSONText(v)
	case kTextArray:
		return jsonArray(v, false)
	case kUUIDArray:
		return jsonArray(v, true)
	case kRealArray:
		return jsonArray(v, false)
	default:
		return nil, fmt.Errorf("未知列类型")
	}
}

func toText(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case []byte:
		return string(t)
	case time.Time:
		return model.FormatTime(t)
	default:
		return fmt.Sprint(t)
	}
}

func toUUIDText(v any) string {
	switch t := v.(type) {
	case string:
		return normalizeUUIDText(t)
	case [16]byte:
		return uuid.UUID(t).String()
	case []byte:
		if len(t) == 16 {
			var u uuid.UUID
			copy(u[:], t)
			return u.String()
		}
		return normalizeUUIDText(string(t))
	default:
		return toText(v)
	}
}

func normalizeUUIDText(s string) string {
	if u, err := uuid.Parse(s); err == nil {
		return u.String()
	}
	return s
}

// toJSONText 把 jsonb 列转换成 JSON 文本。
//
// pgx 经 rows.Values() 读 jsonb 时会解成 map[string]any / []any；若直接按文本处理，
// fmt 会把它写成 `map[k:v]` 这种 Go 字面量——既不合法 JSON，也会静默毁掉数据。
// 这里统一重新序列化，只对"本来就是文本"的输入原样透传。
func toJSONText(v any) (string, error) {
	switch t := v.(type) {
	case string:
		return normalizeJSONText(t)
	case []byte:
		return normalizeJSONText(string(t))
	default:
		b, err := json.Marshal(t)
		if err != nil {
			return "", fmt.Errorf("序列化 JSON 列失败: %w", err)
		}
		text := string(b)
		if text == "null" {
			return "null", nil
		}
		return text, nil
	}
}

// normalizeJSONText 校验文本是合法 JSON，并去掉可能存在的空白。
func normalizeJSONText(s string) (string, error) {
	trimmed := strings.TrimSpace(s)
	if trimmed == "" {
		return "", fmt.Errorf("JSON 列为空文本")
	}
	if !json.Valid([]byte(trimmed)) {
		return "", fmt.Errorf("JSON 列内容不是合法 JSON: %.60q", trimmed)
	}
	return trimmed, nil
}

// jsonArray 把 PostgreSQL 数组转换成 JSON 数组文本（DEFAULT '[]' 与之一致）。
func jsonArray(v any, uuidElems bool) (string, error) {
	switch t := v.(type) {
	case []string:
		items := make([]string, len(t))
		for i, s := range t {
			if uuidElems {
				items[i] = normalizeUUIDText(s)
			} else {
				items[i] = s
			}
		}
		return marshalArray(items)
	case [][16]byte:
		items := make([]string, len(t))
		for i, b := range t {
			items[i] = uuid.UUID(b).String()
		}
		return marshalArray(items)
	case []any:
		items := make([]any, len(t))
		for i, e := range t {
			if uuidElems {
				items[i] = toUUIDText(e)
			} else {
				items[i] = e
			}
		}
		return marshalArray(items)
	case []float32:
		return marshalArray(t)
	case []float64:
		return marshalArray(t)
	default:
		b, err := json.Marshal(v)
		if err != nil {
			return "", err
		}
		if string(b) == "null" {
			return "[]", nil
		}
		return string(b), nil
	}
}

func marshalArray(v any) (string, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return "", err
	}
	if string(b) == "null" {
		return "[]", nil
	}
	return string(b), nil
}

// ---------------------------------------------------------------------------
// 运行时设置与 AI 结果溯源
// ---------------------------------------------------------------------------

// legacySettingsKeys 把旧的 ai.settings 键映射到新的 app_settings 键。
var legacySettingsKeys = map[string]string{
	"vlm_model":         "ai.vlm_model",
	"auto_capabilities": "ai.auto_capabilities",
	"auto_caps":         "ai.auto_capabilities",
	"ollama_vlm_model":  "ai.vlm_model",
}

func migrateLegacySettings(ctx context.Context, src pgx.Tx) error {
	rows, err := src.Query(ctx, "SELECT key, value FROM ai.settings")
	if err != nil {
		return err
	}
	defer rows.Close()

	count := 0
	for rows.Next() {
		var key, value string
		if err := rows.Scan(&key, &value); err != nil {
			return err
		}
		newKey, ok := legacySettingsKeys[key]
		if !ok {
			newKey = key
		}
		if _, err := db.W().ExecContext(ctx,
			`INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)
			 ON CONFLICT (key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
			newKey, value, model.Now()); err != nil {
			return err
		}
		count++
	}
	if count > 0 {
		log.Printf("已搬运 %d 项 AI 运行时设置", count)
	}
	return rows.Err()
}

// seedRuntimeSettings 把当前 .env 中的运行时配置写入 app_settings，
// 使迁移后服务端行为与迁移前一致；此后这些值由 UI 读写。
func seedRuntimeSettings(ctx context.Context) error {
	mapping := map[string]string{
		"app.static_dir":          "STATIC_DIR",
		"app.gallery_dir":         "GALLERY_DIR",
		"comix.python":            "COMIX_PYTHON",
		"ai.enabled":              "AI_ENABLED",
		"ai.python":               "AI_PYTHON",
		"ai.sidecar_dir":          "AI_SIDECAR_DIR",
		"ai.idle_timeout":         "AI_IDLE_TIMEOUT",
		"ai.batch_size":           "AI_BATCH_SIZE",
		"ai.job_timeout":          "AI_JOB_TIMEOUT",
		"ai.max_attempts":         "AI_MAX_ATTEMPTS",
		"ai.workers":              "AI_WORKERS",
		"ai.embed_model":          "AI_EMBED_MODEL",
		"ai.auto_capabilities":    "AI_AUTO_CAPS",
		"ai.device":               "AI_DEVICE",
		"ai.ollama.url":           "OLLAMA_URL",
		"ai.vlm_model":            "OLLAMA_VLM_MODEL",
		"ai.ollama.vlm_model_alt": "OLLAMA_VLM_MODEL_ALT",
		"ai.ollama.vlm_ctx":       "OLLAMA_VLM_CTX",
		"ai.ollama.keep_alive":    "OLLAMA_KEEP_ALIVE",
		"ai.ollama.idle_timeout":  "OLLAMA_IDLE_TIMEOUT",
		"ai.ollama.exe":           "OLLAMA_EXE",
		"ai.ollama.models":        "OLLAMA_MODELS",
	}

	count := 0
	for key, envName := range mapping {
		value := strings.TrimSpace(os.Getenv(envName))
		if value == "" {
			continue
		}
		if _, err := db.W().ExecContext(ctx,
			`INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)
			 ON CONFLICT (key) DO NOTHING`,
			key, value, model.Now()); err != nil {
			return fmt.Errorf("写入 %s 失败: %w", key, err)
		}
		count++
	}
	if count == 0 {
		// 迁移后 .env 已精简，重跑本工具时需要手动提供这些旧配置项，
		// 否则运行时配置会回落到代码默认值（媒体库根目录会变空）。
		log.Printf("警告：未从环境变量读到任何旧配置，运行时配置将使用代码默认值。" +
			"重跑迁移前请先设置 GALLERY_DIR / STATIC_DIR / AI_* / OLLAMA_* 等旧变量。")
	}
	log.Printf("已从 .env 写入 %d 项运行时配置（其余沿用代码默认值）", count)
	return nil
}

// seedResultProvenance 按"迁移前的实际情况"登记 AI 结果溯源。
//
// 旧代码对所有能力都喂 256 预览图，因此如实写 preview256；face/ocr/vlm 的期望档位
// 已是 ai1024，reconcile 循环据此自动重排，无需人工干预。
func seedResultProvenance(ctx context.Context) error {
	embedModel := envOr("AI_EMBED_MODEL", "siglip2-base-patch16-224")
	vlmModel := envOr("OLLAMA_VLM_MODEL", "qwen3.5:4b")
	now := model.Now()

	type seed struct {
		capability string
		executor   string
		query      string
	}
	seeds := []seed{
		{model.CapPHash, model.ImplPHashGoDCT,
			`INSERT INTO ai_results (media_id, capability, input_tier, executor, updated_at)
			 SELECT media_id, ?, ?, ?, ? FROM ai_media WHERE phash IS NOT NULL
			 ON CONFLICT (media_id, capability) DO NOTHING`},
		{model.CapEmbed, embedModel,
			`INSERT INTO ai_results (media_id, capability, input_tier, executor, updated_at)
			 SELECT media_id, ?, ?, ?, ? FROM ai_embeddings WHERE kind = 'image' GROUP BY media_id
			 ON CONFLICT (media_id, capability) DO NOTHING`},
		{model.CapFace, model.ImplFaceSidecar,
			`INSERT INTO ai_results (media_id, capability, input_tier, executor, updated_at)
			 SELECT media_id, ?, ?, ?, ? FROM ai_faces GROUP BY media_id
			 ON CONFLICT (media_id, capability) DO NOTHING`},
		{model.CapOCR, model.ImplOCRSidecar,
			`INSERT INTO ai_results (media_id, capability, input_tier, executor, updated_at)
			 SELECT media_id, ?, ?, ?, ? FROM ai_media WHERE ocr_text IS NOT NULL
			 ON CONFLICT (media_id, capability) DO NOTHING`},
		{model.CapVLM, vlmModel,
			`INSERT INTO ai_results (media_id, capability, input_tier, executor, updated_at)
			 SELECT media_id, ?, ?, ?, ? FROM ai_media WHERE caption IS NOT NULL
			 ON CONFLICT (media_id, capability) DO NOTHING`},
	}

	total := int64(0)
	for _, s := range seeds {
		res, err := db.W().ExecContext(ctx, s.query,
			s.capability, model.LegacyInputTier, s.executor, now)
		if err != nil {
			return fmt.Errorf("登记 %s 溯源失败: %w", s.capability, err)
		}
		n, _ := res.RowsAffected()
		total += n
		log.Printf("  溯源 %-6s tier=%-11s executor=%-34s %7d 行", s.capability, model.LegacyInputTier, s.executor, n)
	}
	log.Printf("已登记 %d 条 AI 结果溯源；face/ocr/vlm 因输入档位升级将被自动重排", total)
	return nil
}

// ---------------------------------------------------------------------------
// 抽样校验
// ---------------------------------------------------------------------------

func verify(ctx context.Context, src pgx.Tx, sample int) error {
	log.Printf("开始校验（每表抽样 %d 行）", sample)
	var failures []string

	for _, spec := range tables {
		pgCount, err := countPG(ctx, src, spec.pg)
		if err != nil {
			return err
		}
		sqliteCount, err := countSQLite(ctx, spec.sqlite)
		if err != nil {
			return err
		}
		if pgCount != sqliteCount {
			failures = append(failures, fmt.Sprintf("%s 行数不一致: pg=%d sqlite=%d", spec.pg, pgCount, sqliteCount))
			continue
		}
		if sample <= 0 || pgCount == 0 {
			continue
		}
		// JSON 列必须真的是合法 JSON：抽样逐列比对只能证明"拷贝忠实"，
		// 证明不了"转换正确"，所以这里对全部行做一次结构校验。
		invalid, err := countInvalidJSON(ctx, spec)
		if err != nil {
			return err
		}
		if invalid > 0 {
			failures = append(failures,
				fmt.Sprintf("%s 有 %d 行的 JSON 列不是合法 JSON（转换器有问题，先修再迁）", spec.pg, invalid))
			continue
		}
		mismatches, err := compareSample(ctx, src, spec, sample)
		if err != nil {
			return err
		}
		if mismatches > 0 {
			failures = append(failures, fmt.Sprintf("%s 抽样不一致 %d 行", spec.pg, mismatches))
			continue
		}
		log.Printf("  %-26s 行数 %7d 一致，抽样 %d 行一致", spec.pg, pgCount, min(sample, int(pgCount)))
	}

	if len(failures) > 0 {
		return fmt.Errorf("校验未通过:\n  - %s", strings.Join(failures, "\n  - "))
	}
	return nil
}

func countPG(ctx context.Context, src pgx.Tx, table string) (int64, error) {
	var n int64
	if err := src.QueryRow(ctx, "SELECT count(*) FROM "+table).Scan(&n); err != nil {
		return 0, err
	}
	return n, nil
}

func countSQLite(ctx context.Context, table string) (int64, error) {
	var n int64
	if err := db.R().QueryRowContext(ctx, "SELECT count(*) FROM "+table).Scan(&n); err != nil {
		return 0, err
	}
	return n, nil
}

// jsonColumns 返回该表需要校验 JSON 合法性的列名。
func jsonColumns(spec tableSpec) []string {
	var out []string
	for _, c := range spec.cols {
		switch c.kind {
		case kJSON, kTextArray, kUUIDArray, kRealArray:
			out = append(out, c.name)
		}
	}
	return out
}

// countInvalidJSON 统计 JSON 列中不是合法 JSON 的行数（json_valid 对 NULL 返回 1）。
func countInvalidJSON(ctx context.Context, spec tableSpec) (int64, error) {
	columns := jsonColumns(spec)
	if len(columns) == 0 {
		return 0, nil
	}
	conditions := make([]string, 0, len(columns))
	for _, name := range columns {
		conditions = append(conditions, fmt.Sprintf(`"%s" IS NOT NULL AND json_valid("%s") = 0`, name, name))
	}
	query := fmt.Sprintf("SELECT count(*) FROM %s WHERE %s", spec.sqlite, strings.Join(conditions, " OR "))
	var n int64
	if err := db.R().QueryRowContext(ctx, query).Scan(&n); err != nil {
		return 0, fmt.Errorf("校验 %s 的 JSON 列失败: %w", spec.sqlite, err)
	}
	return n, nil
}

// compareSample 随机抽取若干主键，逐列比对两侧的规范化取值。
func compareSample(ctx context.Context, src pgx.Tx, spec tableSpec, sample int) (int, error) {
	keys, err := sampleKeys(ctx, src, spec, sample)
	if err != nil {
		return 0, err
	}

	pgNames := make([]string, len(spec.cols))
	sqliteNames := make([]string, len(spec.cols))
	for i, c := range spec.cols {
		pgNames[i] = c.name
		sqliteNames[i] = `"` + c.name + `"`
	}
	pgConds := make([]string, len(spec.keys))
	sqliteConds := make([]string, len(spec.keys))
	for i, k := range spec.keys {
		pgConds[i] = fmt.Sprintf("%s = $%d", k.name, i+1)
		sqliteConds[i] = fmt.Sprintf("%s = ?", k.name)
	}
	pgSQL := fmt.Sprintf("SELECT %s FROM %s WHERE %s",
		strings.Join(pgNames, ", "), spec.pg, strings.Join(pgConds, " AND "))
	sqliteSQL := fmt.Sprintf("SELECT %s FROM %s WHERE %s",
		strings.Join(sqliteNames, ", "), spec.sqlite, strings.Join(sqliteConds, " AND "))

	mismatches := 0
	for _, key := range keys {
		pgRow, err := readPGCanonical(ctx, src, pgSQL, key, spec)
		if err != nil {
			return 0, fmt.Errorf("%s 读取源行失败: %w", spec.pg, err)
		}
		sqliteRow, err := readSQLiteCanonical(ctx, sqliteSQL, key, len(spec.cols))
		if err != nil {
			return 0, fmt.Errorf("%s 读取目标行失败: %w", spec.sqlite, err)
		}
		if pgRow != sqliteRow {
			mismatches++
			if mismatches <= 3 {
				log.Printf("    ! %s %v 不一致\n      pg    : %s\n      sqlite: %s", spec.pg, key, pgRow, sqliteRow)
			}
		}
	}
	return mismatches, nil
}

// sampleKeys 随机抽取主键，统一转成 SQLite 侧的表示（uuid → 文本）。
func sampleKeys(ctx context.Context, src pgx.Tx, spec tableSpec, sample int) ([][]any, error) {
	names := make([]string, len(spec.keys))
	for i, k := range spec.keys {
		names[i] = k.name
	}
	rows, err := src.Query(ctx, fmt.Sprintf("SELECT %s FROM %s ORDER BY random() LIMIT %d",
		strings.Join(names, ", "), spec.pg, sample))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out [][]any
	for rows.Next() {
		values, err := rows.Values()
		if err != nil {
			return nil, err
		}
		key := make([]any, len(spec.keys))
		for i, k := range spec.keys {
			v, err := convert(values[i], k.kind)
			if err != nil {
				return nil, err
			}
			key[i] = v
		}
		out = append(out, key)
	}
	return out, rows.Err()
}

func readPGCanonical(ctx context.Context, src pgx.Tx, query string, key []any, spec tableSpec) (string, error) {
	rows, err := src.Query(ctx, query, key...)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	if !rows.Next() {
		return "", fmt.Errorf("源行不存在")
	}
	values, err := rows.Values()
	if err != nil {
		return "", err
	}
	canonical := make([]any, len(values))
	for i, v := range values {
		converted, err := convert(v, spec.cols[i].kind)
		if err != nil {
			return "", err
		}
		canonical[i] = canonicalValue(converted)
	}
	return fmt.Sprint(canonical), nil
}

func readSQLiteCanonical(ctx context.Context, query string, key []any, n int) (string, error) {
	dest := make([]any, n)
	ptrs := make([]any, n)
	for i := range dest {
		ptrs[i] = &dest[i]
	}
	if err := db.R().QueryRowContext(ctx, query, key...).Scan(ptrs...); err != nil {
		return "", err
	}
	canonical := make([]any, n)
	for i, v := range dest {
		canonical[i] = canonicalValue(v)
	}
	return fmt.Sprint(canonical), nil
}

// canonicalValue 抹平两侧的表示差异：数字统一成 int64/float64，二进制统一成十六进制。
func canonicalValue(v any) any {
	switch t := v.(type) {
	case nil:
		return nil
	case []byte:
		return fmt.Sprintf("hex:%x", t)
	case int:
		return int64(t)
	case int32:
		return int64(t)
	case int64:
		return t
	case float32:
		return float64(t)
	case bool:
		if t {
			return int64(1)
		}
		return int64(0)
	case time.Time:
		return model.FormatTime(t)
	default:
		return t
	}
}

func envOr(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

// ---------------------------------------------------------------------------
// 既有运行时配置的保留
// ---------------------------------------------------------------------------

// readExistingSettings 从已存在的目标库读出 app_settings 快照。
//
// 目标库不存在或还没有该表时返回 nil —— 迁移要能在全新环境直接跑通。
func readExistingSettings(path string) (map[string]string, error) {
	abs, err := filepath.Abs(path)
	if err != nil {
		return nil, err
	}
	if fi, err := os.Stat(abs); err != nil || fi.Size() == 0 {
		return nil, nil
	}

	conn, err := sql.Open("sqlite", "file:"+filepath.ToSlash(abs)+"?mode=ro")
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	rows, err := conn.Query(`SELECT key, value FROM app_settings`)
	if err != nil {
		// 表不存在（或不是本项目的库）时无需保留任何东西
		return nil, nil
	}
	defer rows.Close()

	out := map[string]string{}
	for rows.Next() {
		var k, v string
		if err := rows.Scan(&k, &v); err != nil {
			return nil, err
		}
		out[k] = v
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(out) == 0 {
		return nil, nil
	}
	log.Printf("目标库已有 %d 项运行时配置，将在重建后原样恢复", len(out))
	return out, nil
}

// restoreSettings 把快照写回（覆盖环境变量播种的初值，因为用户改过的值才是权威）。
func restoreSettings(ctx context.Context, values map[string]string) error {
	if len(values) == 0 {
		return nil
	}
	now := model.Now()
	err := db.Tx(ctx, func(tx *sql.Tx) error {
		for key, value := range values {
			if _, err := tx.ExecContext(ctx,
				`INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)
				 ON CONFLICT (key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
				key, value, now); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return err
	}
	log.Printf("已恢复 %d 项既有运行时配置", len(values))
	return nil
}
