"""侧车目录解析：模型与依赖统一放在 tools/ai 下，便于整体删除与迁移。

目录布局：
    tools/ai/.venv/                独立虚拟环境（可整个删除回滚）
    tools/ai/models/siglip/        SigLIP 双塔 ONNX + 分词器
    tools/ai/models/buffalo_l/     InsightFace 检测/识别模型
"""

from __future__ import annotations

from pathlib import Path

# ronin_ai 包所在目录的上一级即侧车根目录（tools/ai）
PACKAGE_DIR = Path(__file__).resolve().parent
ROOT_DIR = PACKAGE_DIR.parent


def models_dir() -> Path:
    """模型根目录。"""
    base = ROOT_DIR / "models"
    base.mkdir(parents=True, exist_ok=True)
    return base


def siglip_dir() -> Path:
    """SigLIP 模型目录。"""
    base = models_dir() / "siglip"
    base.mkdir(parents=True, exist_ok=True)
    return base


def insightface_root() -> Path:
    """insightface 的 root 参数。

    insightface 会在 <root>/models/<name> 下查找模型，因此 root 取 tools/ai，
    实际模型位于 tools/ai/models/buffalo_l。
    """
    return ROOT_DIR
