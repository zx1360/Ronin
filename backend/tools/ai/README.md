# Ronin AI 侧车（tools/ai）

给 Monarch 提供语义向量、人脸和 OCR 推理的 Python 进程，用时启动、空闲退出。

## 组成

| 路径 | 说明 |
| ---- | ---- |
| `ronin_ai/` | 随仓库提供的侧车源码 |
| `requirements.txt`、`install.ps1` | 依赖清单与安装入口 |
| `.python/`、`.venv/` | 项目内可选的基础 Python、安装时生成的虚拟环境。两者均不入库 |
| `models/` | 安装时下载的 SigLIP 2 和人脸模型，已忽略 |

## 安装

```powershell
pwsh -File .\install.ps1 -Recreate -SkipModels
```

Monarch 依次使用 `backend/.env` 的 `AI_PYTHON`、侧车的 `.venv`、进程 PATH 中的 `python`。重装后可在 Northstar 的「AI 与检索」点「刷新」。`-PipIndex` 可覆盖默认清华镜像，`-HfEndpoint` 可覆盖默认 `hf-mirror.com`。

下载来源：

- SigLIP 2 双塔 ONNX + 分词器 ← HF `onnx-community/siglip2-base-patch16-224-ONNX`（经 hf-mirror）
- buffalo_l 的 `det_10g.onnx` / `w600k_r50.onnx` ← HF `public-data/insightface`（经 hf-mirror）
- PP-OCR 模型 ← **随 rapidocr wheel 一起提供**，无需额外下载

> **向量模型必须支持中文。** SigLIP 1（`Xenova/siglip-base-patch16-224`）的分词器只有
> 3.2 万词表且不含中文，中文查询会整体退化成 `<unk>`——不同查询得到完全相同的向量，
> 语义搜索表面正常但结果全错。SigLIP 2 用 Gemma 的 25.6 万词表多语分词器，与 SigLIP 1
> 结构同构（视觉/文本双塔 + `tokenizer.json`），因此只是换了模型来源。

## 与 Ollama 的关系

`vlm` 能力走 HTTP 调用本机 Ollama，**不在此目录内**：

- 用户已在运行的 Ollama 应用优先复用（本服务不接管、不回收用户的进程）；
- 已配置的 Ollama 不可达时，Monarch 可按需启动 `ollama serve`，由 `OLLAMA_IDLE_TIMEOUT` 和模型保活时间控制回收；
- 自拉的实例必须通过 `OLLAMA_MODELS` 指向用户实际的模型库（Ollama 应用自身设置的
  模型目录不一定在系统环境变量里）。配置见 `backend/.env`；指错目录时任务会失败并
  在错误信息里给出实际使用的目录。
- 每次请求显式下发 `think=false` 与 `num_ctx`（`OLLAMA_VLM_CTX`）：思考型模型
  （qwen3.5 默认开启）会把 `num_predict` 全用在推理上，实测 256 token 耗尽后
  `response` 为空，每张图都会解析失败且慢十倍以上。

## 通信协议（NDJSON）

Go 侧持有 stdin/stdout，逐行收发；stderr 为进度日志，转发到服务日志。

```
→ {"v":1,"capability":"embed","count":2,"params":{"model":"..."}}
→ {"id":"<媒体ID>","path":"<绝对路径>"}
→ {"id":"<媒体ID>","path":"..."}
← {"id":"<媒体ID>","ok":true,"result":{...}}
← {"id":"<媒体ID>","ok":false,"error":"RuntimeError: ..."}
```

`count` 是必需字段：Go 侧写完请求后并不关闭 stdin（要保持进程供后续批次复用），
侧车必须靠计数判断本批读到何处。

`count = 0` 是预热请求，侧车加载该能力的模型后回 `{"ready":true}`。
stdin 关闭则进程退出——空闲回收完全由 Go 侧的进程监管驱动。

## 能力与返回值

| capability | 输入 | result |
| ---------- | ---- | ------ |
| `embed` | 图片路径 | `{"dim":768,"scale":f,"vec":base64(int8)}` |
| `embed_text` | 文本 | 同上（SigLIP 文本塔） |
| `face` | 图片路径 | `{"faces":[{"bbox":[x1,y1,x2,y2],"det":f,"quality":f,"embedding":base64(float32[512])}]}` |
| `ocr` | 图片路径 | `{"text":"...","lines":[{"text":..,"score":..,"box":[[x,y],..]}]}` |

## 依赖探测

```powershell
.\.venv\Scripts\python.exe -m ronin_ai --probe
```

返回已安装的包与已就位的模型，供 Monarch 判断各能力是否就绪。
探测只走 `importlib.util.find_spec` / `importlib.metadata`，不真正导入重模块。

## 说明

- **不依赖 insightface 包**（其 sdist 需要本地 C++ 编译）：人脸检测/识别由
  `faces.py` 直接在 onnxruntime 上实现 SCRFD 后处理与五点对齐 + ArcFace 特征。
- 批处理使用 Monarch 生成的 JPEG。语义向量用 256 预览图，人脸和 OCR 优先用 1024 派生图。
- 图片读取统一走 `image_io.load_bgr`（numpy + `cv2.imdecode`）：Windows 上
  `cv2.imread` 遇到中文路径会直接返回 None，而媒体库里中文文件名非常普遍。
- **推理设备**（`ronin_ai/providers.py`，由 `AI_DEVICE` 控制）：`auto` 时 `face` / `ocr`
  走 DirectML（实测比 CPU 快 63 倍 / 约 1.8 倍），DirectML 未实现的算子自动回退 CPU；
  `cpu` 时全部走 CPU。
  **向量编码（`embed` / `embed_text`）固定 CPU**：DirectML 会让 SigLIP 的输出向量偏移
  （同图余弦中位 0.9898、top-10 近邻重合度降到 80%），而提速只有 1.8 倍——既有
  `ai.embeddings` 会与新的查询向量不在同一空间，检索质量反而下降。若将来改用
  CUDA EP，注意换 EP 同样会改变向量数值，需要重算 `ai.embeddings`。
- 三个引擎的 ONNX 会话按一半逻辑核心数配置线程，上限 8。OCR 的检测边长参数为 320。
- 每个能力一个独立进程，模型按需加载；空闲退出由 Go 侧 `AI_IDLE_TIMEOUT` 控制，
  退出即释放全部内存。
