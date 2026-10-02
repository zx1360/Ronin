# AI 处理层数据表

> 建表真源：`references/db/sqlite.sql`（AI 侧 8 张表）。不修改其它模块的任何表，
> 只以外键引用 `media_assets`（`ON DELETE CASCADE`），可整组删除而不影响其它数据。
> 既有库的补列由 `internal/service/db/migrate.go` 负责（见 `AGENTS_DB.md` 的列迁移）。

**AI 产物与人工数据物理隔离**：人工标签在 `tags`，AI 关键词在 `media_ai_tags`，
两者天然可区分，不会互相覆盖。

> **不需要 pgvector**：图像向量以 int8 量化存于 `embeddings.vec`，检索由 Go 服务把
> 全量向量载入内存做精确余弦扫描（7w × 768 维 ≈ 54MB，SQLite 读取比原 pgx 更快：
> 0.41s vs 1.23s）。
>
> **不需要 pg_trgm**：OCR/描述/AI 标签的关键词检索改为 `LIKE '%kw%'` 全表扫描
> （media_ai 表窄，7 万行实测 29ms，快于原 pg_trgm 路径）；代价随文本量线性增长，
> 属已知上限，见 `AGENTS_DB.md`。

## 输入档位与执行者指纹（input_sig）

每个能力把"输入档位 + 执行者"记成指纹，形如 `ai1024|ollama:qwen3.5:4b`：

- 输入档位：`preview256`（256 预览档，`phash`/`embed` 用）或 `ai1024`
  （`GALLERY_DIR/AI/<年-月>/<基础名>_ai.jpg`，长边 1024，`face`/`ocr`/`vlm` 用，按需生成并缓存）。
- 执行者：进程内实现（`go-dct-phash`）、侧车模型（`siglip2-…` / `insightface-buffalo_l` /
  `rapidocr-ppocr`）、或 Ollama 模型（`ollama:<模型名>`）。

`jobs.input_sig` 记录"这条任务上次是用什么算的"；与当前指纹不一致时由 reconcile 自动重排
（换 VLM 模型后旧标注会被重算）。三张产物表也各存一份，便于直接看出产物的来源。
旧版本留下的 NULL 指纹不会被自动重排——否则升级后第一次 reconcile 会把全库 28 万条任务
一次性重排；这类历史数据要刷新只能走"全量重生成"。

## media_ai

单媒体的 AI 标量结果（一媒体一行，各列可独立为空）。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| media_id | TEXT PRIMARY KEY FK→media_assets ON DELETE CASCADE | |
| phash | INTEGER | 感知哈希；`-1` 表示无法解码（占位，避免重复尝试） |
| phash_input_sig | TEXT | 计算该哈希时的档位/执行者指纹 |
| ocr_text | TEXT | OCR 全文（多行拼接）；`''` 表示已识别但无文字 |
| ocr_input_sig | TEXT | 同上 |
| caption | TEXT | VLM 生成的一句话描述 |
| caption_input_sig | TEXT | 同上 |
| updated_at | TEXT (AFTER UPDATE 触发器维护) | |

索引：`phash`。

## media_ai_tags

VLM 关键词（替代原 PG 的 `media_ai.vlm_tags text[]`）：一行一个标签，
使「任一命中」与「标签聚合」都退化为普通索引查询。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| media_id | TEXT FK→media_ai ON DELETE CASCADE | |
| tag | TEXT | |

主键：`(media_id, tag)`；另建 `tag` 索引。写入时整组替换（`SaveVLM`）。

## embeddings

图像向量（一媒体一模型一行），int8 量化。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| media_id | TEXT FK→media_assets ON DELETE CASCADE | |
| kind | TEXT | 目前仅 `image` |
| model | TEXT | 如 `siglip2-base-patch16-224` |
| dim | INTEGER | 维度 |
| scale | REAL | 反量化系数：真实分量 = int8 值 × scale |
| vec | BLOB | dim 字节 int8 |
| input_sig | TEXT | 编码该向量时的档位/执行者指纹 |

主键：`(media_id, kind, model)`。量化前做 L2 归一化，故内积即余弦相似度。

> 模型必须是**多语种分词器**版本。SigLIP 1（`siglip-base-patch16-224`）的 3.2 万词表
> 不含中文，中文查询全部退化成 `<unk>`，不同查询会得到完全相同的向量——语义搜索
> 表面正常、结果全错。默认使用 SigLIP 2（Gemma 25.6 万词表）。换模型后旧向量不再
> 被读取（`model` 是主键的一部分），需要清掉并重跑 `embed`。

## faces / persons

| faces 列 | 类型 | 说明 |
| -------- | ---- | ---- |
| id | TEXT PRIMARY KEY | |
| media_id | TEXT FK→media_assets ON DELETE CASCADE | |
| person_id | TEXT FK→persons ON DELETE SET NULL | 未归组时为 NULL |
| bbox | TEXT | JSON `[x1,y1,x2,y2]`（归一化） |
| det_score | REAL | 检测置信度 |
| quality | REAL | 检测分 × 人脸尺寸权重，用于选封面与聚类顺序 |
| embedding | BLOB | 512 维 float32（已 L2 归一化），2048 字节 |
| input_sig | TEXT | 检出该人脸时的档位/执行者指纹 |

> 一张图未检出任何人脸时不会留下行，因此也没有指纹可记——"无脸"本身不是产物，
> 是否已处理过由 `jobs` 的 `done` 状态回答。

| persons 列 | 类型 | 说明 |
| ---------- | ---- | ---- |
| id | TEXT PRIMARY KEY | |
| name | TEXT | 人工命名，可空 |
| cover_face_id | TEXT FK→faces ON DELETE SET NULL | 质量最高的人脸 |
| face_count | INTEGER | 冗余计数，由服务端在归并后重算 |

聚类策略（`internal/service/ai/cluster.go`）：以人物中心为锚做在线增量归并，
余弦阈值默认 0.45；常规流水线只把新人脸并入现有人物，批量聚类才新建分组，
且**只有 ≥2 张人脸的候选簇**才会落库，避免大量单人分组污染界面。

## jobs

任务队列：一行 = 一个 (能力, 媒体) 处理单元。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT | |
| capability | TEXT | `phash` / `embed` / `face` / `ocr` / `vlm` |
| media_id | TEXT FK→media_assets ON DELETE CASCADE | |
| status | TEXT | `pending` / `running` / `done` / `failed` |
| priority | INTEGER DEFAULT 100 | 越小越先处理 |
| attempts | INTEGER DEFAULT 0 | 认领时 +1 |
| last_error | TEXT | 最近一次失败原因 |
| input_sig | TEXT | 本次执行（或上次成功执行）使用的档位/执行者指纹；旧数据为 NULL |
| started_at / finished_at | TEXT | |
| created_at / updated_at | TEXT (updated_at 触发器维护) | |

唯一约束：`(capability, media_id)` —— 入队天然幂等。
认领（`Claim`）改为在写事务内一条 `UPDATE ... WHERE id IN (SELECT ... LIMIT n)
RETURNING id, media_id`：单写者模型下进程内不存在竞争，无需 PG 的
`FOR UPDATE SKIP LOCKED`。

## duplicate_ignores

去重的人工判定：被标记的媒体不再参与近重复分组（分组时直接排除）。
只记录"人工否决"，不改动任何 AI 产物，删除记录即可恢复原分组结果。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| media_id | TEXT PRIMARY KEY FK→media_assets ON DELETE CASCADE | |
| created_at | TEXT | 标记时间 |
