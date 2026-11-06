import 'dart:async';

import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_write_verification.dart';

/// 本地事务提交后顺序回传；确认过的记录保留到批次校验和清理完成。
class GalleryWriteBuffer {
  GalleryWriteBuffer({
    required this.db,
    required this.currentClient,
    this.onChanged,
  });

  final GalleryDatabaseService db;
  final ApiClient Function() currentClient;
  final void Function()? onChanged;
  Future<void> _localWrites = Future.value();
  Future<bool>? _sending;
  Timer? _timer;
  bool _disposed = false;
  bool _locked = false;
  int _attempt = 0;
  Object? _lastError;

  Future<void> queueTags(String id, List<String> tags) =>
      queue('tags', {'media_id': id, 'tag_ids': tags.toSet().toList()});

  Future<void> queuePatch(List<String> ids, MediaPatchIntent patch) =>
      queue('patch', patch.toBody(ids));

  Future<void> queue(String kind, Map<String, dynamic> body) {
    if (_locked || _disposed) return Future.error(StateError('正在回传，请稍后操作'));
    final snapshot = {
      for (final entry in body.entries)
        entry.key: entry.value is List
            ? List<dynamic>.from(entry.value as List)
            : entry.value,
    };
    final next = _localWrites.then((_) async {
      await db.recordOperation(kind, snapshot);
      if (!_disposed) onChanged?.call();
      retry();
    });
    _localWrites = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  void retry() {
    _attempt = 0;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _timer?.cancel();
    if (_disposed || _locked || currentClient().baseUrl.isEmpty) return;
    _timer = Timer(Duration(milliseconds: 250 * (1 << _attempt)), () async {
      if (!await _flushInBackground() && _attempt++ < 2) _scheduleRetry();
    });
  }

  Future<bool> _flushInBackground() async {
    await _localWrites;
    while (!_disposed && !_locked) {
      final client = currentClient();
      if (client.baseUrl.isEmpty) return true;
      final sending = _sending ??= _drain(
        client,
      ).whenComplete(() => _sending = null);
      if (!await sending) return false;
      await _localWrites;
      if ((await db.operations(pendingOnly: true, limit: 1)).isEmpty) {
        return true;
      }
    }
    return true;
  }

  Future<bool> _drain(ApiClient client) async {
    final api = GalleryApiService(client);
    try {
      while (!_disposed) {
        final pending = await db.operations(pendingOnly: true, limit: 1);
        if (pending.isEmpty) return true;
        final operation = pending.first;
        await api.sendOperation(operation);
        await db.acknowledge(operation.seq);
      }
    } catch (error) {
      _lastError = error;
    }
    return false;
  }

  /// 确认期间冻结编辑，防止校验后的新操作被清理。
  Future<ApiClient> confirmAndLock({bool requireConnection = true}) async {
    if (_locked) throw StateError('已有回传操作正在执行');
    _locked = true;
    _timer?.cancel();
    try {
      await _localWrites;
      await _sending;
      final client = currentClient();
      if (client.baseUrl.isEmpty) {
        if (requireConnection || (await db.operations(limit: 1)).isNotEmpty) {
          throw StateError('请先配置服务器地址，本机修改已保留');
        }
        return client;
      }
      if (!await _drain(client)) {
        throw StateError('修改已保存在本机，回传未完成：$_lastError');
      }
      await verifyGalleryWrites(
        db,
        GalleryApiService(client),
        await db.operations(),
      );
      return client;
    } catch (_) {
      unlock();
      rethrow;
    }
  }

  void unlock() => _locked = false;

  Future<T> writeOnline<T>(Future<T> Function(GalleryApiService) action) async {
    final client = await confirmAndLock();
    try {
      if ((await db.operations()).any((op) => op.kind == 'processed')) {
        throw StateError('请先重试完成上次的标记已处理');
      }
      return await action(GalleryApiService(client));
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
