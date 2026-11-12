import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_database_service.dart';

part 'local_data_providers.g.dart';

@Riverpod(keepAlive: true)
class GalleryLocalDataController extends _$GalleryLocalDataController {
  @override
  bool build() => false;

  Future<void> clearDatabase() => _clear(database: true, files: false);

  Future<void> clearFiles() => _clear(database: false, files: true);

  Future<void> clearAll() => _clear(database: true, files: true);

  Future<void> _clear({required bool database, required bool files}) async {
    if (state) return;
    state = true;
    final buffer = ref.read(galleryWriteBufferProvider);
    var locked = false;
    try {
      if (database) {
        await buffer.confirmAndLock(requireConnection: false);
      } else {
        await buffer.lock();
      }
      locked = true;
      final db = ref.read(galleryDatabaseProvider);
      if (database &&
          (await db.operations()).any((op) => op.kind == 'processed')) {
        throw StateError('请先重试完成上次的标记已处理');
      }
      if (files) {
        await ref.read(galleryStorageProvider).clearAllFiles();
        ref.read(galleryFilesRevisionProvider.notifier).state++;
      }
      if (database) await db.clearAllData();
      if (files) {
        try {
          await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
        } catch (_) {}
      }
    } finally {
      if (locked) buffer.unlock();
      state = false;
    }
  }
}
