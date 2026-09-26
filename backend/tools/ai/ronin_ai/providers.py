"""ONNX Runtime 执行提供者（EP）选择。

DirectML 在部分算子上走低精度路径，对本项目三个模型的影响实测差异极大：

  - face：ArcFace 输出与 CPU 逐位一致（余弦 1.00000000），SCRFD 各输出最大差 3.6e-6；
  - ocr：4 个真实样本文本逐字相同；
  - embed：SigLIP 视觉塔向量明显偏移（同图余弦中位 0.9898，top-10 近邻重合度仅 80%），
    而提速只有 1.8 倍——既破坏既有向量空间又降低检索质量，不值得。

因此只给人脸与 OCR 开 GPU（实测提速 63 倍 / 约 1.8 倍）。若将来换 CUDA EP，
这里换掉 provider 名即可，但换 EP 会改变向量数值，需要重算 ai.embeddings。
"""

from __future__ import annotations

CPU = "CPUExecutionProvider"
DIRECTML = "DmlExecutionProvider"

# 允许使用 GPU 的能力；其余一律 CPU。
GPU_CAPABILITIES = frozenset({"face", "ocr"})


def use_gpu(capability: str, device: str) -> bool:
    """该能力在当前 device 设置下是否应使用 GPU。"""
    if (device or "").strip().lower() == "cpu":
        return False
    if capability not in GPU_CAPABILITIES:
        return False
    import onnxruntime as ort

    return DIRECTML in ort.get_available_providers()


def providers_for(capability: str, device: str) -> list[str]:
    """该能力的 session provider 列表；CPU 始终兜底，DirectML 未支持的算子自动回退。"""
    return [DIRECTML, CPU] if use_gpu(capability, device) else [CPU]
