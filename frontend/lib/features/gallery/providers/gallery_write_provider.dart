import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/gallery/providers/media_providers.dart';
import 'package:torrid/features/gallery/providers/service_providers.dart';
import 'package:torrid/features/gallery/providers/stats_providers.dart';
import 'package:torrid/features/gallery/providers/tag_providers.dart';
import 'package:torrid/features/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/gallery/services/gallery_write_service.dart';

part 'gallery_write_provider.g.dart';

/// 服务端写入统一入口
///
/// 本地立即生效 → 推送（写缓冲合并 / 直推重试）→ 失败回滚, 全部收敛在
/// [GalleryWriteService]; 这里只把它接到具体 provider 与网络实现上。
@Riverpod(keepAlive: true)
GalleryWriteService galleryWriteService(GalleryWriteServiceRef ref) {
  final api = ref.watch(galleryApiProvider);
  final store = GalleryMediaWriteStore(ref.watch(galleryDatabaseProvider));

  final service = GalleryWriteService(
    store: store,
    pushTags: api.setMediaTags,
    pushPatch: (mediaIds, intent) =>
        api.patchMedia(mediaIds: mediaIds, intent: intent),
    pushTagLinks: (mediaIds, {addTagIds = const [], removeTagIds = const []}) =>
        api.batchMediaTags(
      mediaIds: mediaIds,
      addTagIds: addTagIds,
      removeTagIds: removeTagIds,
    ),
    onLocalChanged: () => ref.invalidate(mediaIdsWithTagsProvider),
    onReverted: () {
      ref.invalidate(mediaAssetListProvider);
      ref.invalidate(mediaIdsWithTagsProvider);
      ref.invalidate(currentMediaTagsProvider);
    },
    onError: (message) =>
        ref.read(galleryWriteStatusProvider.notifier).report(message),
  );

  ref.onDispose(service.dispose);
  return service;
}

/// 服务端写入的用户提示通道（由浮层/页面监听并弹出提示）
@Riverpod(keepAlive: true)
class GalleryWriteStatus extends _$GalleryWriteStatus {
  @override
  String? build() => null;

  void report(String message) => state = message;

  void clear() => state = null;
}
