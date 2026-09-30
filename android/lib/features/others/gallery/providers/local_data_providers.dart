import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_sync_service.dart';

part 'local_data_providers.g.dart';

/// 本地缓存的清空动作。
///
/// 只清本机（gallery.db 与下载的文件），**不触碰服务端**；清空后把游标复位、让派生数据重取。
/// 此前设置页把"复位 + 失效一堆 provider"抄了三遍（还各漏了几项），这里收敛成一条路径。
@Riverpod(keepAlive: true)
class GalleryLocalDataController extends _$GalleryLocalDataController {
  /// 是否有清空操作在执行。
  @override
  bool build() => false;

  /// 清空本地数据库缓存。
  Future<void> clearDatabase() => _run(() async {
        await ref.read(galleryDatabaseProvider).clearAllData();
        await _resetCursors();
        _invalidateDerived();
      });

  /// 清空本地媒体文件（保留数据库记录）。
  Future<void> clearFiles() => _run(() async {
        await ref.read(galleryStorageProvider).clearAllFiles();
        await _refreshStorageStats();
      });

  /// 清空数据库与文件。
  Future<void> clearAll() => _run(() async {
        await ref.read(galleryDatabaseProvider).clearAllData();
        await ref.read(galleryStorageProvider).clearAllFiles();
        await _resetCursors();
        _invalidateDerived();
        await _refreshStorageStats();
      });

  Future<void> _run(Future<void> Function() action) async {
    state = true;
    try {
      await action();
    } finally {
      state = false;
    }
  }

  /// 浏览位置与"已处理"游标都指向已经不存在的数据，必须复位。
  Future<void> _resetCursors() async {
    await ref.read(galleryModifiedCountProvider.notifier).reset();
    await ref.read(galleryCurrentIndexProvider.notifier).update(0);
  }

  void _invalidateDerived() {
    ref.invalidate(mediaAssetListProvider);
    ref.invalidate(tagTreeProvider);
    ref.invalidate(galleryDbStatsProvider);
    ref.invalidate(galleryUploadStatsProvider);
  }

  /// 文件系统扫描较慢，失败不影响已完成的清理。
  Future<void> _refreshStorageStats() async {
    try {
      await ref.read(galleryCachedStorageStatsProvider.notifier).refresh();
    } catch (_) {}
  }
}
