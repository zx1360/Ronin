import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/providers/media_providers.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/stats_providers.dart';
import 'package:torrid/features/others/gallery/providers/tag_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_write_buffer.dart';

part 'write_buffer_provider.g.dart';

/// 乐观写缓冲 Provider
///
/// 乐观状态仅在内存；服务端确认后才持久化缓存。
@Riverpod(keepAlive: true)
GalleryWriteBuffer galleryWriteBuffer(GalleryWriteBufferRef ref) {
  final api = ref.watch(galleryApiProvider);
  final db = ref.watch(galleryDatabaseProvider);
  var disposed = false;

  final buffer = GalleryWriteBuffer(
    pushTags: (mediaId, tagIds) async {
      final confirmed = await api.setMediaTags(mediaId, tagIds);
      if (!disposed) await db.setTagsForMedia(mediaId, confirmed);
    },
    pushPatch: (mediaId, patch) async {
      final confirmed = await api.patchMedia(
        mediaIds: [mediaId],
        intent: patch,
      );
      if (!disposed) await db.updateMediaAssetsLocal(confirmed);
    },
    onChanged: () {
      // 消费端读取缓冲快照，由这里失效，避免反向 watch。
      ref.invalidate(currentMediaTagsProvider);
      ref.invalidate(mediaIdsWithTagsProvider);
    },
    onRevert: (mediaId, baseline) async {
      if (baseline.asset != null) {
        ref.read(mediaAssetListProvider.notifier).replaceAsset(baseline.asset!);
      }
      for (final member in baseline.members) {
        ref.read(mediaAssetListProvider.notifier).replaceAsset(member);
      }
      if (baseline.tagIds != null) {
        if (ref.read(currentMediaAssetProvider)?.id == mediaId) {
          ref.invalidate(currentMediaTagsProvider);
        }
      }
      ref.invalidate(mediaIdsWithTagsProvider);
    },
    onError: (message) =>
        ref.read(galleryWriteStatusProvider.notifier).report(message),
  );

  ref.onDispose(() {
    disposed = true;
    buffer.dispose();
  });
  return buffer;
}

/// 服务端写入的用户提示通道（由浮层/页面监听并弹出提示）
@Riverpod(keepAlive: true)
class GalleryWriteStatus extends _$GalleryWriteStatus {
  @override
  String? build() => null;

  void report(String message) => state = message;

  void clear() => state = null;
}
