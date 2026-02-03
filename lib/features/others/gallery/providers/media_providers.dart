import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';

part 'media_providers.g.dart';

// ============ 媒体数据 Providers ============

/// 媒体文件列表 Provider (按 captured_at 升序, 仅主文件)
@riverpod
class MediaAssetList extends _$MediaAssetList {
  @override
  Future<List<MediaAsset>> build() async {
    final db = ref.watch(galleryDatabaseProvider);
    return await db.getMediaAssets();
  }

  /// 刷新列表
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(galleryDatabaseProvider);
      return await db.getMediaAssets();
    });
  }

  /// 标记删除
  Future<void> markDeleted(String id, {bool deleted = true}) async {
    final db = ref.read(galleryDatabaseProvider);
    await db.markMediaAssetDeleted(id, deleted: deleted);
    
    // 更新 modified_count
    await _updateModifiedCount(id);
    
    await refresh();
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

  /// 前进到下一个
  Future<bool> next() async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final currentIndex = ref.read(galleryCurrentIndexProvider);
    
    if (currentIndex < assets.length - 1) {
      await ref.read(galleryCurrentIndexProvider.notifier).update(currentIndex + 1);
      return true;
    }
    return false;
  }

  /// 返回上一个
  Future<bool> previous() async {
    final currentIndex = ref.read(galleryCurrentIndexProvider);
    
    if (currentIndex > 0) {
      await ref.read(galleryCurrentIndexProvider.notifier).update(currentIndex - 1);
      return true;
    }
    return false;
  }

  /// 跳转到指定位置
  Future<void> jumpTo(int index) async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    if (index >= 0 && index < assets.length) {
      await ref.read(galleryCurrentIndexProvider.notifier).update(index);
    }
  }
}
