import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_write_buffer.dart';

part 'immich_providers.g.dart';

/// 相册页(immich)数据层
///
/// 该页始终在线: 媒体/标签/关联均直接从服务端读取, 同时把结果写回本地缓存,
/// 使画廊页的离线缓存与服务端保持一致。写操作同样走服务端权威接口。

/// 媒体筛选条件
class ImmichFilter {
  final List<String> tagIds;
  final bool includeDescendants;
  final bool untagged;
  final bool includeDeleted;

  const ImmichFilter({
    this.tagIds = const [],
    this.includeDescendants = true,
    this.untagged = false,
    this.includeDeleted = false,
  });

  ImmichFilter copyWith({
    List<String>? tagIds,
    bool? includeDescendants,
    bool? untagged,
    bool? includeDeleted,
  }) {
    return ImmichFilter(
      tagIds: tagIds ?? this.tagIds,
      includeDescendants: includeDescendants ?? this.includeDescendants,
      untagged: untagged ?? this.untagged,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImmichFilter &&
      other.untagged == untagged &&
      other.includeDeleted == includeDeleted &&
      other.includeDescendants == includeDescendants &&
      other.tagIds.length == tagIds.length &&
      other.tagIds.every(tagIds.contains);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(tagIds), includeDescendants, untagged, includeDeleted);
}

/// 筛选条件 Provider
@riverpod
class ImmichFilterNotifier extends _$ImmichFilterNotifier {
  @override
  ImmichFilter build() => const ImmichFilter();

  /// 选中/取消单个标签（多选累积）
  void toggleTag(String tagId) {
    final next = [...state.tagIds];
    if (!next.remove(tagId)) next.add(tagId);
    state = state.copyWith(tagIds: next, untagged: false);
  }

  /// 只查看未打标签的媒体
  void toggleUntagged() {
    state = state.copyWith(untagged: !state.untagged, tagIds: const []);
  }

  void setIncludeDescendants(bool value) =>
      state = state.copyWith(includeDescendants: value);

  void setIncludeDeleted(bool value) =>
      state = state.copyWith(includeDeleted: value);

  void clearTags() => state = state.copyWith(tagIds: const []);

  void reset() => state = const ImmichFilter();
}

/// 媒体分页数据
class ImmichMediaPage {
  final List<MediaAsset> assets;

  /// media_id → tag ids
  final Map<String, List<String>> tagIdsByMedia;
  final int total;
  final bool loadingMore;

  const ImmichMediaPage({
    required this.assets,
    required this.tagIdsByMedia,
    required this.total,
    this.loadingMore = false,
  });

  bool get hasMore => assets.length < total;

  ImmichMediaPage copyWith({
    List<MediaAsset>? assets,
    Map<String, List<String>>? tagIdsByMedia,
    int? total,
    bool? loadingMore,
  }) {
    return ImmichMediaPage(
      assets: assets ?? this.assets,
      tagIdsByMedia: tagIdsByMedia ?? this.tagIdsByMedia,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

const int _kPageSize = 60;

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）
@riverpod
class ImmichMedia extends _$ImmichMedia {
  @override
  Future<ImmichMediaPage> build() async {
    final filter = ref.watch(immichFilterNotifierProvider);
    return _fetch(filter, 0);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(
        ref.read(immichFilterNotifierProvider),
        current.assets.length,
        previous: current,
      );
      state = AsyncData(next);
    } catch (e) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// 重新拉取并保持已加载条数（批量操作后刷新, 不退回第一页）
  Future<void> reloadKeepingLength() async {
    final loaded = state.valueOrNull?.assets.length ?? _kPageSize;
    final filter = ref.read(immichFilterNotifierProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(filter, 0, limit: loaded.clamp(_kPageSize, 1000)),
    );
  }

  Future<ImmichMediaPage> _fetch(
    ImmichFilter filter,
    int offset, {
    ImmichMediaPage? previous,
    int limit = _kPageSize,
  }) async {
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);

    final result = await api.queryMedia(
      tagIds: filter.tagIds,
      includeDescendants: filter.includeDescendants,
      untagged: filter.untagged,
      includeDeleted: filter.includeDeleted,
      limit: limit,
      offset: offset,
    );

    // 写回本地缓存（仅更新已缓存的行, 保持画廊页一致）
    await db.updateMediaAssetsLocal(result.mediaAssets);
    final tagIdsByMedia = <String, List<String>>{
      ...?previous?.tagIdsByMedia,
    };
    for (final link in result.mediaTagLinks) {
      tagIdsByMedia.putIfAbsent(link.mediaId, () => []).add(link.tagId);
    }
    await db.replaceTagsForMediaBatch(tagIdsByMedia);

    final assets = [...?previous?.assets, ...result.mediaAssets];
    return ImmichMediaPage(
      assets: assets,
      tagIdsByMedia: tagIdsByMedia,
      total: result.total,
    );
  }
}

/// 选中集合
@riverpod
class ImmichSelection extends _$ImmichSelection {
  @override
  Set<String> build() => {};

  void toggle(String mediaId) {
    final next = {...state};
    if (!next.remove(mediaId)) next.add(mediaId);
    state = next;
  }

  void selectAll(Iterable<String> mediaIds) => state = {...mediaIds};

  void clear() => state = {};
}

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）
@riverpod
class ImmichActions extends _$ImmichActions {
  @override
  bool build() => false;

  Future<T> _run<T>(Future<T> Function() action) async {
    state = true;
    try {
      final result = await action();
      // 保持已加载条数, 避免操作后跳回第一页
      await ref.read(immichMediaProvider.notifier).reloadKeepingLength();
      ref.read(immichSelectionProvider.notifier).clear();
      ref.invalidate(mediaIdsWithTagsProvider);
      // 标签计数需要服务端重算
      await ref.read(tagTreeProvider.notifier).syncFromServer();
      return result;
    } finally {
      state = false;
    }
  }

  /// 批量加标签
  Future<void> addTags(List<String> mediaIds, List<String> tagIds) async {
    if (mediaIds.isEmpty || tagIds.isEmpty) return;
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    await _run(() async {
      await retryServerWrite(
        () => api.batchMediaTags(mediaIds: mediaIds, addTagIds: tagIds),
      );
      await db.addRemoveMediaTagLinks(mediaIds, addTagIds: tagIds);
    });
  }

  /// 批量移除标签
  Future<void> removeTags(List<String> mediaIds, List<String> tagIds) async {
    if (mediaIds.isEmpty || tagIds.isEmpty) return;
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    await _run(() async {
      await retryServerWrite(
        () => api.batchMediaTags(mediaIds: mediaIds, removeTagIds: tagIds),
      );
      await db.addRemoveMediaTagLinks(mediaIds, removeTagIds: tagIds);
    });
  }

  /// 软删除/恢复
  Future<void> setDeleted(List<String> mediaIds, bool deleted) async {
    if (mediaIds.isEmpty) return;
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    await _run(() async {
      final updated = await retryServerWrite(
        () => api.patchMedia(
          mediaIds: mediaIds,
          intent: MediaPatchIntent(isDeleted: deleted),
        ),
      );
      await db.updateMediaAssetsLocal(updated);
      await db.updateMediaAssetsField(
        mediaIds,
        {'is_deleted': deleted ? 1 : 0},
      );
    });
  }

  /// 设置备注（空串清空）
  Future<void> setMessage(List<String> mediaIds, String message) async {
    if (mediaIds.isEmpty) return;
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    await _run(() async {
      final updated = await retryServerWrite(
        () => api.patchMedia(
          mediaIds: mediaIds,
          intent: MediaPatchIntent(message: message),
        ),
      );
      await db.updateMediaAssetsLocal(updated);
    });
  }

  /// 捆绑到主文件
  Future<void> bundle(String leadId, List<String> memberIds) async {
    if (memberIds.isEmpty) return;
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    await _run(() async {
      final updated = await retryServerWrite(
        () => api.patchMedia(
          mediaIds: memberIds,
          intent: MediaPatchIntent(groupId: leadId),
        ),
      );
      await db.updateMediaAssetsLocal(updated);
    });
  }

  /// 解绑
  Future<void> unbundle(List<String> memberIds) async {
    if (memberIds.isEmpty) return;
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    await _run(() async {
      final updated = await retryServerWrite(
        () => api.patchMedia(
          mediaIds: memberIds,
          intent: const MediaPatchIntent(clearGroup: true),
        ),
      );
      await db.updateMediaAssetsLocal(updated);
    });
  }
}
