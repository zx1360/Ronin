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
/// 把"服务端推送"与"失败回滚"接到具体 provider: 本地先改, 后台合并推送,
/// 重试仍失败则回滚本地缓存与内存状态, 保证本地始终向服务端看齐.
@Riverpod(keepAlive: true)
GalleryWriteBuffer galleryWriteBuffer(GalleryWriteBufferRef ref) {
  final api = ref.watch(galleryApiProvider);
  final db = ref.watch(galleryDatabaseProvider);

  final buffer = GalleryWriteBuffer(
    pushTags: (mediaId, tagIds) => api.setMediaTags(mediaId, tagIds),
    pushPatch: (mediaId, patch) =>
        api.patchMedia(mediaIds: [mediaId], intent: patch),
    onRevert: (mediaId, baseline) async {
      if (baseline.asset != null) {
        await db.updateMediaAsset(baseline.asset!);
        ref
            .read(mediaAssetListProvider.notifier)
            .replaceAsset(baseline.asset!);
      }
      if (baseline.tagIds != null) {
        await db.setTagsForMedia(mediaId, baseline.tagIds!);
        if (ref.read(currentMediaAssetProvider)?.id == mediaId) {
          ref.invalidate(currentMediaTagsProvider);
        }
      }
      ref.invalidate(mediaIdsWithTagsProvider);
    },
    onError: (message) =>
        ref.read(galleryWriteStatusProvider.notifier).report(message),
  );

  ref.onDispose(buffer.dispose);
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
