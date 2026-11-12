import 'package:dio/dio.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/ai/models/ai_search_models.dart';
import 'package:torrid/features/others/ai/services/ai_api_service.dart';
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
///
/// [tagIds] 为人工标签（可写），[vlmTags] 为服务端 AI 标签（只读）。
/// 两者物理隔离、互不覆盖，同时在筛选条件里出现时取交集。
class ImmichFilter {
  final List<String> tagIds;
  final bool includeDescendants;
  final bool untagged;
  final bool includeDeleted;
  final List<String> vlmTags;
  final DateTime? jumpMonth;

  const ImmichFilter({
    this.tagIds = const [],
    this.includeDescendants = true,
    this.untagged = false,
    this.includeDeleted = false,
    this.vlmTags = const [],
    this.jumpMonth,
  });

  ImmichFilter copyWith({
    List<String>? tagIds,
    bool? includeDescendants,
    bool? untagged,
    bool? includeDeleted,
    List<String>? vlmTags,
    DateTime? jumpMonth,
    bool clearMonth = false,
  }) {
    return ImmichFilter(
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
      other is ImmichFilter &&
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

  /// 选中/取消单个 AI 标签（只读数据，仅参与筛选）
  void toggleVlmTag(String tag) {
    final next = [...state.vlmTags];
    if (!next.remove(tag)) next.add(tag);
    state = state.copyWith(vlmTags: next);
  }

  void clearVlmTags() => state = state.copyWith(vlmTags: const []);

  void setJumpMonth(DateTime? month) =>
      state = state.copyWith(jumpMonth: month, clearMonth: month == null);

  void reset() => state = const ImmichFilter();
}

/// 媒体分页数据
class ImmichMediaPage {
  final List<MediaAsset> assets;

  /// media_id → tag ids
  final Map<String, List<String>> tagIdsByMedia;
  final int total;
  final bool loadingMore;
  final int nextOffset;

  ImmichMediaPage({
    required this.assets,
    required this.tagIdsByMedia,
    required this.total,
    this.loadingMore = false,
    int? nextOffset,
  }) : nextOffset = nextOffset ?? assets.length;

  bool get hasMore => nextOffset < total;

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
      nextOffset: nextOffset,
    );
  }
}

const int _kPageSize = 60;

/// AI 标签清单（只读，用于筛选）。
///
/// 依赖稳定，故用普通 Provider 而非代码生成。AI 层未初始化、未连接或尚未产出
/// VLM 标签时返回空列表——页面据此隐藏 AI 标签入口，而不是抛错打断整个相册页。
final immichAiTagsProvider = FutureProvider<List<AiTagCount>>((ref) async {
  try {
    return await ref.watch(aiApiProvider).fetchTags();
  } catch (_) {
    return const <AiTagCount>[];
  }
});

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）
@riverpod
class ImmichMedia extends _$ImmichMedia {
  CancelToken? _request;
  int? _reloadLimit;

  @override
  Future<ImmichMediaPage> build() async {
    final token = _request = CancelToken();
    ref.onDispose(() {
      _request?.cancel();
      _request = null;
    });
    final filter = ref.watch(immichFilterProvider);
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
        ref.read(immichFilterProvider),
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

  Future<ImmichMediaPage> _fetch(
    ImmichFilter filter,
    int offset,
    CancelToken token, {
    ImmichMediaPage? previous,
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
    return ImmichMediaPage(
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
class ImmichSelection extends _$ImmichSelection {
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

typedef ImmichMediaUpdate = ({List<MediaAsset> assets, bool changesVisibility});

@riverpod
class ImmichEdits extends _$ImmichEdits {
  @override
  ({int tagRevision, ImmichMediaUpdate? media}) build() =>
      (tagRevision: 0, media: null);

  void tagsChanged() =>
      state = (tagRevision: state.tagRevision + 1, media: state.media);

  void mediaChanged(ImmichMediaUpdate update) =>
      state = (tagRevision: state.tagRevision, media: update);
}

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）
@riverpod
class ImmichActions extends _$ImmichActions {
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
        final photos = ref.read(immichMediaProvider.notifier);
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
      ref.read(immichEditsProvider.notifier).tagsChanged();
      return null;
    });
  }

  Future<void> setDeleted(List<String> mediaIds, bool deleted) =>
      _patchMedia(mediaIds, MediaPatchIntent(isDeleted: deleted));

  /// 设置备注（空串清空）
  Future<void> setMessage(List<String> mediaIds, String message) =>
      _patchMedia(mediaIds, MediaPatchIntent(message: message));

  /// 捆绑到主文件
  Future<void> bundle(String leadId, List<String> memberIds) =>
      _patchMedia(memberIds, MediaPatchIntent(groupId: leadId));

  /// 解绑
  Future<void> unbundle(List<String> memberIds) =>
      _patchMedia(memberIds, const MediaPatchIntent(clearGroup: true));

  Future<void> _patchMedia(
    List<String> mediaIds,
    MediaPatchIntent intent,
  ) async {
    if (mediaIds.isEmpty) return;
    final db = ref.read(galleryDatabaseProvider);
    await _run((api) async {
      final updated = await retryServerWrite(
        () => api.patchMedia(mediaIds: mediaIds, intent: intent),
      );
      await db.updateMediaAssetsLocal(updated);
      ref.read(immichEditsProvider.notifier).mediaChanged((
        assets: updated,
        changesVisibility: intent.isDeleted != null,
      ));
      return intent.isDeleted == null ? updated : null;
    });
  }
}
