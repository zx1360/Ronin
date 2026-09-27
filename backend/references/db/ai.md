# AI 处理层数据表

> **输入档位**：phash / embed 用 `preview256`（256 预览图，够用且统一 JPEG）；
> face / ocr / vlm 用 `ai1024`（长边 1024 的 AI 专用派生档，按需生成并缓存在
> `<GALLERY_DIR>/AI/`）。只有这两档，`Preview` 的语义与用途不变。
>
> **结果溯源**：每条 (媒体, 能力) 的输入档位与执行者记录在 `ai_results`；
> reconcile 循环发现与期望规格不符时自动重排（`EnqueueStale`），无需人工干预。
>
> **不需要向量扩展**：图像向量以 int8 量化存于 `ai_embeddings.vec`，检索由 Go 服务
> 把全量向量载入内存做精确余弦扫描（7w × 768 维 ≈ 54MB，单次查询数十毫秒）。
>
> 模糊检索由 SQLite 的 `LIKE` 承担（ASCII 大小写不敏感，中文不受影响）；
> 数组检索用 JSON1 的 `json_each`。原 `ai.settings` 表已并入顶层 `app_settings`。

## ai_media

单媒体的 AI 标量结果（一媒体一行，各列可独立为空）。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| media_id | TEXT PRIMARY KEY FK→gallery_media_assets ON DELETE CASCADE | |
| phash | INTEGER | 感知哈希；`-1` 表示无法解码（占位，避免重复尝试） |
| ocr_text | TEXT | OCR 全文（多行拼接）；`''` 表示已识别但无文字 |
| caption | TEXT | VLM 生成的一句话描述 |
| vlm_tags | TEXT NOT NULL DEFAULT '[]' | VLM 关键词（JSON 数组） |
| updated_at | TEXT NOT NULL | |

索引：`phash`。**AI 关键词与人工标签物理隔离**：人工标签在 `gallery_tags`，
AI 关键词在 `ai_media.vlm_tags`，不会互相覆盖。

## ai_results

结果溯源：这是"自动重排"的唯一判据。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| media_id | TEXT FK→gallery_media_assets ON DELETE CASCADE | |
| capability | TEXT | `phash` / `embed` / `face` / `ocr` / `vlm` |
| input_tier | TEXT | `preview256` / `ai1024` |
| executor | TEXT | 能力实现或模型标识 |
| updated_at | TEXT NOT NULL | |

主键 `(media_id, capability)`；索引 `(capability, input_tier, executor)`。
face 每媒体只写一行（不按人脸计）。执行者标识：phash 为 `go-dct-phash-v1`，
embed 为向量模型名（与 `ai_embeddings.model` 一致），face 为 `buffalo_l`，
ocr 为 `rapidocr`，vlm 为当前 Ollama 模型名。

## ai_embeddings

图像向量（一媒体一模型一行），int8 量化。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| media_id | TEXT FK→gallery_media_assets ON DELETE CASCADE | |
| kind | TEXT | 目前仅 `image` |
| model | TEXT | 如 `siglip2-base-patch16-224` |
| dim | INTEGER | 维度 |
| scale | REAL | 反量化系数：真实分量 = int8 值 × scale |
| vec | BLOB | dim 字节 int8 |
| updated_at | TEXT NOT NULL | |

主键 `(media_id, kind, model)`。量化前做 L2 归一化，故内积即余弦相似度。

> 模型必须是**多语种分词器**版本。SigLIP 1（`siglip-base-patch16-224`）的 3.2 万词表
> 不含中文，中文查询全部退化成 `<unk>`，不同查询会得到完全相同的向量——语义搜索
> 表面正常、结果全错。默认使用 SigLIP 2（Gemma 25.6 万词表）。换模型后旧向量不再
> 被读取（`model` 是主键的一部分），并由 `ai_results` 失配自动重排 `embed`。

## ai_faces / ai_persons

| ai_faces 列 | 类型 | 说明 |
| ----------- | ---- | ---- |
| id | TEXT PRIMARY KEY | |
| media_id | TEXT FK→gallery_media_assets ON DELETE CASCADE | |
| person_id | TEXT FK→ai_persons ON DELETE SET NULL | 未归组时为 NULL |
| bbox | TEXT NOT NULL DEFAULT '[]' | 归一化 x1,y1,x2,y2（JSON 数组） |
| det_score | REAL | 检测置信度 |
| quality | REAL | 检测分 × 人脸尺寸权重，用于选封面与聚类顺序 |
| embedding | BLOB | 512 维 float32（已 L2 归一化），2048 字节 |
| created_at | TEXT NOT NULL | |

| ai_persons 列 | 类型 | 说明 |
| ------------- | ---- | ---- |
| id | TEXT PRIMARY KEY | |
| name | TEXT | 人工命名，可空 |
| cover_face_id | TEXT FK→ai_faces ON DELETE SET NULL | 质量最高的人脸 |
| face_count | INTEGER | 冗余计数，由服务端在归并后重算 |
| created_at / updated_at | TEXT NOT NULL | |

两表互相引用（环形），建表顺序与写入都依赖 `PRAGMA foreign_keys=ON`。

聚类策略（`internal/service/ai/cluster.go`）：以人物中心为锚做在线增量归并，
余弦阈值默认 0.45；常规流水线只把新人脸并入现有人物，批量聚类才新建分组，
且**只有 ≥2 张人脸的候选簇**才会落库，避免大量单人分组污染界面。

## ai_jobs

任务队列：一行 = 一个 (能力, 媒体) 处理单元。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT | |
| capability | TEXT | `phash` / `embed` / `face` / `ocr` / `vlm` |
| media_id | TEXT FK→gallery_media_assets ON DELETE CASCADE | |
| status | TEXT | `pending` / `running` / `done` / `failed` |
| priority | INTEGER DEFAULT 100 | 越小越先处理 |
| attempts | INTEGER DEFAULT 0 | 认领时 +1 |
| last_error | TEXT | 最近一次失败原因 |
| started_at / finished_at | TEXT | |
| created_at / updated_at | TEXT NOT NULL | |

唯一约束 `(capability, media_id)`——入队天然幂等。
**不需要 `FOR UPDATE SKIP LOCKED`**：写连接池只有一条连接，认领在进程内天然串行。

## ai_duplicate_ignores

去重的人工判定：被标记的媒体不再参与近重复分组。只记录"人工否决"，
不改动任何 AI 产物，删除记录即可恢复原分组结果。

| 列 | 类型 |
| -- | ---- |
| media_id | TEXT PRIMARY KEY FK→gallery_media_assets ON DELETE CASCADE |
| created_at | TEXT NOT NULL |

## ai_reviews / ai_review_presets

近期回顾：统计由后端算出（`ai_reviews.stats`），叙述交本地模型写入
（`ai_reviews.narrative`）。缓存键是"统计指纹 + 预设 + 模型"，数据没变不重复推理。

| ai_reviews 列 | 类型 | 说明 |
| ------------- | ---- | ---- |
| id | INTEGER PRIMARY KEY AUTOINCREMENT | |
| kind | TEXT | 目前仅 `recent` |
| scope_key | TEXT | 统计内容的确定性指纹 |
| preset_id | TEXT | 使用的语气/角色预设 |
| model | TEXT | 生成所用模型 |
| stats | TEXT | JSON：后端算出的确定性统计 |
| narrative | TEXT | 模型生成的叙述 |
| created_at | TEXT NOT NULL | |

| ai_review_presets 列 | 类型 | 说明 |
| -------------------- | ---- | ---- |
| id | TEXT PRIMARY KEY | |
| name | TEXT NOT NULL | |
| tone / role | TEXT | 语气与角色，均可在前端编辑 |
| is_default | INTEGER | 默认预设不可删除 |
| created_at / updated_at | TEXT NOT NULL | |
