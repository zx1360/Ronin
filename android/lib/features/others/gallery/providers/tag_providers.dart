import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/models/tag_tree.dart';
import 'package:torrid/features/others/gallery/providers/media_providers.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/write_buffer_provider.dart';
import 'package:torrid/features/others/gallery/services/gallery_write_buffer.dart';

part 'tag_providers.g.dart';

// 标签数据 Providers（服务端权威 + 本地缓存）

/// 标签树 Provider
///
/// Gallery 使用离线工作副本；在线相册写入前先确认待回传操作。
@riverpod
class TagTree extends _$TagTree {
  @override
  Stream<List<Tag>> build() => ref.watch(galleryDatabaseProvider).watchTags();

  /// 从服务端拉取标签并镜像到本地缓存（标签管理/immich 页进入时调用）
  Future<void> syncFromServer() async {
    await ref.read(galleryWriteBufferProvider).writeOnline((api) async {
      final db = ref.read(galleryDatabaseProvider);
      final tags = await retryServerWrite(api.fetchTags);
      await db.syncTagsCache(tags);
    });
  }

  /// 新建标签
  Future<Tag> createTag({
    required String name,
    String? parentId,
    bool localFirst = false,
  }) async {
    if (localFirst) {
      final id = const Uuid().v4();
      await ref.read(galleryWriteBufferProvider).queue('tagCreate', {
        'id': id,
        'name': name.trim(),
        'parent_id': parentId,
      });

      return (await ref.read(galleryDatabaseProvider).getTag(id))!;
    }
    return ref.read(galleryWriteBufferProvider).writeOnline((api) async {
      final db = ref.read(galleryDatabaseProvider);
      final tag = await retryServerWrite(
        () => api.createTag(name: name, parentId: parentId),
      );
      await db.upsertTagLocal(tag);

      return tag;
    });
  }

  /// 重命名标签（服务端会级联重算子孙 full_path, 因此整表回拉）
  Future<Tag> renameTag(Tag tag, String name, {bool localFirst = false}) async {
    if (localFirst) return _editLocal(tag.id, {'name': name.trim()});
    return ref.read(galleryWriteBufferProvider).writeOnline((api) async {
      final db = ref.read(galleryDatabaseProvider);
      final updated = await retryServerWrite(
        () => api.updateTag(tag.id, name: name),
      );
      final tags = await retryServerWrite(api.fetchTags);
      await db.syncTagsCache(tags, preserveOperations: false);

      return updated;
    });
  }

  /// 移动标签（[newParentId] 为 null 表示移到根级）
  Future<Tag> moveTag(
    String tagId,
    String? newParentId, {
    bool localFirst = false,
  }) async {
    if (localFirst) return _editLocal(tagId, {'parent_id': newParentId});
    return ref.read(galleryWriteBufferProvider).writeOnline((api) async {
      final db = ref.read(galleryDatabaseProvider);
      final updated = await retryServerWrite(
        () => api.updateTag(
          tagId,
          parentId: newParentId,
          moveToRoot: newParentId == null,
        ),
      );
      final tags = await retryServerWrite(api.fetchTags);
      await db.syncTagsCache(tags, preserveOperations: false);

      return updated;
    });
  }

  /// 删除标签（服务端级联删除子孙与关联, 本地按服务端返回清理）
  Future<void> deleteTag(String tagId, {bool localFirst = false}) async {
    if (localFirst) {
      await ref.read(galleryWriteBufferProvider).queue('tagDelete', {
        'id': tagId,
      });

      return;
    }
    return ref.read(galleryWriteBufferProvider).writeOnline((api) async {
      final db = ref.read(galleryDatabaseProvider);
      final removedIds = await retryServerWrite(() => api.deleteTag(tagId));
      await db.deleteTagsLocal(removedIds);
    });
  }

  /// 快捷标签开关；在线相册失败时回滚。
  Future<void> setFavorite(
    String tagId,
    bool value, {
    bool localFirst = false,
  }) async {
    if (localFirst) {
      await _editLocal(tagId, {'is_favorite': value});
      return;
    }
    return ref.read(galleryWriteBufferProvider).writeOnline((api) async {
      final db = ref.read(galleryDatabaseProvider);
      final target = await db.getTag(tagId);
      if (target == null || target.isFavorite == value) return;

      final updated = target.copyWith(isFavorite: value);
      await db.upsertTagLocal(updated);

      try {
        await retryServerWrite(() => api.updateTag(tagId, isFavorite: value));
      } catch (e) {
        await db.upsertTagLocal(target);
        rethrow;
      }
    });
  }

  Future<Tag> _editLocal(String id, Map<String, dynamic> fields) async {
    await ref.read(galleryWriteBufferProvider).queue('tagUpdate', {
      'id': id,
      ...fields,
    });

    return (await ref.read(galleryDatabaseProvider).getTag(id))!;
  }
}

/// 快捷标签（收藏标签，按绑定媒体数降序）
@riverpod
List<Tag> favoriteTags(Ref ref) {
  final tags = ref.watch(tagTreeProvider).value ?? const <Tag>[];
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
  Stream<List<Tag>> build() {
    final id = ref.watch(
      currentMediaAssetProvider.select((asset) => asset?.id),
    );
    final db = ref.watch(galleryDatabaseProvider);
    return id == null ? Stream.value(const []) : db.watchTagsForMedia(id);
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
      await buffer.queueTags(mediaId, tagIds);
    });
    _updates = pending.then((_) {}, onError: (Object _) {});
    return pending.whenComplete(keepAlive.close);
  }
}
