import 'dart:async';

import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_write_verification.dart';

/// 本地事务提交后顺序回传；确认过的记录保留到批次校验和清理完成。
class GalleryWriteBuffer {
  GalleryWriteBuffer({required this.db, required this.currentClient});

  final GalleryDatabaseService db;
  final ApiClient Function() currentClient;
  Future<void> _localWrites = Future.value();
  Future<bool>? _sending;
  Timer? _timer;
  bool _disposed = false;
  bool _locked = false;
  int _attempt = 0;

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
      final sending = _sending ??= _flushPending(
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

  Future<bool> _flushPending(ApiClient client) async {
    try {
      if ((await db.operations(pendingOnly: true, limit: 1)).isNotEmpty) {
        await _drain(await _boundApi(client));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _drain(GalleryApiService api) async {
    while (!_disposed) {
      if (!identical(api.client, currentClient())) {
        throw StateError('服务器连接已切换，请重试');
      }
      final pending = await db.operations(pendingOnly: true, limit: 1);
      if (pending.isEmpty) return;
      final operation = pending.first;
      await api.sendOperation(operation);
      await db.acknowledge(operation.seq);
    }
  }

  Future<GalleryApiService> _boundApi(ApiClient client) async {
    final id = await GalleryApiService(client).fetchLibraryId();
    if (_disposed || !identical(client, currentClient())) {
      throw StateError('服务器连接已切换，请重试');
    }
    await db.bindLibrary(id);
    return GalleryApiService(client, libraryId: id);
  }

  Future<void> lock() async {
    if (_locked) throw StateError('已有回传操作正在执行');
    _locked = true;
    _timer?.cancel();
    await _localWrites;
    await _sending;
  }

  /// 确认期间冻结编辑，防止校验后的新操作被清理。
  Future<GalleryApiService> confirmAndLock({
    bool requireConnection = true,
  }) async {
    await lock();
    try {
      final client = currentClient();
      if (!requireConnection && (await db.operations(limit: 1)).isEmpty) {
        return GalleryApiService(client);
      }
      if (client.baseUrl.isEmpty) {
        throw StateError('请先配置服务器地址，本机修改已保留');
      }
      final api = await _boundApi(client);
      await _drain(api);
      await verifyGalleryWrites(db, api, await db.operations());
      return api;
    } catch (_) {
      unlock();
      rethrow;
    }
  }

  void unlock() {
    _locked = false;
    retry();
  }

  Future<T> writeOnline<T>(Future<T> Function(GalleryApiService) action) async {
    final api = await confirmAndLock();
    try {
      if ((await db.operations()).any((op) => op.kind == 'processed')) {
        throw StateError('请先重试完成上次的标记已处理');
      }
      return await action(api);
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
