import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/media_providers.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';
import 'package:torrid/features/others/gallery/providers/stats_providers.dart';

part 'tag_providers.g.dart';

// ============ 标签数据 Providers ============

/// 标签树 Provider
@riverpod
class TagTree extends _$TagTree {
  @override
  Future<List<Tag>> build() async {
    final db = ref.watch(galleryDatabaseProvider);
    return await db.getAllTags();
  }

  /// 刷新标签列表
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(galleryDatabaseProvider);
      return await db.getAllTags();
    });
  }

  /// 添加标签
  Future<void> addTag(Tag tag) async {
    final db = ref.read(galleryDatabaseProvider);
    await db.upsertTag(tag);
    await refresh();
  }

  /// 更新标签
  Future<void> updateTag(Tag tag) async {
    final db = ref.read(galleryDatabaseProvider);
    await db.updateTagWithCascade(tag);
    await refresh();
  }

  /// 删除标签
  Future<void> deleteTag(String tagId) async {
    final db = ref.read(galleryDatabaseProvider);
    // 级联清除了关联记录, 返回被删掉的标签 ID (含子孙)
    final removedIds = await db.deleteTag(tagId);
    // 快捷标签里若包含被删除的标签则一并清理
    await ref.read(galleryFavoriteTagIdsProvider.notifier).removeMany(removedIds);
    // 标签删除后级联清除了关联记录，刷新标签指示器与当前媒体标签
    ref.invalidate(mediaIdsWithTagsProvider);
    ref.invalidate(currentMediaTagsProvider);
    await refresh();
  }

  /// 移动标签到新父节点
  Future<void> moveTag(String tagId, String? newParentId) async {
    final allTags = state.valueOrNull ?? [];
    final tag = allTags.firstWhere((t) => t.id == tagId);
    
    // 检查是否会形成循环
    if (newParentId != null && _wouldCreateCycle(tagId, newParentId, allTags)) {
      throw Exception('不能将标签移动到其子标签下');
    }
    
    // 计算新的 full_path
    String newFullPath;
    if (newParentId == null) {
      newFullPath = tag.name;
    } else {
      final parent = allTags.firstWhere((t) => t.id == newParentId);
      newFullPath = '${parent.fullPath}/${tag.name}';
    }
    
    final updatedTag = tag.copyWith(
      parentId: newParentId,
      fullPath: newFullPath,
      clearParentId: newParentId == null,
    );
    
    await updateTag(updatedTag);
  }

  /// 检查是否会形成循环
  bool _wouldCreateCycle(String tagId, String newParentId, List<Tag> allTags) {
    String? currentId = newParentId;
    while (currentId != null) {
      if (currentId == tagId) return true;
      final tag = allTags.firstWhere((t) => t.id == currentId, orElse: () => allTags.first);
      currentId = tag.parentId;
    }
    return false;
  }
}

/// 当前媒体文件的标签 Provider
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
  /// 先用标签树缓存做乐观更新，避免每次勾选都等待数据库往返（影响打标签手感）；
  /// 写库失败则回滚到修改前的状态。
  Future<void> setTags(List<String> tagIds) async {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;

    final db = ref.read(galleryDatabaseProvider);
    final allTags = ref.read(tagTreeProvider).valueOrNull;
    final previous = state;

    // 标签树不可用时无法本地映射，退回"写完再重读"
    final canOptimistic = allTags != null;
    if (canOptimistic) {
      final byId = {for (final t in allTags) t.id: t};
      final mapped = [
        for (final id in tagIds)
          if (byId[id] != null) byId[id]!,
      ]..sort((a, b) =>
          (a.fullPath ?? a.name).compareTo(b.fullPath ?? b.name));
      state = AsyncData(mapped);
    }

    try {
      await db.setTagsForMedia(currentMedia.id, tagIds);
    } catch (e) {
      state = previous;
      rethrow;
    }

    if (!canOptimistic) ref.invalidateSelf();

    // 标签关联变化后刷新标签指示器数据
    ref.invalidate(mediaIdsWithTagsProvider);

    // 更新 modified_count
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final index = assets.indexWhere((a) => a.id == currentMedia.id);
    if (index >= 0) {
      final currentModified = ref.read(galleryModifiedCountProvider);
      if (index > currentModified) {
        await ref.read(galleryModifiedCountProvider.notifier).update(index);
      }
    }
  }

  /// 添加标签
  Future<void> addTag(String tagId) async {
    await _mutate((ids) {
      if (!ids.contains(tagId)) ids.add(tagId);
    });
  }

  /// 移除标签
  Future<void> removeTag(String tagId) async {
    await _mutate((ids) => ids.remove(tagId));
  }

  /// 基于数据库现状做增量修改
  ///
  /// 不能以 [state] 作为增删依据: 切换媒体时 provider 会短暂处于加载态,
  /// 其残留值属于上一张媒体, 据此写回会造成标签串档或丢失.
  Future<void> _mutate(void Function(List<String> tagIds) change) async {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;

    final db = ref.read(galleryDatabaseProvider);
    final tagIds = await db.getTagIdsForMedia(currentMedia.id);
    change(tagIds);
    await setTags(tagIds);
  }
}
