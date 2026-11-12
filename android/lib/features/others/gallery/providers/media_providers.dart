import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';
import 'package:torrid/features/others/gallery/providers/write_buffer_provider.dart';

part 'media_providers.g.dart';

// 组内位置仅在浏览期间保留，批次游标仍按主列表计算。
final galleryActiveGroupProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final galleryGroupIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

final galleryGroupAssetsProvider = StreamProvider.autoDispose
    .family<List<MediaAsset>, String>(
      (ref, leadId) => ref.watch(galleryDatabaseProvider).watchGroup(leadId),
    );
final galleryBrowsingAssetsProvider =
    Provider.autoDispose<AsyncValue<List<MediaAsset>>>((ref) {
      final group = ref.watch(galleryActiveGroupProvider);
      return group == null
          ? ref.watch(mediaAssetListProvider)
          : ref.watch(galleryGroupAssetsProvider(group));
    });

final galleryBrowsingIndexProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(galleryActiveGroupProvider) == null
      ? ref.watch(galleryCurrentIndexProvider)
      : ref.watch(galleryGroupIndexProvider);
});

final mediaGroupSizesProvider = StreamProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(galleryDatabaseProvider).watchGroupSizes(),
);

/// 媒体编辑通过操作表提交，查询流提供工作副本。
@riverpod
class MediaAssetList extends _$MediaAssetList {
  @override
  Stream<List<MediaAsset>> build() =>
      ref.watch(galleryDatabaseProvider).watchMediaAssets();

  Future<void> markDeleted(String id, {bool deleted = true}) =>
      batchMarkDeleted([id], deleted: deleted);

  Future<void> batchMarkDeleted(List<String> ids, {bool deleted = true}) => ref
      .read(galleryWriteBufferProvider)
      .queuePatch(ids, MediaPatchIntent(isDeleted: deleted));

  Future<void> setMessage(MediaAsset target, String message) => ref
      .read(galleryWriteBufferProvider)
      .queuePatch([target.id], MediaPatchIntent(message: message));

  Future<void> setEditParams(MediaAsset target, String? params) =>
      ref.read(galleryWriteBufferProvider).queuePatch(
        [target.id],
        params == null || params.isEmpty
            ? const MediaPatchIntent(clearEditParams: true)
            : MediaPatchIntent(editParams: params),
      );

  Future<void> bundleMedia(String leadId, List<String> memberIds) => ref
      .read(galleryWriteBufferProvider)
      .queuePatch(memberIds, MediaPatchIntent(groupId: leadId));

  Future<void> unbundleMedia(List<String> memberIds) => ref
      .read(galleryWriteBufferProvider)
      .queuePatch(memberIds, const MediaPatchIntent(clearGroup: true));
}

/// 当前媒体文件 Provider
/// 如果当前索引指向已删除文件，返回该文件（让 UI 层处理跳过逻辑）
@riverpod
class CurrentMediaAsset extends _$CurrentMediaAsset {
  @override
  MediaAsset? build() {
    final assets = ref.watch(galleryBrowsingAssetsProvider).value ?? [];
    final index = ref.watch(galleryBrowsingIndexProvider);

    if (assets.isEmpty || index < 0 || index >= assets.length) {
      return null;
    }
    return assets[index];
  }

  Future<void> _updateIndex(int index) async {
    if (ref.read(galleryActiveGroupProvider) == null) {
      await ref.read(galleryCurrentIndexProvider.notifier).update(index);
    } else {
      ref.read(galleryGroupIndexProvider.notifier).state = index;
    }
  }

  Future<void> browseGroup(MediaAsset asset) async {
    final leadId = asset.groupId ?? asset.id;
    final db = ref.read(galleryDatabaseProvider);
    final lead = await db.getMediaAssetById(leadId);
    final members = await db.getGroupMembers(leadId);
    if (members.isEmpty) return;
    final group = [if (lead != null) lead, ...members];
    final index = group.indexWhere((a) => a.id == asset.id);
    ref.read(galleryGroupIndexProvider.notifier).state = index < 0 ? 0 : index;
    ref.read(galleryActiveGroupProvider.notifier).state = leadId;
  }

  void closeGroup() {
    ref.read(galleryActiveGroupProvider.notifier).state = null;
  }

  /// 前进到下一个未删除的文件
  Future<bool> next() async {
    final assets = ref.read(galleryBrowsingAssetsProvider).value ?? [];
    final currentIndex = ref.read(galleryBrowsingIndexProvider);

    for (int i = currentIndex + 1; i < assets.length; i++) {
      if (!assets[i].isDeleted) {
        await _inheritTagsToTarget(currentIndex, i, assets);
        await _updateIndex(i);
        return true;
      }
    }
    return false;
  }

  /// 返回上一个未删除的文件
  Future<bool> previous() async {
    final assets = ref.read(galleryBrowsingAssetsProvider).value ?? [];
    final currentIndex = ref.read(galleryBrowsingIndexProvider);

    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!assets[i].isDeleted) {
        await _inheritTagsToTarget(currentIndex, i, assets);
        await _updateIndex(i);
        return true;
      }
    }
    return false;
  }

  /// 跳转到指定位置（直接跳转，不检查删除状态）
  Future<void> jumpTo(int index) async {
    final assets = ref.read(galleryBrowsingAssetsProvider).value ?? [];
    if (index < 0 || index >= assets.length) return;

    final currentIndex = ref.read(galleryBrowsingIndexProvider);
    if (index == currentIndex) return;

    await _inheritTagsToTarget(currentIndex, index, assets);
    await _updateIndex(index);
  }

  /// 跳转到下一个未删除的文件（从当前位置开始查找）
  Future<void> skipToNextNonDeleted() async {
    final assets = ref.read(galleryBrowsingAssetsProvider).value ?? [];
    final currentIndex = ref.read(galleryBrowsingIndexProvider);

    if (assets.isEmpty) return;

    for (int i = currentIndex; i < assets.length; i++) {
      if (!assets[i].isDeleted) {
        if (i != currentIndex) {
          await _inheritTagsToTarget(currentIndex, i, assets);
        }
        await _updateIndex(i);
        return;
      }
    }
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!assets[i].isDeleted) {
        await _inheritTagsToTarget(currentIndex, i, assets);
        await _updateIndex(i);
        return;
      }
    }
    // 全部都被删除了，保持当前索引
  }

  /// 标签自动套用：先落盘，再更新浏览位置。
  Future<void> _inheritTagsToTarget(
    int fromIndex,
    int toIndex,
    List<MediaAsset> assets,
  ) async {
    if (ref.read(galleryActiveGroupProvider) != null) return;
    if (!ref.read(galleryTagAutoApplyEnabledProvider)) return;

    if (fromIndex < 0 || fromIndex >= assets.length) return;
    if (toIndex < 0 || toIndex >= assets.length) return;
    if (fromIndex == toIndex) return;

    final fromAsset = assets[fromIndex];
    final toAsset = assets[toIndex];

    try {
      final db = ref.read(galleryDatabaseProvider);
      final buffer = ref.read(galleryWriteBufferProvider);
      final tagIds = await db.getTagIdsForMedia(fromAsset.id);
      await buffer.queueTags(toAsset.id, tagIds);
    } catch (error) {
      ref.read(galleryWriteStatusProvider.notifier).report('标签套用未保存：$error');
      rethrow;
    }
  }
}

/// 下一个未删除的媒体文件 Provider（用于预览小窗）
/// 如果不存在下一个文件，返回 null
@riverpod
MediaAsset? nextMediaAsset(Ref ref) {
  final assets = ref.watch(galleryBrowsingAssetsProvider).value ?? [];
  final currentIndex = ref.watch(galleryBrowsingIndexProvider);

  if (assets.isEmpty || currentIndex < 0) {
    return null;
  }

  for (int i = currentIndex + 1; i < assets.length; i++) {
    if (!assets[i].isDeleted) {
      return assets[i];
    }
  }

  return null;
}
