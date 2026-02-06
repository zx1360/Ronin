import 'package:riverpod_annotation/riverpod_annotation.dart';
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

/// 文件存储统计信息 Provider (仅在手动刷新或操作后更新)
@Riverpod(keepAlive: true)
Future<GalleryStorageStats> galleryStorageStats(GalleryStorageStatsRef ref) async {
  final storage = ref.watch(galleryStorageProvider);
  return await storage.getStorageStats();
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
