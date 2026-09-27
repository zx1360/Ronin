"""OCR 文字识别（RapidOCR，PP-OCR ONNX 模型）。

模型在首次使用时由 rapidocr 自动从 ModelScope 下载到用户缓存目录；
安装脚本会预热一次，避免第一次处理任务时卡在下载上。

返回 {"text": 合并文本}。text 为空串表示"已识别但无文字"，
与"尚未处理"（无记录）区分开。
"""

from __future__ import annotations

from typing import Any, Dict, List

from .protocol import log

# 低于该置信度的识别结果直接丢弃，避免噪声污染检索
MIN_SCORE = 0.5

# 检测网络的输入边长上限。
#
# 侧车喂的是长边 1024 的 AI 派生档（见 backend/internal/service/ai/tier.go），
# 上限必须与之匹配：再往下限到几百像素等于把档位升级的收益又丢回去。
# rapidocr 默认 736 比这更小，因此这里取 1024 就够，不必再放大。
OCR_DET_SIDE_LIMIT = 1024


class OcrEngine:
    def __init__(self) -> None:
        self._engine = None

    def ensure_loaded(self, params: Dict[str, Any] | None = None) -> None:
        if self._engine is not None:
            return
        from rapidocr import RapidOCR

        from .providers import use_gpu as use_gpu_provider
        from .threads import intra_op_threads

        settings: Dict[str, Any] = {
            "Det.limit_side_len": OCR_DET_SIDE_LIMIT,
            # 默认 -1 会吃满所有核心，长时间批量识别会明显影响日常使用
            "EngineConfig.onnxruntime.intra_op_num_threads": intra_op_threads(),
        }
        # rapidocr 自己拼 provider 列表：开了 use_dml 仍是 DML 优先、CPU 兜底
        use_gpu = use_gpu_provider("ocr", str((params or {}).get("device", "auto")))
        if use_gpu:
            settings["EngineConfig.onnxruntime.use_dml"] = True

        log(f"加载 RapidOCR（PP-OCR ONNX，{'DmlExecutionProvider' if use_gpu else 'CPUExecutionProvider'}）")
        self._engine = RapidOCR(params=settings)

    def loaded_models(self) -> List[str]:
        return ["rapidocr_ppocr"] if self._engine is not None else []

    def recognize(self, path: str) -> Dict[str, Any]:
        if self._engine is None:
            raise RuntimeError("OCR 模型尚未加载")

        # 自己读图后传 ndarray：rapidocr 内部用 cv2.imread，中文路径会读成 None
        from .image_io import load_bgr

        image = load_bgr(path)
        if image is None:
            raise ValueError("无法解码图片")

        return {"text": "\n".join(_texts(self._engine(image)))}


def _texts(raw: Any) -> List[str]:
    """取出通过置信度阈值的文本行（兼容 rapidocr 3.x 输出对象与旧版元组）。"""
    texts, scores = _extract(raw)
    out: List[str] = []
    for index, text in enumerate(texts):
        text = str(text).strip()
        score = _as_float(scores[index]) if index < len(scores) else 0.0
        if text and score >= MIN_SCORE:
            out.append(text)
    return out


def _extract(raw: Any):
    """统一取出 (texts, scores) 两个序列。

    注意：这些字段可能是 numpy 数组，绝不能写 `value or []`
    （数组的真值判断会抛 ValueError），只能显式判 None。
    """
    # rapidocr 3.x：RapidOCROutput 带 txts / scores 属性
    for attr in ("txts", "texts"):
        if hasattr(raw, attr):
            return _as_list(getattr(raw, attr)), _as_list(getattr(raw, "scores", None))

    # 旧版：([box, text, score], ...) 列表，可能包在 (result, elapse) 里
    result = raw[0] if isinstance(raw, tuple) else raw
    if result is None:
        return [], []

    texts, scores = [], []
    for entry in result:
        if not isinstance(entry, (list, tuple)) or len(entry) < 3:
            continue
        texts.append(entry[1])
        scores.append(entry[2])
    return texts, scores


def _as_list(value: Any) -> List[Any]:
    """把 None / ndarray / list 统一成 list。"""
    if value is None:
        return []
    if isinstance(value, list):
        return value
    try:
        return list(value)
    except TypeError:
        return [value]


def _as_float(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


_engine: OcrEngine | None = None


def get_ocr_engine() -> OcrEngine:
    global _engine
    if _engine is None:
        _engine = OcrEngine()
    return _engine
