import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';

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

  /// 标记删除，返回刷新后的列表
  Future<List<MediaAsset>> markDeleted(String id, {bool deleted = true}) async {
    final db = ref.read(galleryDatabaseProvider);
    await db.markMediaAssetDeleted(id, deleted: deleted);
    
    // 更新 modified_count
    await _updateModifiedCount(id);
    
    return await refresh();
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
        await ref.read(galleryCurrentIndexProvider.notifier).update(i);
        return true;
      }
    }
    return false;
  }

  /// 跳转到指定位置（直接跳转，不检查删除状态）
  Future<void> jumpTo(int index) async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    if (index >= 0 && index < assets.length) {
      await ref.read(galleryCurrentIndexProvider.notifier).update(index);
    }
  }
  
  /// 跳转到下一个未删除的文件（从当前位置开始查找）
  Future<void> skipToNextNonDeleted() async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final currentIndex = ref.read(galleryCurrentIndexProvider);
    
    if (assets.isEmpty) return;
    
    // 从当前位置向后找
    for (int i = currentIndex; i < assets.length; i++) {
      if (!assets[i].isDeleted) {
        await ref.read(galleryCurrentIndexProvider.notifier).update(i);
        return;
      }
    }
    // 向后没找到，从当前位置向前找
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!assets[i].isDeleted) {
        await ref.read(galleryCurrentIndexProvider.notifier).update(i);
        return;
      }
    }
    // 全部都被删除了，保持当前索引
  }
}
