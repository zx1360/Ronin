import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/media_providers.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';
import 'package:torrid/features/others/gallery/providers/stats_providers.dart';
import 'package:torrid/features/others/gallery/providers/write_buffer_provider.dart';
import 'package:torrid/features/others/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_write_buffer.dart';

part 'tag_providers.g.dart';

// 标签数据 Providers（服务端权威 + 本地缓存）

/// 标签树 Provider
///
/// 读取本地缓存（离线可浏览）; 所有写操作先落服务端, 再把服务端结果写入缓存。
@riverpod
class TagTree extends _$TagTree {
  @override
  Future<List<Tag>> build() async {
    final db = ref.watch(galleryDatabaseProvider);
    return await db.getAllTags();
  }

  /// 重新读取本地缓存（保留服务端同步得到的媒体计数）
  Future<void> refresh() async {
    final db = ref.read(galleryDatabaseProvider);
    final cached = await db.getAllTags();
    final counts = {
      for (final tag in state.valueOrNull ?? const <Tag>[])
        tag.id: tag.mediaCount,
    };
    state = AsyncData([
      for (final tag in cached)
        tag.copyWith(mediaCount: counts[tag.id] ?? 0),
    ]);
  }

  /// 从服务端拉取标签并镜像到本地缓存（标签管理/immich 页进入时调用）
  Future<void> syncFromServer() async {
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    final tags = await retryServerWrite(api.fetchTags);
    await db.syncTagsCache(tags);
    state = AsyncData(tags);
    ref.invalidate(mediaIdsWithTagsProvider);
  }

  /// 新建标签
  Future<Tag> createTag({required String name, String? parentId}) async {
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    final tag = await retryServerWrite(
      () => api.createTag(name: name, parentId: parentId),
    );
    await db.upsertTagLocal(tag);
    await refresh();
    return tag;
  }

  /// 重命名标签（服务端会级联重算子孙 full_path, 因此整表回拉）
  Future<Tag> renameTag(Tag tag, String name) async {
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    final updated = await retryServerWrite(
      () => api.updateTag(tag.id, name: name),
    );
    final tags = await retryServerWrite(api.fetchTags);
    await db.syncTagsCache(tags);
    state = AsyncData(tags);
    return updated;
  }

  /// 移动标签（[newParentId] 为 null 表示移到根级）
  Future<Tag> moveTag(String tagId, String? newParentId) async {
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    final updated = await retryServerWrite(
      () => api.updateTag(
        tagId,
        parentId: newParentId,
        moveToRoot: newParentId == null,
      ),
    );
    final tags = await retryServerWrite(api.fetchTags);
    await db.syncTagsCache(tags);
    state = AsyncData(tags);
    return updated;
  }

  /// 删除标签（服务端级联删除子孙与关联, 本地按服务端返回清理）
  Future<void> deleteTag(String tagId) async {
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    final removedIds = await retryServerWrite(() => api.deleteTag(tagId));
    for (final id in removedIds) {
      await db.deleteTagLocal(id);
    }
    ref.invalidate(mediaIdsWithTagsProvider);
    ref.invalidate(currentMediaTagsProvider);
    await refresh();
  }

  /// 快捷标签开关（乐观更新, 失败回滚）
  Future<void> setFavorite(String tagId, bool value) async {
    final api = ref.read(galleryApiProvider);
    final db = ref.read(galleryDatabaseProvider);
    final current = state.valueOrNull ?? const <Tag>[];

    Tag? target;
    for (final tag in current) {
      if (tag.id == tagId) {
        target = tag;
        break;
      }
    }
    if (target == null || target.isFavorite == value) return;

    final updated = target.copyWith(isFavorite: value);
    state = AsyncData([
      for (final tag in current) tag.id == tagId ? updated : tag,
    ]);
    await db.upsertTagLocal(updated);

    try {
      await retryServerWrite(() => api.updateTag(tagId, isFavorite: value));
    } catch (e) {
      await db.upsertTagLocal(target);
      state = AsyncData(current);
      rethrow;
    }
  }
}

/// 快捷标签（收藏标签, 按路径排序）——浮层右栏 / 快捷选择使用
@riverpod
List<Tag> favoriteTags(FavoriteTagsRef ref) {
  final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
  final favorites = [
    for (final tag in tags)
      if (tag.isFavorite) tag,
  ];
  favorites.sort(
    (a, b) => (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name),
  );
  return favorites;
}

/// 当前媒体文件的标签 Provider（读本地缓存）
@riverpod
class CurrentMediaTags extends _$CurrentMediaTags {
  @override
  Future<List<Tag>> build() async {
    final currentMedia = ref.watch(currentMediaAssetProvider);
    if (currentMedia == null) return [];

    final db = ref.watch(galleryDatabaseProvider);
    return await db.getTagsForMedia(currentMedia.id);
  }

  /// 设置标签（全量覆盖）
  ///
  /// 本地缓存与 UI 立即生效, 服务端推送后台执行（合并 + 重试 + 失败回滚）。
  Future<void> setTags(List<String> tagIds) async {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;

    final db = ref.read(galleryDatabaseProvider);
    final baseline = await db.getTagIdsForMedia(currentMedia.id);
    await _applyLocal(currentMedia.id, tagIds);

    ref.read(galleryWriteBufferProvider).queueTags(
          currentMedia.id,
          tagIds,
          baselineTagIds: baseline,
        );
    ref.invalidate(mediaIdsWithTagsProvider);
    await _bumpModifiedCount(currentMedia.id);
  }

  /// 添加标签
  Future<void> addTag(String tagId) async {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;

    final db = ref.read(galleryDatabaseProvider);
    final tagIds = await db.getTagIdsForMedia(currentMedia.id);
    if (tagIds.contains(tagId)) return;
    tagIds.add(tagId);
    await setTags(tagIds);
  }

  /// 移除标签
  Future<void> removeTag(String tagId) async {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;

    final db = ref.read(galleryDatabaseProvider);
    final tagIds = await db.getTagIdsForMedia(currentMedia.id);
    if (!tagIds.remove(tagId)) return;
    await setTags(tagIds);
  }

  /// 写入本地缓存并同步内存状态（按标签树缓存映射为 Tag 对象）
  Future<void> _applyLocal(String mediaId, List<String> tagIds) async {
    final db = ref.read(galleryDatabaseProvider);
    await db.setTagsForMedia(mediaId, tagIds);

    final allTags = ref.read(tagTreeProvider).valueOrNull;
    if (allTags == null) {
      ref.invalidateSelf();
      return;
    }
    final byId = {for (final tag in allTags) tag.id: tag};
    final mapped = [
      for (final id in tagIds)
        if (byId[id] != null) byId[id]!,
    ]..sort((a, b) => (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name));
    state = AsyncData(mapped);
  }

  /// 记录批次处理游标位置（modified_count）
  Future<void> _bumpModifiedCount(String mediaId) async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final index = assets.indexWhere((a) => a.id == mediaId);
    if (index < 0) return;
    final currentModified = ref.read(galleryModifiedCountProvider);
    if (index > currentModified) {
      await ref.read(galleryModifiedCountProvider.notifier).update(index);
    }
  }
}
