"""SigLIP 图像/文本向量编码（ONNX Runtime）。

产出与 Go 侧约定一致：L2 归一化后按 per-vector 最大绝对值量化为 int8，
返回 {"dim", "scale", "vec"(base64)}。Go 侧存入 ai.embeddings.vec。
"""

from __future__ import annotations

import base64
import json
import os
from pathlib import Path
from typing import Any, Dict, List

import numpy as np

from .paths import siglip_dir
from .protocol import log

VISION_FILE = "vision_model_quantized.onnx"
TEXT_FILE = "text_model_quantized.onnx"
TOKENIZER_FILE = "tokenizer.json"
PREPROCESSOR_FILE = "preprocessor_config.json"

DEFAULT_MAX_LENGTH = 64
DEFAULT_IMAGE_SIZE = 224


class SiglipEmbedder:
    """SigLIP 双塔编码器（视觉塔 + 文本塔），按需加载。"""

    def __init__(self) -> None:
        self._vision = None
        self._text = None
        self._tokenizer = None
        self._device = "auto"
        self._image_size = DEFAULT_IMAGE_SIZE
        self._mean = 0.5
        self._std = 0.5
        self._max_length = DEFAULT_MAX_LENGTH

    # ---------- 加载 ----------

    def ensure_loaded(self, params: Dict[str, Any] | None = None) -> None:
        self._device = str((params or {}).get("device", "auto"))
        if self._vision is None:
            self._load_vision()
        if self._text is None:
            self._load_text()

    def loaded_models(self) -> List[str]:
        names = []
        if self._vision is not None:
            names.append("siglip_vision")
        if self._text is not None:
            names.append("siglip_text")
        if self._tokenizer is not None:
            names.append("siglip_tokenizer")
        return names

    def _session(self, path: Path):
        import onnxruntime as ort

        from .providers import providers_for
        from .threads import intra_op_threads

        options = ort.SessionOptions()
        options.intra_op_num_threads = intra_op_threads()
        options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        # 向量编码固定 CPU：切 DirectML 会让向量空间偏移，详见 providers.py
        chosen = providers_for("embed", self._device)
        log(f"加载 ONNX 模型: {path.name}（{chosen[0]}）")
        return ort.InferenceSession(str(path), sess_options=options, providers=chosen)

    def _load_vision(self) -> None:
        directory = siglip_dir()
        path = directory / VISION_FILE
        if not path.is_file():
            raise FileNotFoundError(f"缺少模型文件 {path}（运行 tools/ai/install.ps1）")
        self._vision = self._session(path)
        self._read_preprocessor(directory)

    def _load_text(self) -> None:
        from tokenizers import Tokenizer

        directory = siglip_dir()
        model_path = directory / TEXT_FILE
        tokenizer_path = directory / TOKENIZER_FILE
        if not model_path.is_file():
            raise FileNotFoundError(f"缺少模型文件 {model_path}（运行 tools/ai/install.ps1）")
        if not tokenizer_path.is_file():
            raise FileNotFoundError(f"缺少分词器 {tokenizer_path}（运行 tools/ai/install.ps1）")

        self._text = self._session(model_path)
        tokenizer = Tokenizer.from_file(str(tokenizer_path))
        tokenizer.enable_truncation(max_length=self._max_length)
        tokenizer.enable_padding(length=self._max_length)
        self._tokenizer = tokenizer
        log("分词器已就绪")

    def _read_preprocessor(self, directory: Path) -> None:
        """读取官方预处理参数（尺寸/均值/方差），缺失时退回 SigLIP 默认值。"""
        path = directory / PREPROCESSOR_FILE
        if not path.is_file():
            return
        try:
            config = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            return
        size = config.get("size") or {}
        if isinstance(size, dict) and size.get("height"):
            self._image_size = int(size["height"])
        if config.get("image_mean"):
            self._mean = float(config["image_mean"][0])
        if config.get("image_std"):
            self._std = float(config["image_std"][0])
        if config.get("model_max_length"):
            self._max_length = int(config["model_max_length"])

    # ---------- 推理 ----------

    def embed_image(self, path: str) -> Dict[str, Any]:
        session = self._vision
        if session is None:
            raise RuntimeError("视觉塔尚未加载")
        pixels = self._preprocess(path)
        inputs = {session.get_inputs()[0].name: pixels}
        outputs = session.run(None, inputs)
        vector = _pick_embedding(session, outputs)
        return _quantize(vector)

    def embed_text(self, text: str) -> Dict[str, Any]:
        session = self._text
        if session is None or self._tokenizer is None:
            raise RuntimeError("文本塔尚未加载")

        encoding = self._tokenizer.encode(text or "")
        input_ids = np.asarray([encoding.ids], dtype=np.int64)
        attention_mask = np.asarray([encoding.attention_mask], dtype=np.int64)

        available = {item.name for item in session.get_inputs()}
        inputs: Dict[str, Any] = {}
        if "input_ids" in available:
            inputs["input_ids"] = input_ids
        if "attention_mask" in available:
            inputs["attention_mask"] = attention_mask
        if "token_type_ids" in available:
            inputs["token_type_ids"] = np.zeros_like(input_ids)
        if not inputs:
            inputs[session.get_inputs()[0].name] = input_ids

        outputs = session.run(None, inputs)
        vector = _pick_embedding(session, outputs)
        return _quantize(vector)

    def _preprocess(self, path: str) -> np.ndarray:
        from PIL import Image

        size = self._image_size
        with Image.open(path) as image:
            image = image.convert("RGB")
            image = image.resize((size, size), Image.BICUBIC)
            array = np.asarray(image, dtype=np.float32) / 255.0

        array = (array - self._mean) / self._std
        array = np.transpose(array, (2, 0, 1))  # HWC → CHW
        return np.ascontiguousarray(array[None, ...], dtype=np.float32)


def _pick_embedding(session, outputs) -> np.ndarray:
    """从模型输出中挑出池化后的句/图向量。"""
    preferred = ("pooler_output", "image_embeds", "text_embeds", "embeddings")
    for index, meta in enumerate(session.get_outputs()):
        if any(key in meta.name for key in preferred):
            array = np.asarray(outputs[index])
            if array.ndim >= 2:
                return array.reshape(-1, array.shape[-1])[0]

    # 退化路径：取秩为 2 的输出；否则对最后一维做平均池化
    for array in outputs:
        array = np.asarray(array)
        if array.ndim == 2:
            return array[0]
    array = np.asarray(outputs[-1])
    if array.ndim == 3:
        return array[0].mean(axis=0)
    raise RuntimeError("无法从模型输出中解析向量")


def _quantize(vector: np.ndarray) -> Dict[str, Any]:
    """L2 归一化 → per-vector 最大绝对值量化 → base64 int8。"""
    vector = np.asarray(vector, dtype=np.float32).reshape(-1)
    norm = float(np.linalg.norm(vector))
    if norm > 0:
        vector = vector / norm

    max_abs = float(np.max(np.abs(vector))) if vector.size else 0.0
    scale = (max_abs / 127.0) if max_abs > 0 else 1.0
    quantized = np.clip(np.round(vector / scale), -127, 127).astype(np.int8)

    return {
        "dim": int(quantized.size),
        "scale": float(scale),
        "vec": base64.b64encode(quantized.tobytes()).decode("ascii"),
    }


_embedder: SiglipEmbedder | None = None


def get_embedder() -> SiglipEmbedder:
    global _embedder
    if _embedder is None:
        _embedder = SiglipEmbedder()
    return _embedder
