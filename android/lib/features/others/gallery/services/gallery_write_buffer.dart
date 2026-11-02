import 'dart:async';

import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';

/// 本地事务提交后顺序回传；确认过的记录保留到批次校验和清理完成。
class GalleryWriteBuffer {
  GalleryWriteBuffer({
    required this.db,
    required this.server,
    required this.send,
    required this.verify,
    this.onChanged,
  }) {
    retry();
  }

  final GalleryDatabaseService db;
  final String Function() server;
  final Future<void> Function(GalleryOperation) send;
  final Future<void> Function(List<GalleryOperation>) verify;
  final void Function()? onChanged;
  Future<void> _localWrites = Future.value();
  Future<bool>? _sending;
  Timer? _timer;
  bool _disposed = false;
  bool _locked = false;
  int _attempt = 0;
  Object? lastError;

  Future<void> queueTags(String id, List<String> tags) =>
      queue('tags', {'media_id': id, 'tag_ids': tags.toSet().toList()});

  Future<void> queuePatch(List<String> ids, MediaPatchIntent patch) =>
      queue('patch', patch.toBody(ids));

  Future<void> queue(String kind, Map<String, dynamic> body) {
    if (_locked || _disposed) return Future.error(StateError('正在回传，请稍后操作'));
    final origin = server();
    if (origin.isEmpty) return Future.error(StateError('请先选择画廊服务器地址'));
    final snapshot = {
      for (final entry in body.entries)
        entry.key: entry.value is List
            ? List<dynamic>.from(entry.value as List)
            : entry.value,
    };
    final next = _localWrites.then((_) async {
      await db.recordOperation(origin, kind, snapshot);
      if (!_disposed) onChanged?.call();
      _attempt = 0;
      retry();
    });
    _localWrites = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  void retry() {
    _timer?.cancel();
    if (_disposed || _locked) return;
    _timer = Timer(Duration(milliseconds: 250 * (1 << _attempt)), () async {
      if (!await flushAll() && _attempt++ < 2) retry();
    });
  }

  Future<bool> flushAll() async {
    _timer?.cancel();
    await _localWrites;
    if (_disposed) return false;
    while (!_disposed) {
      if (!await (_sending ??= _drain().whenComplete(() => _sending = null))) {
        return false;
      }
      await _localWrites;
      if ((await db.operations(pendingOnly: true, limit: 1)).isEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _drain() async {
    try {
      while (!_disposed) {
        final pending = await db.operations(pendingOnly: true, limit: 1);
        if (pending.isEmpty) return true;
        final operation = pending.first;
        if (operation.server != server()) throw StateError('请切回原画廊服务器完成回传');
        await send(operation);
        await db.acknowledge(operation.seq);
      }
    } catch (error) {
      lastError = error;
    }
    return false;
  }

  /// 确认期间冻结编辑，防止校验后的新操作被清理。
  Future<void> confirmAndLock() async {
    if (_locked) throw StateError('已有回传操作正在执行');
    _locked = true;
    try {
      if (!await flushAll()) throw StateError('修改已保存在本机，回传未完成：$lastError');
      final operations = await db.operations();
      if (operations.any((op) => op.server != server())) {
        throw StateError('请切回原画廊服务器完成回传');
      }
      await verify(operations);
    } catch (_) {
      unlock();
      rethrow;
    }
  }

  void unlock() => _locked = false;

  Future<T> writeOnline<T>(Future<T> Function() action) async {
    await confirmAndLock();
    try {
      if ((await db.operations()).any((op) => op.kind == 'processed')) {
        throw StateError('请先重试完成上次的标记已处理');
      }
      return await action();
    } finally {
      unlock();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

Future<T> retryServerWrite<T>(
  Future<T> Function() action, {
  int attempts = 3,
  Duration firstDelay = const Duration(milliseconds: 400),
}) async {
  Object? lastError;
  for (var i = 0; i < attempts; i++) {
    try {
      return await action();
    } catch (e) {
      lastError = e;
      if (i < attempts - 1) await Future.delayed(firstDelay * (i + 1));
    }
  }
  throw lastError!;
}
