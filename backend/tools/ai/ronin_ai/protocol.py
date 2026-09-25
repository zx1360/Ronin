"""NDJSON 协议主循环与能力分发。"""

from __future__ import annotations

import json
import os
import sys
import traceback
from typing import Any, Dict, List

from .paths import siglip_dir
from .probe import run_probe

PROTOCOL_VERSION = 1


def emit(payload: Dict[str, Any]) -> None:
    """向 stdout 写一行 JSON 并立即刷新（Go 侧按行阻塞读取）。"""
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))
    sys.stdout.write("\n")
    sys.stdout.flush()


def log(message: str) -> None:
    """进度与诊断信息走 stderr，由 Go 侧转发到服务日志。"""
    sys.stderr.write(message + "\n")
    sys.stderr.flush()


def _handler_for(capability: str):
    """按能力懒加载对应处理器（导入即拉起 onnxruntime，故延迟到此处）。"""
    if capability == "embed":
        from .embedder import get_embedder
        return get_embedder()
    if capability == "embed_text":
        from .embedder import get_embedder
        return get_embedder()
    if capability == "face":
        from .faces import get_face_engine
        return get_face_engine()
    if capability == "ocr":
        from .ocr import get_ocr_engine
        return get_ocr_engine()
    raise ValueError(f"未知能力: {capability}")


def _process(handler, capability: str, item: Dict[str, Any], params: Dict[str, Any]) -> Dict[str, Any]:
    if capability == "embed":
        return handler.embed_image(item["path"])
    if capability == "embed_text":
        return handler.embed_text(item.get("text", ""))
    if capability == "face":
        return handler.detect(item["path"], params)
    if capability == "ocr":
        return handler.recognize(item["path"])
    raise ValueError(f"未知能力: {capability}")


def _read_header(stream) -> Dict[str, Any] | None:
    """读取一行并解析为请求头；EOF 返回 None。"""
    while True:
        line = stream.readline()
        if not line:
            return None
        line = line.strip()
        if line:
            return json.loads(line)


def run_loop() -> int:
    """主循环：逐个批次处理，直到 stdin 关闭。"""
    stream = sys.stdin
    try:
        while True:
            header = _read_header(stream)
            if header is None:
                return 0  # stdin 关闭 → 正常退出（Go 侧的空闲回收路径）

            version = int(header.get("v", 0))
            if version != PROTOCOL_VERSION:
                log(f"协议版本不匹配: 期望 {PROTOCOL_VERSION}，收到 {version}")
                return 2

            capability = str(header.get("capability", ""))
            params = header.get("params") or {}
            count = int(header.get("count", 0))

            items: List[Dict[str, Any]] = []
            for _ in range(count):
                line = stream.readline()
                if not line:
                    return 0
                line = line.strip()
                if line:
                    items.append(json.loads(line))

            try:
                handler = _handler_for(capability)
                handler.ensure_loaded(params)
                handler_params = params or {}
                if count == 0:
                    # count=0 为预热请求：加载完成即回报就绪
                    emit({"ready": True, "models": handler.loaded_models()})
                    continue
                for item in items:
                    emit(_process_one(handler, capability, item, handler_params))
            except Exception as exc:  # 加载失败等：整批回报错误，由 Go 侧重试
                log(f"批次处理失败: {exc}")
                log(traceback.format_exc())
                if count == 0:
                    emit({"ready": False, "error": f"{type(exc).__name__}: {exc}"})
                    continue
                for item in items:
                    emit({"id": item.get("id"), "ok": False,
                          "error": f"{type(exc).__name__}: {exc}"})
    except KeyboardInterrupt:
        return 0
    except BrokenPipeError:
        return 0


def _process_one(handler, capability: str, item: Dict[str, Any], params: Dict[str, Any]) -> Dict[str, Any]:
    """处理单条并包成响应；单条失败不影响同批其它条目。"""
    item_id = item.get("id")
    try:
        result = _process(handler, capability, item, params)
        return {"id": item_id, "ok": True, "result": result}
    except Exception as exc:
        # 逐条失败也要留完整堆栈：Go 侧只回报一行错误信息，排查依赖这里的日志
        log(f"{capability} 处理 {item_id} 失败: {exc}")
        log(traceback.format_exc())
        return {"id": item_id, "ok": False, "error": f"{type(exc).__name__}: {exc}"}


def main(argv: List[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if "--probe" in argv:
        emit(run_probe())
        return 0
    if "--models-dir" in argv:
        emit({"models_dir": str(siglip_dir())})
        return 0
    os.environ.setdefault("OMP_NUM_THREADS", str(max(1, (os.cpu_count() or 4) // 2)))
    return run_loop()
