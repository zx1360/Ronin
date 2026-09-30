import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_patch_intent.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/settings_providers.dart';
import 'package:torrid/features/others/gallery/providers/stats_providers.dart';
import 'package:torrid/features/others/gallery/providers/write_buffer_provider.dart';
import 'package:torrid/features/others/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_write_buffer.dart';

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

  /// 替换列表中的某一行（写缓冲回滚用, 不触发服务端写入）
  void replaceAsset(MediaAsset asset) {
    final currentList = state.valueOrNull;
    if (currentList == null) return;
    final index = currentList.indexWhere((a) => a.id == asset.id);
    if (index < 0) return;
    state = AsyncData(List<MediaAsset>.from(currentList)..[index] = asset);
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

    // 本地缓存同样级联标记（与服务端行为一致）
    final db = ref.read(galleryDatabaseProvider);
    await db.markMediaAssetDeleted(id, deleted: deleted);
    ref.invalidate(mediaIdsWithTagsProvider);
    ref.read(galleryWriteBufferProvider).queuePatch(
          id,
          MediaPatchIntent(isDeleted: deleted),
          baselineAsset: previous,
        );
    await bumpModifiedCount(id);
    return state.valueOrNull ?? [];
  }

  /// 批量标记删除/恢复（乐观更新 + 单次服务端请求, 失败整体回滚）
  Future<List<MediaAsset>> batchMarkDeleted(
    List<String> ids, {
    bool deleted = true,
  }) async {
    if (ids.isEmpty) return state.valueOrNull ?? [];

    final db = ref.read(galleryDatabaseProvider);
    final api = ref.read(galleryApiProvider);
    final currentList = state.valueOrNull ?? [];
    final previousById = {
      for (final asset in currentList)
        if (ids.contains(asset.id)) asset.id: asset,
    };

    await db.batchMarkMediaAssetDeleted(ids, deleted: deleted);
    state = AsyncData([
      for (final asset in currentList)
        ids.contains(asset.id) ? asset.copyWith(isDeleted: deleted) : asset,
    ]);
    ref.invalidate(mediaIdsWithTagsProvider);

    try {
      await retryServerWrite(
        () => api.patchMedia(
          mediaIds: ids,
          intent: MediaPatchIntent(isDeleted: deleted),
        ),
      );
    } catch (e) {
      for (final previous in previousById.values) {
        await db.updateMediaAsset(previous);
      }
      state = AsyncData([
        for (final asset in currentList) previousById[asset.id] ?? asset,
      ]);
      rethrow;
    }

    for (final id in ids) {
      await bumpModifiedCount(id);
    }
    return state.valueOrNull ?? [];
  }

  /// 设置备注（空串清空）。
  Future<void> setMessage(MediaAsset target, String message) =>
      _applyLocalAndQueue(
        target.copyWith(
          message: message.isEmpty ? null : message,
          clearMessage: message.isEmpty,
        ),
        target,
        MediaPatchIntent(message: message),
      );

  /// 保存编辑参数（图片旋转/裁切、视频剪辑共用）；[params] 为空表示清除编辑记录。
  Future<void> setEditParams(MediaAsset target, String? params) =>
      _applyLocalAndQueue(
        target.copyWith(
          editParams: params,
          clearEditParams: params == null || params.isEmpty,
        ),
        target,
        params == null || params.isEmpty
            ? const MediaPatchIntent(clearEditParams: true)
            : MediaPatchIntent(editParams: params),
      );

  /// 「本地立即生效 → 写缓冲合并推送」这一条写路径的唯一实现。
  ///
  /// 详情页、图片编辑页、视频剪辑页原先各抄一遍（还各漏了几项），统一到这里：
  /// 本地落库 + 内存态同步 + 服务端经缓冲推送，失败由缓冲层回滚。
  Future<void> _applyLocalAndQueue(
    MediaAsset updated,
    MediaAsset baseline,
    MediaPatchIntent intent,
  ) async {
    final currentList = state.valueOrNull ?? [];
    final index = currentList.indexWhere((a) => a.id == updated.id);
    if (index >= 0) {
      state = AsyncData(
        List<MediaAsset>.from(currentList)..[index] = updated,
      );
    }

    final db = ref.read(galleryDatabaseProvider);
    await db.updateMediaAsset(updated);
    ref.read(galleryWriteBufferProvider).queuePatch(
          updated.id,
          intent,
          baselineAsset: baseline,
        );
  }

  /// 捆绑媒体文件（组成员写入 group_id）
  Future<void> bundleMedia(String leadId, List<String> memberIds) async {
    if (memberIds.isEmpty) return;

    final db = ref.read(galleryDatabaseProvider);
    final api = ref.read(galleryApiProvider);

    await db.setMediaGroupId(memberIds, leadId);
    await refresh();

    try {
      await retryServerWrite(
        () => api.patchMedia(
          mediaIds: memberIds,
          intent: MediaPatchIntent(groupId: leadId),
        ),
      );
    } catch (e) {
      await db.setMediaGroupId(memberIds, null);
      await refresh();
      rethrow;
    }
    await bumpModifiedCount(leadId);
  }

  /// 解除捆绑
  Future<void> unbundleMedia(List<String> memberIds) async {
    if (memberIds.isEmpty) return;

    final db = ref.read(galleryDatabaseProvider);
    final api = ref.read(galleryApiProvider);

    await db.setMediaGroupId(memberIds, null);
    await refresh();

    await retryServerWrite(
      () => api.patchMedia(
        mediaIds: memberIds,
        intent: const MediaPatchIntent(clearGroup: true),
      ),
    );
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
      final baseline = await db.getTagIdsForMedia(toAsset.id);
      await db.setTagsForMedia(toAsset.id, tagIds);
      ref.invalidate(mediaIdsWithTagsProvider);
      // 服务端推送走缓冲（合并 + 重试 + 失败回滚）
      ref.read(galleryWriteBufferProvider).queueTags(
            toAsset.id,
            tagIds,
            baselineTagIds: baseline,
          );
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
