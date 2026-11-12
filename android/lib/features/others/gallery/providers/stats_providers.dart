import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/features/others/gallery/models/gallery_overview.dart';
import 'package:torrid/features/others/gallery/providers/service_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'stats_providers.g.dart';

// 统计信息 Providers

@Riverpod(keepAlive: true)
Stream<GalleryDbStats> galleryDbStats(Ref ref) => ref
    .watch(galleryDatabaseProvider)
    .watchCounts()
    .map(
      (count) => GalleryDbStats(
        mediaAssetCount: count.media,
        tagCount: count.tags,
        mediaTagLinkCount: count.links,
      ),
    );

@Riverpod(keepAlive: true)
class GalleryCachedStorageStats extends _$GalleryCachedStorageStats {
  @override
  Future<GalleryStorageStats> build() =>
      ref.watch(galleryStorageProvider).getStorageStats();

  Future<void> refresh() async {
    final storage = ref.read(galleryStorageProvider);
    try {
      state = AsyncData(await storage.getStorageStats());
    } catch (error, stack) {
      AppLogger().error('画廊文件统计失败', error, stack);
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

/// 服务端画廊总览 Provider
@riverpod
Future<GalleryOverview> galleryServerOverview(Ref ref) async {
  final apiClient = ref.watch(apiClientManagerProvider);
  final response = await apiClient.get('/API/gallery/overview');
  return GalleryOverview.fromJson(response.data as Map<String, dynamic>);
}

/// 有关联标签的媒体 ID 集合 Provider（用于浏览页标签指示器）
@Riverpod(keepAlive: true)
Stream<Set<String>> mediaIdsWithTags(Ref ref) =>
    ref.watch(galleryDatabaseProvider).watchMediaIdsWithTags();
