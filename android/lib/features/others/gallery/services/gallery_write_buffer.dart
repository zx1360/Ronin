import 'dart:async';

import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';

/// 按媒体合并、串行推送乐观修改；仅回滚尚未确认的部分。
class GalleryWriteBuffer {
  GalleryWriteBuffer({
    required this.pushTags,
    required this.pushPatch,
    required this.onRevert,
    this.onError,
    this.retryDelays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 1200),
    ],
    this.debounce = const Duration(milliseconds: 250),
  });

  /// 推送标签集合（全量替换）
  final Future<void> Function(String mediaId, List<String> tagIds) pushTags;

  /// 推送媒体标注
  final Future<void> Function(String mediaId, MediaPatchIntent patch) pushPatch;

  /// 最终失败时回滚到写前状态
  final Future<void> Function(String mediaId, WriteBaseline baseline) onRevert;

  /// 最终失败时的用户提示
  final void Function(String message)? onError;

  final List<Duration> retryDelays;
  final Duration debounce;

  final Map<String, _PendingWrite> _writes = {};
  bool _disposed = false;

  /// 排队一次标签集合写入（[baselineTagIds] 为改动前的标签集合）
  void queueTags(
    String mediaId,
    List<String> tagIds, {
    List<String>? baselineTagIds,
  }) {
    if (_disposed) return;
    final write = _writeFor(mediaId, baselineTagIds: baselineTagIds);
    write.tagIds = List<String>.from(tagIds);
    _schedule(mediaId);
  }

  /// 排队一次媒体标注写入
  void queuePatch(
    String mediaId,
    MediaPatchIntent patch, {
    MediaAsset? baselineAsset,
    List<MediaAsset> baselineMembers = const [],
  }) {
    if (_disposed) return;
    if (patch.isEmpty) return;
    final write = _writeFor(
      mediaId,
      baselineAsset: baselineAsset,
      baselineMembers: baselineMembers,
    );
    write.patch = write.patch == null ? patch : write.patch!.merge(patch);
    _schedule(mediaId);
  }

  _PendingWrite _writeFor(
    String mediaId, {
    MediaAsset? baselineAsset,
    List<String>? baselineTagIds,
    List<MediaAsset> baselineMembers = const [],
  }) {
    final write = _writes.putIfAbsent(mediaId, _PendingWrite.new);
    write.baseline = WriteBaseline(
      asset: write.baseline.asset ?? baselineAsset,
      tagIds: write.baseline.tagIds ?? baselineTagIds?.toList(),
      members: write.baseline.members.isEmpty
          ? baselineMembers
          : write.baseline.members,
    );
    return write;
  }

  /// 清理缓存或推进批次前，等待当前修改完成；失败时保留缓存。
  Future<bool> flushAll() async {
    if (_disposed) return false;
    while (_writes.isNotEmpty) {
      final pending = Map.of(_writes);
      for (final entry in pending.entries) {
        entry.value.timer?.cancel();
        if (!entry.value.inFlight) unawaited(_flush(entry.key));
      }
      final results = await Future.wait(
        pending.values.map((w) => w.done.future),
      );
      if (results.any((ok) => !ok)) return false;
    }
    return !_disposed;
  }

  void _schedule(String mediaId) {
    final write = _writes[mediaId];
    if (write == null || _disposed) return;
    if (write.inFlight) return;
    write.timer?.cancel();
    write.timer = Timer(debounce, () => _flush(mediaId));
  }

  Future<void> _flush(String mediaId) async {
    final write = _writes[mediaId];
    if (write == null || write.inFlight || _disposed) return;

    var tagIds = write.tagIds;
    var patch = write.patch;
    if (tagIds == null && patch == null) {
      _writes.remove(mediaId);
      write.done.complete(true);
      return;
    }

    write.inFlight = true;
    write.tagIds = null;
    write.patch = null;

    try {
      if (tagIds != null) {
        await pushTags(mediaId, tagIds);
        write.baseline = WriteBaseline(
          asset: write.baseline.asset,
          tagIds: write.tagIds == null ? null : tagIds,
          members: write.baseline.members,
        );
        tagIds = null;
      }
      if (patch != null) {
        await pushPatch(mediaId, patch);
        final baseline = write.baseline.asset;
        write.baseline = WriteBaseline(
          asset: write.patch == null || baseline == null
              ? null
              : patch.applyTo(baseline),
          tagIds: write.baseline.tagIds,
          members: write.patch?.isDeleted == null
              ? const []
              : [
                  for (final member in write.baseline.members)
                    member.copyWith(isDeleted: patch.isDeleted),
                ],
        );
        patch = null;
      }
      if (_disposed) return;
      write.attempt = 0;
      write.inFlight = false;
      if (write.tagIds != null || write.patch != null) {
        _schedule(mediaId);
      } else {
        _writes.remove(mediaId);
        write.done.complete(true);
      }
    } catch (_) {
      if (_disposed) return;
      write.inFlight = false;
      // 期间有更新的修改: 直接带着最新状态重试, 不回滚
      if (write.tagIds != null || write.patch != null) {
        if (tagIds != null) write.tagIds ??= tagIds;
        if (patch != null) write.patch = patch.merge(write.patch ?? patch);
        _schedule(mediaId);
        return;
      }
      // 已经没有新修改: 退避重试
      if (write.attempt < retryDelays.length) {
        final delay = retryDelays[write.attempt];
        write.attempt++;
        if (tagIds != null) write.tagIds = tagIds;
        if (patch != null) write.patch = patch;
        write.timer?.cancel();
        write.timer = Timer(delay, () => _flush(mediaId));
        return;
      }
      // 最终失败: 回滚到写前状态
      final baseline = write.baseline;
      _writes.remove(mediaId);
      try {
        await onRevert(mediaId, baseline);
      } catch (_) {
        if (_disposed) return;
        onError?.call('网络异常，本地回滚失败，请重新同步');
        write.done.complete(false);
        return;
      }
      if (_disposed) return;
      write.done.complete(false);
      onError?.call('网络异常，已撤销未同步的修改');
    }
  }

  void dispose() {
    _disposed = true;
    for (final write in _writes.values) {
      write.timer?.cancel();
      if (!write.done.isCompleted) write.done.complete(false);
    }
    _writes.clear();
  }
}

/// 服务端写重试（批量/低频操作用, 高频单条操作请走 [GalleryWriteBuffer]）
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
      if (i < attempts - 1) {
        await Future.delayed(firstDelay * (i + 1));
      }
    }
  }
  throw lastError!;
}

/// 写入前状态快照
class WriteBaseline {
  final MediaAsset? asset;
  final List<String>? tagIds;
  final List<MediaAsset> members;

  const WriteBaseline({this.asset, this.tagIds, this.members = const []});
}

class _PendingWrite {
  WriteBaseline baseline = const WriteBaseline();
  final done = Completer<bool>();

  List<String>? tagIds;
  MediaPatchIntent? patch;
  Timer? timer;
  bool inFlight = false;

  int attempt = 0;
}
