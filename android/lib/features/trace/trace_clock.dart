import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:torrid/core/services/storage/app_database.dart';

class TraceClock {
  const TraceClock({required this.wallMs, this.bootKey, this.elapsedMs});

  static const _channel = MethodChannel('torrid/trace_clock');

  final int wallMs;
  final String? bootKey;
  final int? elapsedMs;

  static Future<TraceClock> read() async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>('read');
      if (value != null) {
        return TraceClock(
          wallMs: value['wallMs'] as int,
          bootKey: value['bootKey'] as String?,
          elapsedMs: value['elapsedMs'] as int,
        );
      }
    } on MissingPluginException {
      // 非 Android 测试环境使用墙钟。
    } on PlatformException {
      // 原生时钟不可读时仍允许确认和修正记录。
    }
    return TraceClock(wallMs: DateTime.now().millisecondsSinceEpoch);
  }

  bool matches(TraceSession session) =>
      bootKey != null &&
      bootKey == session.bootKey &&
      elapsedMs != null &&
      session.anchorElapsedMs != null &&
      elapsedMs! >= session.anchorElapsedMs!;

  int durationMs(TraceSession session) {
    if (matches(session)) {
      return (session.anchorDurationMs ?? 0) +
          elapsedMs! -
          session.anchorElapsedMs!;
    }
    return math.max(session.anchorDurationMs ?? 0, wallMs - session.startedMs);
  }
}
