# AI 处理层数据表 (ai schema)

独立 schema，可整体回滚：`DROP SCHEMA ai CASCADE`（见 `references/db/ai_rollback.sql`）。
不修改 gallery / user_data / comix 的任何既有对象，只以外键引用 `gallery.media_assets`。

**AI 产物与人工数据物理隔离**：人工标签在 `gallery.tags`，AI 关键词在
`ai.media_ai.vlm_tags`，两者天然可区分，不会互相覆盖。

## 扩展

| 扩展 | 位置 | 用途 |
| ---- | ---- | ---- |
| `pg_trgm` | 装入 `ai` schema | OCR 文本 / VLM 描述的子串检索索引（contrib 内置，无需编译安装） |

> **不需要 pgvector**：图像向量以 int8 量化存于 `ai.embeddings.vec`，检索由
> Go 服务把全量向量载入内存做精确余弦扫描（7w × 768 维 ≈ 54MB，单次查询数十毫秒）。

## media_ai

单媒体的 AI 标量结果（一媒体一行，各列可独立为空）。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| media_id | UUID PRIMARY KEY FK→gallery.media_assets ON DELETE CASCADE | |
| phash | BIGINT | 感知哈希；`-1` 表示无法解码（占位，避免重复尝试） |
| ocr_text | TEXT | OCR 全文（多行拼接）；`''` 表示已识别但无文字 |
| caption | TEXT | VLM 生成的一句话描述 |
| vlm_tags | TEXT[] NOT NULL DEFAULT '{}' | VLM 关键词 |
| updated_at | TIMESTAMPTZ (自动更新) | 由 `ai.update_updated_at_column()` 触发器维护 |

索引：`phash`、`vlm_tags` GIN、`ocr_text`/`caption` trigram GIN。

> `updated_at` 触发器函数**自带在 ai schema 内**（`ai.update_updated_at_column`），
> 不依赖 `public` 或其它 schema 的同名函数——生产库中 gallery / user_data 各自持有
> 自己的副本，ai 沿用同一约定，从而保证 ai.sql 可独立执行与整体回收。

## embeddings

图像向量（一媒体一模型一行），int8 量化。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| media_id | UUID FK→media_assets ON DELETE CASCADE | |
| kind | TEXT | 目前仅 `image` |
| model | TEXT | 如 `siglip2-base-patch16-224` |
| dim | INTEGER | 维度 |
| scale | REAL | 反量化系数：真实分量 = int8 值 × scale |
| vec | BYTEA | dim 字节 int8 |

主键：`(media_id, kind, model)`。量化前做 L2 归一化，故内积即余弦相似度。

> 模型必须是**多语种分词器**版本。SigLIP 1（`siglip-base-patch16-224`）的 3.2 万词表
> 不含中文，中文查询全部退化成 `<unk>`，不同查询会得到完全相同的向量——语义搜索
> 表面正常、结果全错。默认使用 SigLIP 2（Gemma 25.6 万词表）。换模型后旧向量不再
> 被读取（`model` 是主键的一部分），需要清掉并重跑 `embed`。

## faces / persons

| faces 列 | 类型 | 说明 |
| -------- | ---- | ---- |
| id | UUID PRIMARY KEY | |
| media_id | UUID FK→media_assets ON DELETE CASCADE | |
| person_id | UUID FK→persons ON DELETE SET NULL | 未归组时为 NULL |
| bbox | REAL[] | 归一化 x1,y1,x2,y2 |
| det_score | REAL | 检测置信度 |
| quality | REAL | 检测分 × 人脸尺寸权重，用于选封面与聚类顺序 |
| embedding | BYTEA | 512 维 float32（已 L2 归一化），2048 字节 |

| persons 列 | 类型 | 说明 |
| ---------- | ---- | ---- |
| id | UUID PRIMARY KEY | |
| name | TEXT | 人工命名，可空 |
| cover_face_id | UUID FK→faces ON DELETE SET NULL | 质量最高的人脸 |
| face_count | INTEGER | 冗余计数，由服务端在归并后重算 |

聚类策略（`internal/service/ai/cluster.go`）：以人物中心为锚做在线增量归并，
余弦阈值默认 0.45；常规流水线只把新人脸并入现有人物，批量聚类才新建分组，
且**只有 ≥2 张人脸的候选簇**才会落库，避免大量单人分组污染界面。

## jobs

任务队列：一行 = 一个 (能力, 媒体) 处理单元。

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| id | BIGSERIAL PRIMARY KEY | |
| capability | TEXT | `phash` / `embed` / `face` / `ocr` / `vlm` |
| media_id | UUID FK→media_assets ON DELETE CASCADE | |
| status | TEXT | `pending` / `running` / `done` / `failed` |
| priority | SMALLINT DEFAULT 100 | 越小越先处理 |
| attempts | SMALLINT DEFAULT 0 | 认领时 +1 |
| last_error | TEXT | 最近一次失败原因 |
| started_at / finished_at | TIMESTAMPTZ | |
| created_at / updated_at | TIMESTAMPTZ (updated_at 自动更新) | |

唯一约束：`(capability, media_id)` —— 入队天然幂等。
认领使用 `FOR UPDATE SKIP LOCKED`，多 worker 安全。

## settings

| 列 | 类型 | 说明 |
| -- | ---- | ---- |
| key | TEXT PRIMARY KEY | 目前仅有 `auto_capabilities` |
| value | TEXT | 逗号分隔的能力列表 |
| updated_at | TIMESTAMPTZ (自动更新) | |

`auto_capabilities` 决定"入库后自动入队处理哪些能力"，可在桌面端 AI 页面实时调整，
未选中者只能手动提交（VLM 默认不在其中：单张 5-15 秒，全量代价过高）。
