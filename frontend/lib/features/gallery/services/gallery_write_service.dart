import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/gallery/services/gallery_database_service.dart';
import 'package:torrid/features/gallery/services/gallery_write_buffer.dart';

/// 本地缓存端口
///
/// 统一写入口只通过它读写本地副本: 生产实现是 [GalleryMediaWriteStore]
/// (gallery.db 缓存), 单测用内存实现替换。
abstract class MediaWriteStore {
  /// 某媒体当前的标签集合
  Future<List<String>> readTagIds(String mediaId);

  /// 某媒体当前的缓存行（未缓存返回 null）
  Future<MediaAsset?> readAsset(String mediaId);

  /// 全量替换标签集合
  Future<void> writeTagIds(String mediaId, List<String> tagIds);

  /// 批量增删标签关联
  Future<void> writeTagLinks(
    List<String> mediaIds, {
    List<String> addTagIds = const [],
    List<String> removeTagIds = const [],
  });

  /// 软删除 / 恢复（含组成员级联）
  Future<void> writeDeleted(List<String> mediaIds, {required bool deleted});

  /// 捆绑（[leadId] 非空）或解绑（null）
  Future<void> writeGroupId(List<String> mediaIds, String? leadId);

  /// 按字段更新缓存行（message / edit_params 等）
  Future<void> writeFields(List<String> mediaIds, Map<String, Object?> values);

  /// 覆盖整行（回滚到写前状态用）
  Future<void> writeAsset(MediaAsset asset);

  /// 用服务端返回的行覆盖缓存（服务端权威）
  Future<void> writeServerRows(List<MediaAsset> assets);
}

/// [MediaWriteStore] 的本地库实现
class GalleryMediaWriteStore implements MediaWriteStore {
  GalleryMediaWriteStore(this._db);

  final GalleryDatabaseService _db;

  @override
  Future<List<String>> readTagIds(String mediaId) =>
      _db.getTagIdsForMedia(mediaId);

  @override
  Future<MediaAsset?> readAsset(String mediaId) => _db.getMediaAssetById(mediaId);

  @override
  Future<void> writeTagIds(String mediaId, List<String> tagIds) =>
      _db.setTagsForMedia(mediaId, tagIds);

  @override
  Future<void> writeTagLinks(
    List<String> mediaIds, {
    List<String> addTagIds = const [],
    List<String> removeTagIds = const [],
  }) =>
      _db.addRemoveMediaTagLinks(
        mediaIds,
        addTagIds: addTagIds,
        removeTagIds: removeTagIds,
      );

  @override
  Future<void> writeDeleted(List<String> mediaIds, {required bool deleted}) =>
      _db.batchMarkMediaAssetDeleted(mediaIds, deleted: deleted);

  @override
  Future<void> writeGroupId(List<String> mediaIds, String? leadId) =>
      _db.setMediaGroupId(mediaIds, leadId);

  @override
  Future<void> writeFields(List<String> mediaIds, Map<String, Object?> values) =>
      _db.updateMediaAssetsField(mediaIds, values);

  @override
  Future<void> writeAsset(MediaAsset asset) async {
    await _db.updateMediaAsset(asset);
  }

  @override
  Future<void> writeServerRows(List<MediaAsset> assets) =>
      _db.updateMediaAssetsLocal(assets);
}

/// 写入方式
enum MediaWriteMode {
  /// 交互式写入: 入写缓冲, 同一条媒体的连续修改合并后推送, 退避重试, 最终失败回滚
  buffered,

  /// 批量 / 低频写入: 立即推送（失败按固定间隔重试）, 最终失败回滚
  direct,

  /// 纯服务端动作（无本地副作用, 如批次处理游标）, 失败直接抛给调用方
  serverOnly,
}

/// 标签集合全量替换（服务端返回确认后的集合）
typedef MediaTagReplace = Future<List<String>> Function(
  String mediaId,
  List<String> tagIds,
);

/// 媒体标注推送（服务端返回更新后的行）
typedef MediaPatchPush = Future<List<MediaAsset>> Function(
  List<String> mediaIds,
  MediaPatchIntent intent,
);

/// 媒体标签关联批量增删（服务端返回受影响行数）
typedef MediaTagLinksPush = Future<int> Function(
  List<String> mediaIds, {
  List<String> addTagIds,
  List<String> removeTagIds,
});

/// 服务端写入统一入口
///
/// 媒体标注（is_deleted / message / group_id / edit_params / tags 集合及其增删）
/// 的所有写操作都只经过这里, 顺序固定为:
///   记录写前基线 → 本地立即生效 → 推送 → 失败回滚到写前状态。
/// 推送按 [MediaWriteMode] 分流: 交互式走 [GalleryWriteBuffer]（合并 + 退避重试 +
/// 回滚）, 批量/低频直推（重试 + 回滚）。服务端始终权威, 本地库只是缓存。
class GalleryWriteService {
  GalleryWriteService({
    required MediaWriteStore store,
    required MediaTagReplace pushTags,
    required MediaPatchPush pushPatch,
    required MediaTagLinksPush pushTagLinks,
    this.onLocalChanged,
    this.onReverted,
    void Function(String message)? onError,
    Duration debounce = const Duration(milliseconds: 250),
    List<Duration> retryDelays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 1200),
    ],
    int directAttempts = 3,
  })  : _store = store,
        _pushTags = pushTags,
        _pushPatch = pushPatch,
        _pushTagLinks = pushTagLinks,
        _directAttempts = directAttempts {
    _buffer = GalleryWriteBuffer(
      pushTags: pushTags,
      pushPatch: (mediaId, patch) => pushPatch([mediaId], patch),
      onRevert: (mediaId, baseline) => _restore({mediaId: baseline}),
      onError: onError,
      debounce: debounce,
      retryDelays: retryDelays,
    );
  }

  final MediaWriteStore _store;
  final MediaTagReplace _pushTags;
  final MediaPatchPush _pushPatch;
  final MediaTagLinksPush _pushTagLinks;
  final int _directAttempts;

  /// 本地缓存写入后回调（失效派生状态）
  final void Function()? onLocalChanged;

  /// 回滚完成后回调（本地行已被写前状态覆盖, 需要重读列表）
  final void Function()? onReverted;

  late final GalleryWriteBuffer _buffer;

  /// 全量替换某媒体的标签集合（交互式）
  Future<void> setTags(String mediaId, List<String> tagIds) {
    return _submit(
      mediaIds: [mediaId],
      mode: MediaWriteMode.buffered,
      tagIds: tagIds,
    );
  }

  /// 单条媒体标注（交互式）
  Future<void> patchOne(String mediaId, MediaPatchIntent intent) {
    return _submit(
      mediaIds: [mediaId],
      mode: MediaWriteMode.buffered,
      intent: intent,
    );
  }

  /// 批量媒体标注（直推, 失败整体回滚）
  Future<void> patchMany(List<String> mediaIds, MediaPatchIntent intent) {
    return _submit(
      mediaIds: mediaIds,
      mode: MediaWriteMode.direct,
      intent: intent,
    );
  }

  /// 批量加标签（直推, 失败整体回滚）
  Future<void> addTagLinks(List<String> mediaIds, List<String> tagIds) {
    return _submit(
      mediaIds: mediaIds,
      mode: MediaWriteMode.direct,
      addTagIds: tagIds,
    );
  }

  /// 批量移除标签（直推, 失败整体回滚）
  Future<void> removeTagLinks(List<String> mediaIds, List<String> tagIds) {
    return _submit(
      mediaIds: mediaIds,
      mode: MediaWriteMode.direct,
      removeTagIds: tagIds,
    );
  }

  /// 只推服务端、不改本地（批次处理游标等）
  Future<void> pushServerOnly(List<String> mediaIds, MediaPatchIntent intent) {
    return _submit(
      mediaIds: mediaIds,
      mode: MediaWriteMode.serverOnly,
      intent: intent,
    );
  }

  void dispose() => _buffer.dispose();

  /// 唯一写入流程: 基线 → 本地生效 → 推送 → 回滚
  Future<void> _submit({
    required List<String> mediaIds,
    required MediaWriteMode mode,
    MediaPatchIntent? intent,
    List<String>? tagIds,
    List<String>? addTagIds,
    List<String>? removeTagIds,
  }) async {
    final patch = (intent == null || intent.isEmpty) ? null : intent;
    final adds = addTagIds ?? const <String>[];
    final removes = removeTagIds ?? const <String>[];
    final writesTags = tagIds != null || adds.isNotEmpty || removes.isNotEmpty;
    if (mediaIds.isEmpty || (!writesTags && patch == null)) return;

    // 纯服务端动作没有本地副作用, 也无需回滚
    if (mode == MediaWriteMode.serverOnly) {
      await retryServerWrite(
        () => _pushPatch(mediaIds, patch!),
        attempts: _directAttempts,
      );
      return;
    }

    final snapshot = await _readBaselines(
      mediaIds,
      tags: writesTags,
      asset: patch != null,
    );

    // 本地立即生效
    if (tagIds != null) {
      for (final mediaId in mediaIds) {
        await _store.writeTagIds(mediaId, tagIds);
      }
    }
    if (adds.isNotEmpty || removes.isNotEmpty) {
      await _store.writeTagLinks(mediaIds, addTagIds: adds, removeTagIds: removes);
    }
    if (patch != null) {
      await _applyLocalPatch(mediaIds, patch);
    }
    onLocalChanged?.call();

    if (mode == MediaWriteMode.buffered) {
      for (final mediaId in mediaIds) {
        final baseline = snapshot[mediaId];
        if (tagIds != null) {
          _buffer.queueTags(mediaId, tagIds, baselineTagIds: baseline?.tagIds);
        }
        if (patch != null) {
          _buffer.queuePatch(mediaId, patch, baselineAsset: baseline?.asset);
        }
      }
      return;
    }

    // 直推: 任一步最终失败即整体回滚
    try {
      if (tagIds != null) {
        for (final mediaId in mediaIds) {
          await retryServerWrite(
            () => _pushTags(mediaId, tagIds),
            attempts: _directAttempts,
          );
        }
      }
      if (adds.isNotEmpty || removes.isNotEmpty) {
        await retryServerWrite(
          () => _pushTagLinks(mediaIds, addTagIds: adds, removeTagIds: removes),
          attempts: _directAttempts,
        );
      }
      if (patch != null) {
        final rows = await retryServerWrite(
          () => _pushPatch(mediaIds, patch),
          attempts: _directAttempts,
        );
        await _store.writeServerRows(rows);
      }
    } catch (_) {
      await _restore(snapshot);
      rethrow;
    }
  }

  /// 读取写前基线（只读需要回滚的部分, 未缓存的媒体不会写入多余快照）
  Future<Map<String, WriteBaseline>> _readBaselines(
    List<String> mediaIds, {
    required bool tags,
    required bool asset,
  }) async {
    final result = <String, WriteBaseline>{};
    for (final mediaId in mediaIds) {
      result[mediaId] = WriteBaseline(
        asset: asset ? await _store.readAsset(mediaId) : null,
        tagIds: tags ? await _store.readTagIds(mediaId) : null,
      );
    }
    return result;
  }

  /// 标注意图 → 本地缓存动作（字段与服务端一一对应）
  Future<void> _applyLocalPatch(
    List<String> mediaIds,
    MediaPatchIntent patch,
  ) async {
    if (patch.isDeleted != null) {
      await _store.writeDeleted(mediaIds, deleted: patch.isDeleted!);
    }
    if (patch.message != null) {
      await _store.writeFields(
        mediaIds,
        {'message': patch.message!.isEmpty ? null : patch.message},
      );
    }
    if (patch.groupId != null || patch.clearGroup) {
      await _store.writeGroupId(mediaIds, patch.clearGroup ? null : patch.groupId);
    }
    if (patch.editParams != null || patch.clearEditParams) {
      await _store.writeFields(
        mediaIds,
        {'edit_params': patch.clearEditParams ? null : patch.editParams},
      );
    }
  }

  /// 回滚到写前状态（写缓冲最终失败与直推失败共用）
  Future<void> _restore(Map<String, WriteBaseline> snapshot) async {
    for (final entry in snapshot.entries) {
      final baseline = entry.value;
      if (baseline.tagIds != null) {
        await _store.writeTagIds(entry.key, baseline.tagIds!);
      }
      if (baseline.asset != null) {
        await _store.writeAsset(baseline.asset!);
      }
    }
    onReverted?.call();
  }
}
