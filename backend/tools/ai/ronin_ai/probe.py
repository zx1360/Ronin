"""依赖探测：报告 python 包与模型文件是否就位。

刻意只使用 importlib.util.find_spec / importlib.metadata，
不真正导入 onnxruntime、opencv 等重模块，因此探测本身是亚秒级的。
"""

from __future__ import annotations

import importlib.metadata
import importlib.util
from typing import Any, Dict

from .paths import models_dir, siglip_dir

# Go 侧按这些 key 判断各能力是否可用（见 backend/internal/service/ai/status.go）
PACKAGE_KEYS = [
    ("onnxruntime", "onnxruntime"),
    ("numpy", "numpy"),
    ("PIL", "Pillow"),
    ("tokenizers", "tokenizers"),
    ("cv2", "opencv-python"),
    ("rapidocr", "rapidocr"),
]

SIGLIP_MODELS = {
    "siglip_vision": "vision_model_quantized.onnx",
    "siglip_text": "text_model_quantized.onnx",
    "siglip_tokenizer": "tokenizer.json",
}


def _package_version(dist_name: str) -> str:
    try:
        return importlib.metadata.version(dist_name)
    except importlib.metadata.PackageNotFoundError:
        return "installed"
    except Exception:
        return "unknown"


def collect_packages() -> Dict[str, str]:
    packages: Dict[str, str] = {}
    for module_name, dist_name in PACKAGE_KEYS:
        if importlib.util.find_spec(module_name) is None:
            continue
        packages[module_name] = _package_version(dist_name)
    return packages


def collect_models() -> Dict[str, bool]:
    models: Dict[str, bool] = {}
    directory = siglip_dir()
    for key, filename in SIGLIP_MODELS.items():
        models[key] = (directory / filename).is_file()

    buffalo = models_dir() / "buffalo_l"
    models["face_buffalo_l"] = (
        (buffalo / "det_10g.onnx").is_file() and (buffalo / "w600k_r50.onnx").is_file()
    )
    return models


def run_probe() -> Dict[str, Any]:
    return {
        "ok": True,
        "packages": collect_packages(),
        "models": collect_models(),
    }
