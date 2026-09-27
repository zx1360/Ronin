import 'dart:async';

import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';

/// 乐观写缓冲
///
/// 交互必须立即生效, 因此本地缓存与 UI 先改; 服务端推送在后台按媒体串行执行:
///  1. 同一媒体的连续修改（[debounce] 窗口内）合并为"最新完整状态", 只发一次请求;
///  2. 推送失败按 [retryDelays] 退避重试;
///  3. 重试仍失败且期间没有更新的修改 → 回调 [onRevert] 让上层回滚到写前状态。
///
/// 本类不直接依赖网络与数据库, 推送/回滚动作由构造方注入, 便于单测。
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
  final Future<void> Function(String mediaId, MediaPatchIntent patch)
      pushPatch;

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
    final write = _writeFor(mediaId, baselineTagIds: baselineTagIds);
    write.tagIds = List<String>.from(tagIds);
    _schedule(mediaId);
  }

  /// 排队一次媒体标注写入
  void queuePatch(
    String mediaId,
    MediaPatchIntent patch, {
    MediaAsset? baselineAsset,
    List<String>? baselineTagIds,
  }) {
    if (patch.isEmpty) return;
    final write = _writeFor(
      mediaId,
      baselineAsset: baselineAsset,
      baselineTagIds: baselineTagIds,
    );
    write.patch = write.patch == null ? patch : write.patch!.merge(patch);
    _schedule(mediaId);
  }

  /// 取（或创建）某媒体的待写状态; 快照只在首次入队时记录
  _PendingWrite _writeFor(
    String mediaId, {
    MediaAsset? baselineAsset,
    List<String>? baselineTagIds,
  }) {
    return _writes.putIfAbsent(
      mediaId,
      () => _PendingWrite(WriteBaseline(
        asset: baselineAsset,
        tagIds: baselineTagIds == null ? null : List<String>.from(baselineTagIds),
      )),
    );
  }

  void _schedule(String mediaId) {
    final write = _writes[mediaId];
    if (write == null || _disposed) return;
    if (write.inFlight) {
      write.dirty = true;
      return;
    }
    write.timer?.cancel();
    write.timer = Timer(debounce, () => _flush(mediaId));
  }

  Future<void> _flush(String mediaId) async {
    final write = _writes[mediaId];
    if (write == null || write.inFlight || _disposed) return;

    final tagIds = write.tagIds;
    final patch = write.patch;
    if (tagIds == null && patch == null) {
      _writes.remove(mediaId);
      return;
    }

    write.inFlight = true;
    write.dirty = false;
    write.tagIds = null;
    write.patch = null;

    try {
      if (tagIds != null) await pushTags(mediaId, tagIds);
      if (patch != null) await pushPatch(mediaId, patch);
      write.attempt = 0;
      write.inFlight = false;
      if (write.dirty || write.tagIds != null || write.patch != null) {
        _schedule(mediaId);
      } else {
        _writes.remove(mediaId);
      }
    } catch (_) {
      write.inFlight = false;
      // 期间有更新的修改: 直接带着最新状态重试, 不回滚
      if (write.dirty || write.tagIds != null || write.patch != null) {
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
        // 回滚失败时以服务端为准, 由后续同步纠正
      }
      onError?.call('网络异常，已撤销未同步的修改');
    }
  }

  void dispose() {
    _disposed = true;
    for (final write in _writes.values) {
      write.timer?.cancel();
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

  const WriteBaseline({this.asset, this.tagIds});
}

class _PendingWrite {
  _PendingWrite(this.baseline);

  final WriteBaseline baseline;

  List<String>? tagIds;
  MediaPatchIntent? patch;
  Timer? timer;
  bool inFlight = false;

  /// 推送进行中又产生了新修改
  bool dirty = false;
  int attempt = 0;
}
