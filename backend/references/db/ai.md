# AI 数据

建表真源为 [sqlite.sql](sqlite.sql)，读写在 [ai_repo](../../internal/repository/ai_repo/)。AI 关键词独立于人工标签，VLM 每次按媒体整体替换关键词。

- phash/embed 用 `preview256`，face/ocr/vlm 优先用 1024 派生图，失败回退预览。任务和产物的 `input_sig` 记录图源档位及执行者，配置差异供诊断。reconcile 只补缺失任务，重生成由用户触发。
- `media_ai.phash=-1` 表示无法解码，OCR 空串表示完成但无文字。未检出人脸由任务 `done` 状态表示。
- 图像向量按 `(media_id, kind, model)` 保存 L2 归一后的 int8 数据和 scale。图片与文字编码使用同一模型、多语种分词器和 CPU。Go 精确扫描向量，空闲回收索引。OCR/描述片段过滤用 `LIKE`。
- 人脸特征为 L2 归一后的 512 维 float32，bbox 为归一坐标。未归组的人脸 `person_id` 为空。流水线把新人脸归入已有组，批量聚类才创建候选组。人物计数由服务端重算。
- 任务按 `(capability, media_id)` 去重，在写事务中认领。`duplicate_ignores` 排除被人工否决的媒体，清除标记后重新参与分组。
- AI 缺产物统计依赖 `media_assets(is_deleted, id)` 覆盖索引，由诊断接口按需查询。
