import 'package:dio/dio.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/album/models/ai_search_models.dart';
import 'package:torrid/features/album/services/ai_api_service.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/gallery/services/gallery_write_buffer.dart';

part 'album_providers.g.dart';

final albumPeopleProvider = FutureProvider.autoDispose<List<AiPerson>>(
  (ref) => ref.watch(aiApiProvider).fetchPersons(),
);

/// 媒体筛选条件
///
/// [tagIds] 为人工标签（可写），[vlmTags] 为服务端 AI 标签（只读）。
/// 两者物理隔离、互不覆盖，同时在筛选条件里出现时取交集。
class AlbumFilter {
  final List<String> tagIds;
  final bool includeDescendants;
  final bool untagged;
  final bool includeDeleted;
  final List<String> vlmTags;
  final DateTime? jumpMonth;

  const AlbumFilter({
    this.tagIds = const [],
    this.includeDescendants = true,
    this.untagged = false,
    this.includeDeleted = false,
    this.vlmTags = const [],
    this.jumpMonth,
  });

  AlbumFilter copyWith({
    List<String>? tagIds,
    bool? includeDescendants,
    bool? untagged,
    bool? includeDeleted,
    List<String>? vlmTags,
    DateTime? jumpMonth,
    bool clearMonth = false,
  }) {
    return AlbumFilter(
      tagIds: tagIds ?? this.tagIds,
      includeDescendants: includeDescendants ?? this.includeDescendants,
      untagged: untagged ?? this.untagged,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      vlmTags: vlmTags ?? this.vlmTags,
      jumpMonth: clearMonth ? null : jumpMonth ?? this.jumpMonth,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AlbumFilter &&
      other.untagged == untagged &&
      other.includeDeleted == includeDeleted &&
      other.includeDescendants == includeDescendants &&
      other.jumpMonth == jumpMonth &&
      other.tagIds.length == tagIds.length &&
      other.tagIds.every(tagIds.contains) &&
      other.vlmTags.length == vlmTags.length &&
      other.vlmTags.every(vlmTags.contains);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(tagIds),
    includeDescendants,
    untagged,
    includeDeleted,
    Object.hashAllUnordered(vlmTags),
    jumpMonth,
  );
}

/// 筛选条件 Provider
@riverpod
class AlbumFilterNotifier extends _$AlbumFilterNotifier {
  @override
  AlbumFilter build() => const AlbumFilter();

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

  /// 选中/取消单个 AI 标签（只读数据，仅参与筛选）
  void toggleVlmTag(String tag) {
    final next = [...state.vlmTags];
    if (!next.remove(tag)) next.add(tag);
    state = state.copyWith(vlmTags: next);
  }

  void clearVlmTags() => state = state.copyWith(vlmTags: const []);

  void setJumpMonth(DateTime? month) =>
      state = state.copyWith(jumpMonth: month, clearMonth: month == null);

  void reset() => state = const AlbumFilter();
}

/// 媒体分页数据
class AlbumMediaPage {
  final List<MediaAsset> assets;

  /// media_id → tag ids
  final Map<String, List<String>> tagIdsByMedia;
  final int total;
  final bool loadingMore;
  final int nextOffset;

  AlbumMediaPage({
    required this.assets,
    required this.tagIdsByMedia,
    required this.total,
    this.loadingMore = false,
    int? nextOffset,
  }) : nextOffset = nextOffset ?? assets.length;

  bool get hasMore => nextOffset < total;

  AlbumMediaPage copyWith({
    List<MediaAsset>? assets,
    Map<String, List<String>>? tagIdsByMedia,
    int? total,
    bool? loadingMore,
  }) {
    return AlbumMediaPage(
      assets: assets ?? this.assets,
      tagIdsByMedia: tagIdsByMedia ?? this.tagIdsByMedia,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
      nextOffset: nextOffset,
    );
  }
}

const int _kPageSize = 60;

/// AI 不可用或暂无产物时返回空列表，页面据此隐藏 AI 标签入口。
final albumAiTagsProvider = FutureProvider<List<AiTagCount>>((ref) async {
  try {
    return await ref.watch(aiApiProvider).fetchTags();
  } catch (_) {
    return const <AiTagCount>[];
  }
});

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）
@riverpod
class AlbumMedia extends _$AlbumMedia {
  CancelToken? _request;
  int? _reloadLimit;

  @override
  Future<AlbumMediaPage> build() async {
    final token = _request = CancelToken();
    ref.onDispose(() {
      _request?.cancel();
      _request = null;
    });
    final filter = ref.watch(albumFilterProvider);
    ref.watch(galleryApiProvider);
    final limit = _reloadLimit ?? _kPageSize;
    _reloadLimit = null;
    return _fetch(filter, 0, token, limit: limit);
  }

  Future<void> loadMore() async {
    if (state.isLoading) return;
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    final token = _request = CancelToken();
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(
        ref.read(albumFilterProvider),
        current.nextOffset,
        token,
        previous: current,
      );
      if (token.isCancelled) return;
      state = AsyncData(next);
    } catch (e) {
      if (token.isCancelled) return;
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
    final loaded = state.value?.assets.length ?? _kPageSize;
    _reloadLimit = loaded.clamp(_kPageSize, 1000);
    await refresh();
  }

  Future<void> replaceLoadedAssets(List<MediaAsset> updated) async {
    final current = state.value;
    if (state.isLoading || (current?.loadingMore ?? false)) {
      await reloadKeepingLength();
      return;
    }
    if (current == null || updated.isEmpty) return;
    final byId = {for (final asset in updated) asset.id: asset};
    if (!current.assets.any((asset) => byId.containsKey(asset.id))) return;
    state = AsyncData(
      current.copyWith(
        assets: [for (final asset in current.assets) byId[asset.id] ?? asset],
      ),
    );
  }

  Future<AlbumMediaPage> _fetch(
    AlbumFilter filter,
    int offset,
    CancelToken token, {
    AlbumMediaPage? previous,
    int limit = _kPageSize,
  }) async {
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    final month = filter.jumpMonth;

    Future<MediaQueryResult> query(GalleryApiService api) => api.queryMedia(
      tagIds: filter.tagIds,
      includeDescendants: filter.includeDescendants,
      untagged: filter.untagged,
      includeDeleted: filter.includeDeleted,
      vlmTags: filter.vlmTags,
      capturedBefore: month == null
          ? null
          : DateTime(month.year, month.month + 1),
      limit: limit,
      offset: offset,
      cancelToken: token,
    );

    final binding = await db.libraryId();
    var matched = binding != null;
    late final MediaQueryResult result;
    try {
      result = await query(GalleryApiService(api.client, libraryId: binding));
    } on ApiException catch (error) {
      if (!matched || error.statusCode != 409) rethrow;
      matched = false;
      result = await query(api);
    }

    final pageTags = <String, List<String>>{
      for (final asset in result.mediaAssets) asset.id: [],
    };
    for (final link in result.mediaTagLinks) {
      pageTags.putIfAbsent(link.mediaId, () => []).add(link.tagId);
    }
    if (matched && !token.isCancelled) {
      await db.updateMediaAssetsLocal(
        result.mediaAssets,
        preserveOperations: true,
        expectedLibraryId: binding,
        tagIdsByMedia: pageTags,
      );
    }

    final assets = {
      for (final asset in [...?previous?.assets, ...result.mediaAssets])
        asset.id: asset,
    }.values.toList();
    return AlbumMediaPage(
      assets: assets,
      tagIdsByMedia: {...?previous?.tagIdsByMedia, ...pageTags},
      total: result.total,
      nextOffset: result.mediaAssets.isEmpty
          ? result.total
          : offset + result.mediaAssets.length,
    );
  }
}

/// 选中集合
@riverpod
class AlbumSelection extends _$AlbumSelection {
  @override
  Set<String> build() {
    ref.watch(galleryApiProvider);
    return {};
  }

  void toggle(String mediaId) {
    final next = {...state};
    if (!next.remove(mediaId)) next.add(mediaId);
    state = next;
  }

  void selectAll(Iterable<String> mediaIds) => state = {...mediaIds};

  void clear() => state = {};
}

typedef AlbumMediaUpdate = ({List<MediaAsset> assets, bool changesVisibility});

@riverpod
class AlbumEdits extends _$AlbumEdits {
  @override
  ({int tagRevision, AlbumMediaUpdate? media}) build() =>
      (tagRevision: 0, media: null);

  void tagsChanged() =>
      state = (tagRevision: state.tagRevision + 1, media: state.media);

  void mediaChanged(AlbumMediaUpdate update) =>
      state = (tagRevision: state.tagRevision, media: update);
}

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）
@riverpod
class AlbumActions extends _$AlbumActions {
  @override
  bool build() => false;

  Future<void> _run(
    Future<List<MediaAsset>?> Function(GalleryApiService) action,
  ) async {
    if (state) throw StateError('正在提交另一项操作');
    final keepAlive = ref.keepAlive();
    state = true;
    try {
      final updated = await ref
          .read(galleryWriteBufferProvider)
          .writeOnline(action);

      ref.invalidate(galleryServerOverviewProvider);
      try {
        final photos = ref.read(albumMediaProvider.notifier);
        if (updated == null) {
          await photos.reloadKeepingLength();
        } else {
          await photos.replaceLoadedAssets(updated);
        }
      } catch (_) {}
      if (updated == null) {
        try {
          await ref.read(tagTreeProvider.notifier).syncFromServer();
        } catch (_) {}
      }
    } finally {
      state = false;
      keepAlive.close();
    }
  }

  Future<void> addTags(List<String> mediaIds, List<String> tagIds) =>
      editTags(mediaIds, add: tagIds);

  Future<void> removeTags(List<String> mediaIds, List<String> tagIds) =>
      editTags(mediaIds, remove: tagIds);

  Future<void> editTags(
    List<String> mediaIds, {
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    if (mediaIds.isEmpty || (add.isEmpty && remove.isEmpty)) return;
    final db = ref.read(galleryDatabaseProvider);
    await _run((api) async {
      await retryServerWrite(
        () => api.batchMediaTags(
          mediaIds: mediaIds,
          addTagIds: add,
          removeTagIds: remove,
        ),
      );
      await db.addRemoveMediaTagLinks(
        mediaIds,
        addTagIds: add,
        removeTagIds: remove,
      );
      ref.read(albumEditsProvider.notifier).tagsChanged();
      return null;
    });
  }

  Future<void> setDeleted(
    List<String> mediaIds,
    bool deleted, {
    bool onlySelected = false,
  }) => _patchMedia(
    mediaIds,
    MediaPatchIntent(isDeleted: deleted),
    onlySelected: onlySelected,
  );

  /// 设置备注（空串清空）
  Future<void> setMessage(List<String> mediaIds, String message) =>
      _patchMedia(mediaIds, MediaPatchIntent(message: message));

  /// 捆绑到主文件
  Future<void> bundle(
    String leadId,
    List<String> memberIds, {
    bool onlySelected = false,
  }) => _patchMedia(
    memberIds,
    MediaPatchIntent(groupId: leadId),
    onlySelected: onlySelected,
  );

  /// 解绑
  Future<void> unbundle(List<String> memberIds) =>
      _patchMedia(memberIds, const MediaPatchIntent(clearGroup: true));

  Future<void> _patchMedia(
    List<String> mediaIds,
    MediaPatchIntent intent, {
    bool onlySelected = false,
  }) async {
    if (mediaIds.isEmpty) return;
    final db = ref.read(galleryDatabaseProvider);
    await _run((api) async {
      final updated = await retryServerWrite(
        () => api.patchMedia(
          mediaIds: mediaIds,
          intent: intent,
          onlySelected: onlySelected,
        ),
      );
      await db.updateMediaAssetsLocal(updated);
      ref.read(albumEditsProvider.notifier).mediaChanged((
        assets: updated,
        changesVisibility: intent.isDeleted != null,
      ));
      return intent.isDeleted == null ? updated : null;
    });
  }
}
