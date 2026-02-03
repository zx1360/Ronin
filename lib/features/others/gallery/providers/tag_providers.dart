import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/providers/media_providers.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';

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
    await db.deleteTag(tagId);
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

  /// 设置标签
  Future<void> setTags(List<String> tagIds) async {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;
    
    final db = ref.read(galleryDatabaseProvider);
    await db.setTagsForMedia(currentMedia.id, tagIds);
    
    // 更新 modified_count
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final index = assets.indexWhere((a) => a.id == currentMedia.id);
    if (index >= 0) {
      final currentModified = ref.read(galleryModifiedCountProvider);
      if (index > currentModified) {
        await ref.read(galleryModifiedCountProvider.notifier).update(index);
      }
    }
    
    ref.invalidateSelf();
  }

  /// 添加标签
  Future<void> addTag(String tagId) async {
    final currentTags = state.valueOrNull ?? [];
    final tagIds = currentTags.map((t) => t.id).toList();
    if (!tagIds.contains(tagId)) {
      tagIds.add(tagId);
      await setTags(tagIds);
    }
  }

  /// 移除标签
  Future<void> removeTag(String tagId) async {
    final currentTags = state.valueOrNull ?? [];
    final tagIds = currentTags.map((t) => t.id).where((id) => id != tagId).toList();
    await setTags(tagIds);
  }
}
