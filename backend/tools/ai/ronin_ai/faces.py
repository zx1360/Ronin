"""人脸检测与特征提取：SCRFD(det_10g) + ArcFace(w600k_r50)，纯 onnxruntime 实现。

不依赖 insightface 包（其 sdist 需要本地 C++ 编译），只使用 buffalo_l 里
两个 ONNX 文件，配合 numpy/opencv 完成检测后处理与五点对齐。

坐标系约定：检测框按原图宽高归一化为 [x1,y1,x2,y2]；特征为 512 维 L2 归一化
float32，base64 编码后交给 Go 侧落库 ai.faces。
"""

from __future__ import annotations

import base64
import math
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

from .paths import models_dir
from .protocol import log

DET_FILE = "det_10g.onnx"
REC_FILE = "w600k_r50.onnx"

# ArcFace 官方 112×112 五点模板
ARCFACE_DST = np.array(
    [
        [38.2946, 51.6963],
        [73.5318, 51.5014],
        [56.0252, 71.7366],
        [41.5493, 92.3655],
        [70.7299, 92.2041],
    ],
    dtype=np.float32,
)

DET_SIZE = 640
DET_THRESHOLD = 0.5
NMS_THRESHOLD = 0.4
# 过小的人脸对分组没有价值，且容易拉低聚类质量
MIN_FACE_SIDE = 16.0


class FaceEngine:
    """人脸检测 + 特征提取引擎（懒加载两个 ONNX 会话）。"""

    def __init__(self) -> None:
        self._det = None
        self._rec = None
        self._det_input: Optional[str] = None
        self._self_checked = False

    # ---------- 加载 ----------

    def ensure_loaded(self, params: Dict[str, Any] | None = None) -> None:
        if self._det is not None and self._rec is not None:
            return

        directory = models_dir() / "buffalo_l"
        det_path = directory / DET_FILE
        rec_path = directory / REC_FILE
        for path in (det_path, rec_path):
            if not path.is_file():
                raise FileNotFoundError(f"缺少模型文件 {path}（运行 tools/ai/install.ps1）")

        import onnxruntime as ort

        from .providers import providers_for
        from .threads import intra_op_threads

        options = ort.SessionOptions()
        options.intra_op_num_threads = intra_op_threads()
        options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        chosen = providers_for("face", str((params or {}).get("device", "auto")))

        log(f"加载 SCRFD 检测模型: {det_path.name}（{chosen[0]}）")
        self._det = ort.InferenceSession(str(det_path), sess_options=options, providers=chosen)
        self._det_input = self._det.get_inputs()[0].name

        log(f"加载 ArcFace 识别模型: {rec_path.name}（{chosen[0]}）")
        self._rec = ort.InferenceSession(str(rec_path), sess_options=options, providers=chosen)

    def loaded_models(self) -> List[str]:
        return ["face_buffalo_l"] if (self._det is not None and self._rec is not None) else []

    # ---------- 推理 ----------

    def detect(self, path: str, params: Dict[str, Any] | None = None) -> Dict[str, Any]:
        if self._det is None or self._rec is None:
            raise RuntimeError("人脸模型尚未加载")

        from .image_io import load_bgr

        image = load_bgr(path)
        if image is None:
            raise ValueError("无法解码图片")
        height, width = image.shape[:2]
        if height == 0 or width == 0:
            raise ValueError("图片尺寸非法")

        boxes, keypoints, scores = self._detect_faces(image)

        payload: List[Dict[str, Any]] = []
        for box, kps, score in zip(boxes, keypoints, scores):
            side = math.sqrt(max(0.0, (box[2] - box[0]) * (box[3] - box[1])))
            if side < MIN_FACE_SIDE:
                continue
            embedding = self._extract(image, kps)
            if embedding is None:
                continue

            normalised = [
                float(np.clip(box[0] / width, 0.0, 1.0)),
                float(np.clip(box[1] / height, 0.0, 1.0)),
                float(np.clip(box[2] / width, 0.0, 1.0)),
                float(np.clip(box[3] / height, 0.0, 1.0)),
            ]
            det_score = float(score)
            payload.append({
                "bbox": normalised,
                "det": det_score,
                # 与 Go 侧 faceQuality 同口径：检测分 × 归一化人脸边长权重
                "quality": det_score * min(1.0, (side / max(height, width)) * 2),
                "embedding": base64.b64encode(embedding.tobytes()).decode("ascii"),
            })

        return {"faces": payload}

    def _detect_faces(self, image: np.ndarray) -> Tuple[List[np.ndarray], List[np.ndarray], List[float]]:
        """SCRFD 前向 + 解码 + NMS，返回原图坐标系下的框与关键点。"""
        import cv2

        blob, det_scale = self._preprocess(image)
        outputs = self._det.run(None, {self._det_input: blob})

        width, height = self._det_size()
        heads = _group_heads(outputs, width, height)
        if not heads:
            # 输出结构不符合预期时不要静默返回"没有脸"，那与"识别不出脸"无法区分
            raise RuntimeError(
                f"SCRFD 输出结构异常，无法解析检测头（输出数={len(outputs)}，"
                f"形状={[np.asarray(o).shape for o in outputs]}）"
            )

        all_boxes: List[np.ndarray] = []
        all_kps: List[np.ndarray] = []
        all_scores: List[float] = []
        top_score = 0.0

        for stride, head in sorted(heads.items()):
            score = head["score"].reshape(-1)
            top_score = max(top_score, float(score.max()) if score.size else 0.0)
            positive = np.where(score >= DET_THRESHOLD)[0]
            if positive.size == 0:
                continue

            centres = _anchor_centers(head["spatial"], stride)
            bbox = head["bbox"].reshape(-1, 4)[positive] * stride
            kps = head["kps"].reshape(-1, 10)[positive] * stride

            boxes = _distance2bbox(centres[positive], bbox)
            points = _distance2kps(centres[positive], kps)

            all_boxes.append(boxes)
            all_kps.append(points)
            all_scores.extend(score[positive].tolist())

        if not all_boxes:
            if not self._self_checked:
                self._self_checked = True
                log(f"SCRFD 自检: 最高检测分 {top_score:.3f}（阈值 {DET_THRESHOLD}），本图未检出人脸")
            return [], [], []

        # 首次推理打印一次最高分：检测头解析失效时"没有脸"与"识别不出脸"无法区分，
        # 这条日志能让静默失效立刻暴露出来。
        if not self._self_checked:
            self._self_checked = True
            candidates = sum(len(b) for b in all_boxes)
            log(f"SCRFD 自检: 最高检测分 {top_score:.3f}（阈值 {DET_THRESHOLD}），候选 {candidates} 个")

        boxes = np.vstack(all_boxes) / det_scale
        points = np.vstack(all_kps) / det_scale
        scores = np.asarray(all_scores, dtype=np.float32)

        keep = _nms(boxes, scores, NMS_THRESHOLD)
        return boxes[keep], points[keep], scores[keep].tolist()

    def _det_size(self) -> Tuple[int, int]:
        shape = self._det.get_inputs()[0].shape
        height = shape[2] if isinstance(shape[2], int) and shape[2] > 0 else DET_SIZE
        width = shape[3] if isinstance(shape[3], int) and shape[3] > 0 else DET_SIZE
        return width, height

    def _preprocess(self, image: np.ndarray) -> Tuple[np.ndarray, float]:
        """等比缩放并左上角贴到 DET_SIZE 画布，返回 blob 与缩放比例。"""
        import cv2

        width, height = self._det_size()
        image_ratio = image.shape[0] / image.shape[1]
        model_ratio = height / width
        if image_ratio > model_ratio:
            new_height = height
            new_width = int(new_height / image_ratio)
        else:
            new_width = width
            new_height = int(new_width * image_ratio)

        det_scale = new_height / image.shape[0]
        resized = cv2.resize(image, (new_width, new_height))
        canvas = np.zeros((height, width, 3), dtype=np.uint8)
        canvas[:new_height, :new_width, :] = resized

        blob = cv2.dnn.blobFromImage(canvas, 1.0 / 128, (width, height),
                                     (127.5, 127.5, 127.5), swapRB=True)
        return blob, det_scale

    def _extract(self, image: np.ndarray, keypoints: np.ndarray) -> Optional[np.ndarray]:
        """五点相似变换对齐到 112×112 后提取 512 维归一化特征。"""
        import cv2

        transform, _ = cv2.estimateAffinePartial2D(
            keypoints.reshape(5, 2).astype(np.float32), ARCFACE_DST, method=cv2.LMEDS
        )
        if transform is None:
            return None

        aligned = cv2.warpAffine(image, transform, (112, 112), borderValue=0.0)
        blob = cv2.dnn.blobFromImage(aligned, 1.0 / 127.5, (112, 112),
                                     (127.5, 127.5, 127.5), swapRB=True)
        feature = np.asarray(self._rec.run(None, {self._rec.get_inputs()[0].name: blob})[0])
        feature = feature.reshape(-1).astype(np.float32)
        if feature.size != 512:
            return None

        norm = float(np.linalg.norm(feature))
        return feature / norm if norm > 0 else None


def _group_heads(outputs: List[np.ndarray], width: int, height: int) -> Dict[int, Dict[str, Any]]:
    """按输出通道数（1/4/10）与锚点数量把各输出归类到对应 stride。

    det_10g.onnx 的输出是二维 (N, C)（无 batch 维）；这里同时兼容 (1, N, C)，
    并且不依赖输出排列顺序，比按索引取更稳健。
    """
    heads: Dict[int, Dict[str, Any]] = {}
    for raw in outputs:
        array = np.asarray(raw)
        if array.ndim == 3:
            array = array.reshape(-1, array.shape[-1])
        if array.ndim != 2:
            continue

        anchors, channels = array.shape
        kind = {1: "score", 4: "bbox", 10: "kps"}.get(channels)
        if kind is None:
            continue

        num_anchors = 2
        spatial = math.isqrt(max(1, anchors // num_anchors))
        if spatial * spatial * num_anchors != anchors:
            continue
        if width % spatial != 0 or height % spatial != 0:
            continue
        stride = width // spatial

        head = heads.setdefault(stride, {})
        head["spatial"] = spatial
        head[kind] = array

    # 三个 head 都齐备才可用
    return {
        stride: head
        for stride, head in heads.items()
        if all(key in head for key in ("score", "bbox", "kps"))
    }


def _anchor_centers(spatial: int, stride: int) -> np.ndarray:
    """SCRFD 锚点中心（num_anchors=2，每个位置连续重复两次）。"""
    grid = np.stack(np.mgrid[:spatial, :spatial][::-1], axis=-1).astype(np.float32)
    centers = (grid * stride).reshape(-1, 2)
    return np.stack([centers] * 2, axis=1).reshape(-1, 2)


def _distance2bbox(points: np.ndarray, distance: np.ndarray) -> np.ndarray:
    x1 = points[:, 0] - distance[:, 0]
    y1 = points[:, 1] - distance[:, 1]
    x2 = points[:, 0] + distance[:, 2]
    y2 = points[:, 1] + distance[:, 3]
    return np.stack([x1, y1, x2, y2], axis=-1)


def _distance2kps(points: np.ndarray, distance: np.ndarray) -> np.ndarray:
    predictions = []
    for i in range(0, distance.shape[1], 2):
        predictions.append(points[:, 0] + distance[:, i])
        predictions.append(points[:, 1] + distance[:, i + 1])
    return np.stack(predictions, axis=-1)


def _nms(boxes: np.ndarray, scores: np.ndarray, threshold: float) -> np.ndarray:
    """标准 IoU 非极大值抑制，返回保留下标。"""
    if boxes.shape[0] == 0:
        return np.empty((0,), dtype=np.int64)

    x1, y1, x2, y2 = boxes[:, 0], boxes[:, 1], boxes[:, 2], boxes[:, 3]
    areas = np.maximum(0.0, x2 - x1) * np.maximum(0.0, y2 - y1)
    order = scores.argsort()[::-1]

    keep: List[int] = []
    while order.size > 0:
        index = int(order[0])
        keep.append(index)
        if order.size == 1:
            break

        rest = order[1:]
        inter_x1 = np.maximum(x1[index], x1[rest])
        inter_y1 = np.maximum(y1[index], y1[rest])
        inter_x2 = np.minimum(x2[index], x2[rest])
        inter_y2 = np.minimum(y2[index], y2[rest])
        inter = np.maximum(0.0, inter_x2 - inter_x1) * np.maximum(0.0, inter_y2 - inter_y1)

        union = areas[index] + areas[rest] - inter
        iou = np.where(union > 0, inter / np.maximum(union, 1e-9), 0.0)
        order = rest[iou <= threshold]

    return np.asarray(keep, dtype=np.int64)


_engine: FaceEngine | None = None


def get_face_engine() -> FaceEngine:
    global _engine
    if _engine is None:
        _engine = FaceEngine()
    return _engine
