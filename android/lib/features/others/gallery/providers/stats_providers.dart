import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

part 'stats_providers.g.dart';

// ============ 统计信息 Providers ============

/// 数据库统计信息 Provider
@Riverpod(keepAlive: true)
Future<GalleryDbStats> galleryDbStats(GalleryDbStatsRef ref) async {
  final db = ref.watch(galleryDatabaseProvider);
  
  final mediaCount = await db.getMediaAssetCount();
  final tagCount = await db.getTagCount();
  final linkCount = await db.getMediaTagLinkCount();
  
  return GalleryDbStats(
    mediaAssetCount: mediaCount,
    tagCount: tagCount,
    mediaTagLinkCount: linkCount,
  );
}

/// 文件存储统计信息 (持久化缓存, 仅在手动刷新或数据同步后更新)
@Riverpod(keepAlive: true)
class GalleryCachedStorageStats extends _$GalleryCachedStorageStats {
  static const _fileCountKey = 'gallery_storage_file_count';
  static const _totalBytesKey = 'gallery_storage_total_bytes';

  @override
  GalleryStorageStats build() {
    final prefs = PrefsService().prefs;
    return GalleryStorageStats(
      fileCount: prefs.getInt(_fileCountKey) ?? 0,
      totalBytes: prefs.getInt(_totalBytesKey) ?? 0,
    );
  }

  /// 重新扫描文件系统并更新缓存
  Future<void> refresh() async {
    try {
      final storage = ref.read(galleryStorageProvider);
      AppLogger().info('[存储统计] 开始扫描文件系统...');
      final stats = await storage.getStorageStats();
      AppLogger().info('[存储统计] 扫描完成: 文件数=${stats.fileCount}, 字节数=${stats.totalBytes}');
      final prefs = PrefsService().prefs;
      await prefs.setInt(_fileCountKey, stats.fileCount);
      await prefs.setInt(_totalBytesKey, stats.totalBytes);
      state = stats;
      AppLogger().info('[存储统计] 状态已更新');
    } catch (e, s) {
      AppLogger().error('[存储统计] 刷新失败: $e\n$s');
      rethrow;
    }
  }
}

/// 数据库统计信息
class GalleryDbStats {
  final int mediaAssetCount;
  final int tagCount;
  final int mediaTagLinkCount;

  const GalleryDbStats({
    required this.mediaAssetCount,
    required this.tagCount,
    required this.mediaTagLinkCount,
  });
}
