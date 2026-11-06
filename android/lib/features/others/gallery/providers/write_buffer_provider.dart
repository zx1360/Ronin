import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/providers/stats_providers.dart';
import 'package:torrid/features/others/gallery/providers/tag_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_write_buffer.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'write_buffer_provider.g.dart';

@Riverpod(keepAlive: true)
GalleryWriteBuffer galleryWriteBuffer(GalleryWriteBufferRef ref) {
  final db = ref.watch(galleryDatabaseProvider);
  final buffer = GalleryWriteBuffer(
    db: db,
    currentClient: () => ref.read(apiClientManagerProvider),
    onChanged: () {
      ref.invalidate(currentMediaTagsProvider);
      ref.invalidate(mediaIdsWithTagsProvider);
      ref.invalidate(galleryDbStatsProvider);
    },
  );
  ref.listen(apiClientManagerProvider, (_, __) => buffer.retry());
  ref.onDispose(buffer.dispose);
  buffer.retry();
  return buffer;
}

@Riverpod(keepAlive: true)
class GalleryWriteStatus extends _$GalleryWriteStatus {
  @override
  String? build() => null;

  void report(String message) => state = message;
  void clear() => state = null;
}
