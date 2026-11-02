import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';
import 'package:torrid/features/others/gallery/providers/stats_providers.dart';
import 'package:torrid/features/others/gallery/providers/write_buffer_provider.dart';

part 'media_providers.g.dart';

final mediaGroupSizesProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) async {
  final db = ref.watch(galleryDatabaseProvider);
  await ref.watch(mediaAssetListProvider.future);
  return db.getGroupSizes();
});

// 媒体数据 Providers（服务端权威 + 本地缓存）

/// 媒体文件列表 Provider (按 captured_at 升序, 仅主文件, 包含已删除)
///
/// 读取持久工作副本；媒体编辑经操作表回传服务端。
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

  /// 单条标记删除/恢复，同时处理组成员。
  Future<List<MediaAsset>> markDeleted(String id, {bool deleted = true}) async {
    await ref.read(galleryWriteBufferProvider).queuePatch([
      id,
    ], MediaPatchIntent(isDeleted: deleted));
    await refresh();
    await bumpModifiedCount(id);
    return state.valueOrNull ?? [];
  }

  /// 整批操作与本地状态在同一事务提交。
  Future<List<MediaAsset>> batchMarkDeleted(
    List<String> ids, {
    bool deleted = true,
  }) async {
    if (ids.isEmpty) return state.valueOrNull ?? [];
    await ref
        .read(galleryWriteBufferProvider)
        .queuePatch(ids, MediaPatchIntent(isDeleted: deleted));
    ref.invalidate(mediaIdsWithTagsProvider);
    await refresh();
    for (final id in ids) {
      await bumpModifiedCount(id);
    }
    return state.valueOrNull ?? [];
  }

  /// 空串清空备注。
  Future<void> setMessage(MediaAsset target, String message) =>
      _applyLocalAndQueue(target, MediaPatchIntent(message: message));

  Future<void> setEditParams(MediaAsset target, String? params) =>
      _applyLocalAndQueue(
        target,
        params == null || params.isEmpty
            ? const MediaPatchIntent(clearEditParams: true)
            : MediaPatchIntent(editParams: params),
      );

  /// 本地提交完成后更新界面。
  Future<void> _applyLocalAndQueue(
    MediaAsset target,
    MediaPatchIntent intent,
  ) async {
    await ref.read(galleryWriteBufferProvider).queuePatch([target.id], intent);
    await refresh();
    await bumpModifiedCount(target.groupId ?? target.id);
  }

  /// 捆绑或解绑后保持当前浏览位置。
  Future<void> _setGroup(List<String> memberIds, String? leadId) async {
    if (memberIds.isEmpty) return;
    final before = state.valueOrNull ?? [];
    final index = ref.read(galleryCurrentIndexProvider);
    final currentId = index >= 0 && index < before.length
        ? before[index].id
        : null;
    final modified = ref.read(galleryModifiedCountProvider);
    final processedIds = before.take(modified + 1).map((a) => a.id).toSet();
    await ref
        .read(galleryWriteBufferProvider)
        .queuePatch(
          memberIds,
          leadId == null
              ? const MediaPatchIntent(clearGroup: true)
              : MediaPatchIntent(groupId: leadId),
        );
    final after = await refresh();
    var nextIndex = after.indexWhere((a) => a.id == currentId);
    if (nextIndex < 0) nextIndex = after.indexWhere((a) => a.id == leadId);
    if (nextIndex < 0) {
      nextIndex = after.isEmpty ? 0 : index.clamp(0, after.length - 1);
    }
    await ref.read(galleryCurrentIndexProvider.notifier).update(nextIndex);
    final lastProcessed = after.lastIndexWhere(
      (a) => processedIds.contains(a.id),
    );
    await ref
        .read(galleryModifiedCountProvider.notifier)
        .update(lastProcessed < 0 ? 0 : lastProcessed);
  }

  Future<void> bundleMedia(String leadId, List<String> memberIds) async {
    await _setGroup(memberIds, leadId);
    await bumpModifiedCount(leadId);
  }

  Future<void> unbundleMedia(List<String> memberIds) =>
      _setGroup(memberIds, null);

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

  /// 标签自动套用：先落盘，再更新浏览位置。
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
      final buffer = ref.read(galleryWriteBufferProvider);
      final tagIds = await db.getTagIdsForMedia(fromAsset.id);
      ref.invalidate(mediaIdsWithTagsProvider);
      await buffer.queueTags(toAsset.id, tagIds);
      await ref
          .read(mediaAssetListProvider.notifier)
          .bumpModifiedCount(toAsset.id);
    } catch (error) {
      ref.read(galleryWriteStatusProvider.notifier).report('标签套用未保存：$error');
      rethrow;
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
