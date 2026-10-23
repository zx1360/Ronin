import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/models/tag_tree.dart';
import 'package:torrid/features/others/gallery/providers/media_providers.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
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
    state = AsyncData(cached);
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

/// 快捷标签（收藏标签，按绑定媒体数降序）
@riverpod
List<Tag> favoriteTags(FavoriteTagsRef ref) {
  final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
  final favorites = [
    for (final tag in tags)
      if (tag.isFavorite) tag,
  ];
  favorites.sort(compareTagsByMediaCount);
  return favorites;
}

/// 当前媒体文件的标签 Provider（读本地缓存）
@riverpod
class CurrentMediaTags extends _$CurrentMediaTags {
  Future<void> _updates = Future.value();

  @override
  Future<List<Tag>> build() async {
    final currentMedia = ref.watch(currentMediaAssetProvider);
    if (currentMedia == null) return [];

    final db = ref.watch(galleryDatabaseProvider);
    return await db.getTagsForMedia(currentMedia.id);
  }

  Future<void> setTags(List<String> tagIds) {
    final snapshot = tagIds.toSet();
    return _update((_) => snapshot);
  }

  Future<void> toggleTag(String tagId) => _update((ids) {
    if (!ids.remove(tagId)) ids.add(tagId);
    return ids;
  });

  // 串行读改写，并在排队前固定媒体，避免连续点选或翻页时覆盖标签。
  Future<void> _update(Set<String> Function(Set<String>) change) {
    final container = ref.container;
    final mediaId = container.read(currentMediaAssetProvider)?.id;
    if (mediaId == null) return Future.value();
    final keepAlive = ref.keepAlive();
    final db = container.read(galleryDatabaseProvider);
    final buffer = container.read(galleryWriteBufferProvider);
    final pending = _updates.then((_) async {
      final baseline = await db.getTagIdsForMedia(mediaId);
      final next = change(baseline.toSet());
      if (setEquals(baseline.toSet(), next)) return;
      final tagIds = next.toList();
      await db.setTagsForMedia(mediaId, tagIds);
      buffer.queueTags(mediaId, tagIds, baselineTagIds: baseline);
      if (container.read(currentMediaAssetProvider)?.id == mediaId) {
        container.invalidate(currentMediaTagsProvider);
      }
      container.invalidate(mediaIdsWithTagsProvider);
      await container
          .read(mediaAssetListProvider.notifier)
          .bumpModifiedCount(mediaId);
    });
    _updates = pending.then((_) {}, onError: (Object _) {});
    return pending.whenComplete(keepAlive.close);
  }
}
