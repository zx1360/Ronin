import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';
import 'package:torrid/features/others/gallery/providers/stats_providers.dart';

part 'media_providers.g.dart';

// ============ 媒体数据 Providers ============

/// 媒体文件列表 Provider (按 captured_at 升序, 仅主文件, 包含已删除)
/// 统一使用这个列表，索引保持稳定
@riverpod
class MediaAssetList extends _$MediaAssetList {
  @override
  Future<List<MediaAsset>> build() async {
    final db = ref.watch(galleryDatabaseProvider);
    return await db.getMediaAssets(excludeDeleted: false);
  }

  /// 刷新列表，返回刷新后的数据
  Future<List<MediaAsset>> refresh() async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final db = ref.read(galleryDatabaseProvider);
      return await db.getMediaAssets(excludeDeleted: false);
    });
    state = result;
    return result.valueOrNull ?? [];
  }

  /// 标记删除（乐观更新，无加载状态）
  Future<List<MediaAsset>> markDeleted(String id, {bool deleted = true}) async {
    // 1. 乐观更新：立即更新本地状态，避免 loading 闪烁
    final currentList = state.valueOrNull ?? [];
    final index = currentList.indexWhere((a) => a.id == id);
    if (index >= 0) {
      final updatedList = List<MediaAsset>.from(currentList);
      updatedList[index] = currentList[index].copyWith(isDeleted: deleted);
      state = AsyncValue.data(updatedList);
    }
    
    // 2. 后台执行数据库操作
    final db = ref.read(galleryDatabaseProvider);
    await db.markMediaAssetDeleted(id, deleted: deleted);
    
    // 3. 更新 modified_count
    await _updateModifiedCount(id);
    
    // 4. 静默刷新确保数据一致性（可选，如果数据库和本地状态已保持同步可以省略）
    return state.valueOrNull ?? [];
  }

  /// 批量标记删除/恢复（先写数据库，再一次性刷新 UI）
  Future<List<MediaAsset>> batchMarkDeleted(List<String> ids, {bool deleted = true}) async {
    if (ids.isEmpty) return state.valueOrNull ?? [];

    final db = ref.read(galleryDatabaseProvider);

    // 1. 先写数据库（单次批量事务）
    await db.batchMarkMediaAssetDeleted(ids, deleted: deleted);

    // 2. 更新 modified_count（取最大索引）
    int maxIdx = -1;
    final currentList = state.valueOrNull ?? [];
    for (final id in ids) {
      final idx = currentList.indexWhere((a) => a.id == id);
      if (idx > maxIdx) maxIdx = idx;
    }
    if (maxIdx >= 0) {
      final currentModified = ref.read(galleryModifiedCountProvider);
      if (maxIdx > currentModified) {
        await ref.read(galleryModifiedCountProvider.notifier).update(maxIdx);
      }
    }

    // 3. 一次性从数据库刷新 UI
    await refresh();
    return state.valueOrNull ?? [];
  }

  /// 捆绑媒体文件
  Future<void> bundleMedia(String leadId, List<String> memberIds) async {
    final db = ref.read(galleryDatabaseProvider);
    await db.setMediaGroupId(memberIds, leadId);
    
    // 更新 modified_count
    await _updateModifiedCount(leadId);
    
    await refresh();
  }

  /// 解除捆绑
  Future<void> unbundleMedia(List<String> memberIds) async {
    final db = ref.read(galleryDatabaseProvider);
    await db.setMediaGroupId(memberIds, null);
    await refresh();
  }

  /// 更新 modified_count
  Future<void> _updateModifiedCount(String mediaId) async {
    final assets = state.valueOrNull ?? [];
    final index = assets.indexWhere((a) => a.id == mediaId);
    if (index >= 0) {
      final currentModified = ref.read(galleryModifiedCountProvider);
      if (index > currentModified) {
        await ref.read(galleryModifiedCountProvider.notifier).update(index);
      }
    }
  }
}

/// 当前媒体文件 Provider
/// 如果当前索引指向已删除文件，返回该文件（让 UI 层处理跳过逻辑）
@riverpod
class CurrentMediaAsset extends _$CurrentMediaAsset {
  @override
  MediaAsset? build() {
    final assets = ref.watch(mediaAssetListProvider).valueOrNull ?? [];
    final index = ref.watch(galleryCurrentIndexProvider);
    
    if (assets.isEmpty || index < 0 || index >= assets.length) {
      return null;
    }
    return assets[index];
  }

  /// 前进到下一个未删除的文件
  Future<bool> next() async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final currentIndex = ref.read(galleryCurrentIndexProvider);
    
    // 找下一个未删除的
    for (int i = currentIndex + 1; i < assets.length; i++) {
      if (!assets[i].isDeleted) {
        // 标签自动套用：在新媒体成为"当前"之前，先将当前媒体的标签写入目标
        await _inheritTagsToTarget(currentIndex, i, assets);
        await ref.read(galleryCurrentIndexProvider.notifier).update(i);
        return true;
      }
    }
    return false;
  }

  /// 返回上一个未删除的文件
  Future<bool> previous() async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final currentIndex = ref.read(galleryCurrentIndexProvider);
    
    // 找上一个未删除的
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!assets[i].isDeleted) {
        // 标签自动套用：在新媒体成为"当前"之前，先将当前媒体的标签写入目标
        await _inheritTagsToTarget(currentIndex, i, assets);
        await ref.read(galleryCurrentIndexProvider.notifier).update(i);
        return true;
      }
    }
    return false;
  }

  /// 跳转到指定位置（直接跳转，不检查删除状态）
  Future<void> jumpTo(int index) async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    if (index < 0 || index >= assets.length) return;
    
    final currentIndex = ref.read(galleryCurrentIndexProvider);
    
    // 如果跳转到当前位置，不执行任何操作（防止重复套用标签）
    if (index == currentIndex) return;
    
    // 标签自动套用：在新媒体成为"当前"之前，先将当前媒体的标签写入目标
    await _inheritTagsToTarget(currentIndex, index, assets);
    await ref.read(galleryCurrentIndexProvider.notifier).update(index);
  }
  
  /// 跳转到下一个未删除的文件（从当前位置开始查找）
  Future<void> skipToNextNonDeleted() async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final currentIndex = ref.read(galleryCurrentIndexProvider);
    
    if (assets.isEmpty) return;
    
    // 从当前位置向后找
    for (int i = currentIndex; i < assets.length; i++) {
      if (!assets[i].isDeleted) {
        if (i != currentIndex) {
          await _inheritTagsToTarget(currentIndex, i, assets);
        }
        await ref.read(galleryCurrentIndexProvider.notifier).update(i);
        return;
      }
    }
    // 向后没找到，从当前位置向前找
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!assets[i].isDeleted) {
        await _inheritTagsToTarget(currentIndex, i, assets);
        await ref.read(galleryCurrentIndexProvider.notifier).update(i);
        return;
      }
    }
    // 全部都被删除了，保持当前索引
  }

  /// 标签自动套用：将当前媒体的标签写入目标媒体
  /// 
  /// 在索引变更**之前**调用，这样 [currentMediaTagsProvider] 因索引变更而
  /// 重建时，从数据库读取到的就是已经套用后的标签。
  Future<void> _inheritTagsToTarget(int fromIndex, int toIndex, List<MediaAsset> assets) async {
    // 检查功能是否开启
    final tagAutoApply = ref.read(galleryTagAutoApplyEnabledProvider);
    if (!tagAutoApply) return;
    
    // 索引越界保护
    if (fromIndex < 0 || fromIndex >= assets.length) return;
    if (toIndex < 0 || toIndex >= assets.length) return;
    
    // 同一文件不套用
    if (fromIndex == toIndex) return;
    
    final fromAsset = assets[fromIndex];
    final toAsset = assets[toIndex];
    
    try {
      final db = ref.read(galleryDatabaseProvider);
      // 获取当前媒体的标签 ID
      final tagIds = await db.getTagIdsForMedia(fromAsset.id);
      // 写入目标媒体（全量替换）
      await db.setTagsForMedia(toAsset.id, tagIds);
      
      // 标签关联变化后刷新标签指示器数据
      ref.invalidate(mediaIdsWithTagsProvider);
      
      // 更新 modified_count
      final currentModified = ref.read(galleryModifiedCountProvider);
      if (toIndex > currentModified) {
        await ref.read(galleryModifiedCountProvider.notifier).update(toIndex);
      }
    } catch (_) {
      // 标签套用失败时静默处理，不阻塞导航
    }
  }
}

/// 下一个未删除的媒体文件 Provider（用于预览小窗）
/// 如果不存在下一个文件，返回 null
@riverpod
MediaAsset? nextMediaAsset(NextMediaAssetRef ref) {
  final assets = ref.watch(mediaAssetListProvider).valueOrNull ?? [];
  final currentIndex = ref.watch(galleryCurrentIndexProvider);
  
  if (assets.isEmpty || currentIndex < 0) {
    return null;
  }
  
  // 从当前位置+1 向后查找未删除的文件
  for (int i = currentIndex + 1; i < assets.length; i++) {
    if (!assets[i].isDeleted) {
      return assets[i];
    }
  }
  
  return null;
}
