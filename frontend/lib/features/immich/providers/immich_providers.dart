import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/ai/models/ai_search_models.dart';
import 'package:torrid/features/ai/services/ai_api_service.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/gallery/services/gallery_write_service.dart';
import 'package:torrid/features/gallery/services/media_pagination.dart';

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

  const ImmichFilter({
    this.tagIds = const [],
    this.includeDescendants = true,
    this.untagged = false,
    this.includeDeleted = false,
    this.vlmTags = const [],
  });

  ImmichFilter copyWith({
    List<String>? tagIds,
    bool? includeDescendants,
    bool? untagged,
    bool? includeDeleted,
    List<String>? vlmTags,
  }) {
    return ImmichFilter(
      tagIds: tagIds ?? this.tagIds,
      includeDescendants: includeDescendants ?? this.includeDescendants,
      untagged: untagged ?? this.untagged,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      vlmTags: vlmTags ?? this.vlmTags,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImmichFilter &&
      other.untagged == untagged &&
      other.includeDeleted == includeDeleted &&
      other.includeDescendants == includeDescendants &&
      other.tagIds.length == tagIds.length &&
      other.tagIds.every(tagIds.contains) &&
      other.vlmTags.length == vlmTags.length &&
      other.vlmTags.every(vlmTags.contains);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(tagIds),
        includeDescendants,
        untagged,
        includeDeleted,
        Object.hashAll(vlmTags),
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

  void reset() => state = const ImmichFilter();
}

/// 媒体分页数据
class ImmichMediaPage {
  final List<MediaAsset> assets;

  /// media_id → tag ids
  final Map<String, List<String>> tagIdsByMedia;
  final int total;

  /// 是否还有下一页（由 [MediaPager] 按"已加载 / 总数"给出）
  final bool hasMore;
  final bool loadingMore;

  const ImmichMediaPage({
    required this.assets,
    required this.tagIdsByMedia,
    required this.total,
    required this.hasMore,
    this.loadingMore = false,
  });

  ImmichMediaPage copyWith({
    List<MediaAsset>? assets,
    Map<String, List<String>>? tagIdsByMedia,
    int? total,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return ImmichMediaPage(
      assets: assets ?? this.assets,
      tagIdsByMedia: tagIdsByMedia ?? this.tagIdsByMedia,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

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

/// 单个媒体的人工标签 id（详情弹窗用）
///
/// 列表已覆盖该媒体时直接用列表结果（跨页累积），否则兜底查询一次服务端，
/// 使多页刷新后详情弹窗仍能显示正确的标签。
final immichMediaTagIdsProvider =
    FutureProvider.family<List<String>, String>((ref, mediaId) async {
  final page = ref.watch(immichMediaProvider).valueOrNull;
  final fromList = page?.tagIdsByMedia[mediaId];
  if (fromList != null) return fromList;

  try {
    final result = await ref.read(galleryApiProvider).queryMedia(
          ids: [mediaId],
          includeDeleted: true,
          limit: 1,
        );
    return [
      for (final link in result.mediaTagLinks)
        if (link.mediaId == mediaId) link.tagId,
    ];
  } catch (_) {
    return const <String>[]; // 拉取失败时按"无标签"展示, 不打断弹窗
  }
});

/// 单个媒体的 AI 分析结果；AI 层未初始化或离线时返回 null（页面整块不展示）
final immichMediaAiDetailProvider =
    FutureProvider.family<AiMediaDetail?, String>((ref, mediaId) async {
  try {
    return await ref.read(aiApiProvider).fetchMediaDetail(mediaId);
  } catch (_) {
    return null;
  }
});

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）
@riverpod
class ImmichMedia extends _$ImmichMedia {
  /// 分页游标: 页大小 / 是否还有更多 / 下一页起点 / 去重追加与画廊共用同一套规则
  final _pager = MediaPager();

  /// media_id → tag ids（跨页累积）
  final _tagIdsByMedia = <String, List<String>>{};

  @override
  Future<ImmichMediaPage> build() async {
    final filter = ref.watch(immichFilterNotifierProvider);
    _pager.reset();
    _tagIdsByMedia.clear();
    return _fetch(filter);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      state = AsyncData(await _fetch(ref.read(immichFilterNotifierProvider)));
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
    final loaded = _pager.offset;
    final filter = ref.read(immichFilterNotifierProvider);
    _pager.reset();
    _tagIdsByMedia.clear();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        filter,
        limit: loaded.clamp(MediaPager.defaultPageSize, 1000),
      ),
    );
  }

  Future<ImmichMediaPage> _fetch(ImmichFilter filter, {int? limit}) async {
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);

    final result = await api.queryMedia(
      tagIds: filter.tagIds,
      includeDescendants: filter.includeDescendants,
      untagged: filter.untagged,
      includeDeleted: filter.includeDeleted,
      vlmTags: filter.vlmTags,
      limit: limit ?? _pager.pageSize,
      offset: _pager.offset,
    );

    // 写回本地缓存（仅更新已缓存的行, 保持画廊页一致）
    await db.updateMediaAssetsLocal(result.mediaAssets);

    _pager.add(result.mediaAssets, total: result.total);
    for (final link in result.mediaTagLinks) {
      final tagIds = _tagIdsByMedia.putIfAbsent(link.mediaId, () => []);
      if (!tagIds.contains(link.tagId)) tagIds.add(link.tagId);
    }
    await db.replaceTagsForMediaBatch(_tagIdsByMedia);

    return ImmichMediaPage(
      assets: _pager.items,
      tagIdsByMedia: _tagIdsByMedia,
      total: _pager.total,
      hasMore: _pager.hasMore,
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

  void clear() => state = {};
}

/// 批量操作状态与动作（走统一写入口: 本地立即生效 + 直推重试 + 失败回滚）
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
      // 标签计数需要服务端重算（失败不影响已完成的写操作）
      try {
        await ref.read(tagTreeProvider.notifier).syncFromServer();
      } catch (_) {}
      return result;
    } finally {
      state = false;
    }
  }

  GalleryWriteService get _write => ref.read(galleryWriteServiceProvider);

  /// 批量加标签
  Future<void> addTags(List<String> mediaIds, List<String> tagIds) async {
    if (mediaIds.isEmpty || tagIds.isEmpty) return;
    await _run(() => _write.addTagLinks(mediaIds, tagIds));
  }

  /// 批量移除标签
  Future<void> removeTags(List<String> mediaIds, List<String> tagIds) async {
    if (mediaIds.isEmpty || tagIds.isEmpty) return;
    await _run(() => _write.removeTagLinks(mediaIds, tagIds));
  }

  /// 软删除/恢复
  Future<void> setDeleted(List<String> mediaIds, bool deleted) async {
    if (mediaIds.isEmpty) return;
    await _run(
      () => _write.patchMany(mediaIds, MediaPatchIntent(isDeleted: deleted)),
    );
  }

  /// 设置备注（空串清空）
  Future<void> setMessage(List<String> mediaIds, String message) async {
    if (mediaIds.isEmpty) return;
    await _run(
      () => _write.patchMany(mediaIds, MediaPatchIntent(message: message)),
    );
  }

  /// 捆绑到主文件
  Future<void> bundle(String leadId, List<String> memberIds) async {
    if (memberIds.isEmpty) return;
    await _run(
      () => _write.patchMany(memberIds, MediaPatchIntent(groupId: leadId)),
    );
  }

  /// 解绑
  Future<void> unbundle(List<String> memberIds) async {
    if (memberIds.isEmpty) return;
    await _run(
      () => _write.patchMany(memberIds, const MediaPatchIntent(clearGroup: true)),
    );
  }
}
