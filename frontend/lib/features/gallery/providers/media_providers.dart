import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/gallery/providers/gallery_write_provider.dart';
import 'package:torrid/features/gallery/providers/service_providers.dart';
import 'package:torrid/features/gallery/providers/settings_providers.dart';

part 'media_providers.g.dart';

// 媒体数据 Providers（服务端权威 + 本地缓存）

/// 媒体文件列表 Provider (按 captured_at 升序, 仅主文件, 包含已删除)
///
/// 本地缓存供离线浏览; 标注修改乐观作用于本地并后台推送服务端。
@riverpod
class MediaAssetList extends _$MediaAssetList {
  @override
  Future<List<MediaAsset>> build() async {
    final db = ref.watch(galleryDatabaseProvider);
    return await db.getMediaAssets(excludeDeleted: false);
  }

  /// 刷新列表，返回刷新后的数据
  Future<List<MediaAsset>> refresh() async {
    final db = ref.read(galleryDatabaseProvider);
    final result = await AsyncValue.guard(
      () => db.getMediaAssets(excludeDeleted: false),
    );
    state = result;
    return result.valueOrNull ?? [];
  }

  /// 单条媒体标注的统一写路径
  ///
  /// 本地缓存立即生效, 服务端经写缓冲合并推送（失败自动回滚）,
  /// 最后刷新列表使界面与本地缓存一致。
  Future<void> applyPatch({
    required String mediaId,
    required MediaPatchIntent intent,
  }) async {
    await ref.read(galleryWriteServiceProvider).patchOne(mediaId, intent);
    await refresh();
  }

  /// 单条标记删除/恢复（乐观更新 + 后台合并推送）
  Future<List<MediaAsset>> markDeleted(String id, {bool deleted = true}) async {
    final currentList = state.valueOrNull ?? [];
    final index = currentList.indexWhere((a) => a.id == id);
    if (index < 0) return currentList;

    final previous = currentList[index];
    state = AsyncData(
      List<MediaAsset>.from(currentList)
        ..[index] = previous.copyWith(isDeleted: deleted),
    );

    await ref
        .read(galleryWriteServiceProvider)
        .patchOne(id, MediaPatchIntent(isDeleted: deleted));
    await bumpModifiedCount(id);
    return state.valueOrNull ?? [];
  }

  /// 批量标记删除/恢复（本地立即生效 + 直推, 失败整体回滚）
  Future<List<MediaAsset>> batchMarkDeleted(
    List<String> ids, {
    bool deleted = true,
  }) async {
    if (ids.isEmpty) return state.valueOrNull ?? [];

    final currentList = state.valueOrNull ?? [];
    state = AsyncData([
      for (final asset in currentList)
        ids.contains(asset.id) ? asset.copyWith(isDeleted: deleted) : asset,
    ]);

    try {
      await ref
          .read(galleryWriteServiceProvider)
          .patchMany(ids, MediaPatchIntent(isDeleted: deleted));
    } catch (_) {
      // 本地缓存已由写入口回滚, 这里只回滚内存状态
      state = AsyncData(currentList);
      rethrow;
    }

    for (final id in ids) {
      await bumpModifiedCount(id);
    }
    return state.valueOrNull ?? [];
  }

  /// 捆绑媒体文件（组成员写入 group_id）
  Future<void> bundleMedia(String leadId, List<String> memberIds) async {
    if (memberIds.isEmpty) return;

    await ref
        .read(galleryWriteServiceProvider)
        .patchMany(memberIds, MediaPatchIntent(groupId: leadId));
    await refresh();
    await bumpModifiedCount(leadId);
  }

  /// 解除捆绑
  Future<void> unbundleMedia(List<String> memberIds) async {
    if (memberIds.isEmpty) return;

    await ref
        .read(galleryWriteServiceProvider)
        .patchMany(memberIds, const MediaPatchIntent(clearGroup: true));
    await refresh();
  }

  /// 更新 modified_count（批次处理游标）
  Future<void> bumpModifiedCount(String mediaId) async {
    final assets = state.valueOrNull ?? [];
    final index = assets.indexWhere((a) => a.id == mediaId);
    if (index < 0) return;
    final currentModified = ref.read(galleryModifiedCountProvider);
    if (index > currentModified) {
      await ref.read(galleryModifiedCountProvider.notifier).update(index);
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

    for (int i = currentIndex + 1; i < assets.length; i++) {
      if (!assets[i].isDeleted) {
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

    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!assets[i].isDeleted) {
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
    if (index == currentIndex) return;

    await _inheritTagsToTarget(currentIndex, index, assets);
    await ref.read(galleryCurrentIndexProvider.notifier).update(index);
  }

  /// 跳转到下一个未删除的文件（从当前位置开始查找）
  Future<void> skipToNextNonDeleted() async {
    final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
    final currentIndex = ref.read(galleryCurrentIndexProvider);

    if (assets.isEmpty) return;

    for (int i = currentIndex; i < assets.length; i++) {
      if (!assets[i].isDeleted) {
        if (i != currentIndex) {
          await _inheritTagsToTarget(currentIndex, i, assets);
        }
        await ref.read(galleryCurrentIndexProvider.notifier).update(i);
        return;
      }
    }
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
  /// 在索引变更**之前**调用, 这样 [currentMediaTagsProvider] 因索引变更而
  /// 重建时, 从本地缓存读取到的就是已经套用后的标签。
  Future<void> _inheritTagsToTarget(
    int fromIndex,
    int toIndex,
    List<MediaAsset> assets,
  ) async {
    if (!ref.read(galleryTagAutoApplyEnabledProvider)) return;

    if (fromIndex < 0 || fromIndex >= assets.length) return;
    if (toIndex < 0 || toIndex >= assets.length) return;
    if (fromIndex == toIndex) return;

    final fromAsset = assets[fromIndex];
    final toAsset = assets[toIndex];

    try {
      final db = ref.read(galleryDatabaseProvider);
      final tagIds = await db.getTagIdsForMedia(fromAsset.id);
      // 本地写入 + 服务端推送都走统一写入口（合并 + 重试 + 失败回滚）
      await ref.read(galleryWriteServiceProvider).setTags(toAsset.id, tagIds);
      await ref
          .read(mediaAssetListProvider.notifier)
          .bumpModifiedCount(toAsset.id);
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

  for (int i = currentIndex + 1; i < assets.length; i++) {
    if (!assets[i].isDeleted) {
      return assets[i];
    }
  }

  return null;
}
