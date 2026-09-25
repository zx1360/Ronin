# Ronin AI 侧车（tools/ai）

给 Monarch 提供本地 AI 推理的 Python 进程，**用时启动、空闲退出**，
不常驻占用内存。全部产物都在本目录内，删掉即可完全回滚。

## 组成

| 路径 | 说明 |
| ---- | ---- |
| `ronin_ai/` | 侧车源码（协议循环 + 三个能力实现） |
| `requirements.txt` | python 依赖（onnxruntime / numpy / opencv / tokenizers / rapidocr） |
| `install.ps1` | 一键创建 venv、安装依赖、下载模型 |
| `.venv/` | 虚拟环境（install.ps1 生成，已 gitignore） |
| `models/` | 模型文件（install.ps1 生成，已 gitignore） |

## 安装

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

可选参数：`-SkipModels`（只装 python 依赖）、`-Recreate`（重建 venv）、
`-PipIndex`（pip 镜像，默认清华——直连 pypi.org 在本机实测只有 ~40KB/s）、
`-HfEndpoint`（HuggingFace 镜像，默认 `hf-mirror.com`）。

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
- 只有 11434 无人监听时，本服务才自拉 `ollama serve`，空闲 `AI_IDLE_TIMEOUT` 后回收；
- 自拉的实例必须通过 `OLLAMA_MODELS` 指向用户实际的模型库（Ollama 应用自身设置的
  模型目录不一定在系统环境变量里）。配置见 `backend/.env`；指错目录时任务会失败并
  在错误信息里给出实际使用的目录。

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
- 输入一律使用 Monarch 生成的**预览图**（统一 JPEG、边长 256），避免读取 GB 级原图，
  也回避 HEIC/WebP 等格式在侧车里额外解码。
- 图片读取统一走 `image_io.load_bgr`（numpy + `cv2.imdecode`）：Windows 上
  `cv2.imread` 遇到中文路径会直接返回 None，而媒体库里中文文件名非常普遍。
- **CPU 占用**：三个引擎统一只使用一半核心（`threads.intra_op_threads`，上限 8），
  长时间批量处理时给日常使用留出余量。OCR 的检测输入边长限制为 320——预览图本身
  只有 256px，rapidocr 默认放大到 736 既费时又不提升识别率（实测 4.92s/张→2.72s/张，
  识别行数反而更多）。
- 每个能力一个独立进程，模型按需加载；空闲退出由 Go 侧 `AI_IDLE_TIMEOUT` 控制，
  退出即释放全部内存。
